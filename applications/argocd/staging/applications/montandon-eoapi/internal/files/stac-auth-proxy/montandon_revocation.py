"""
External-token revocation for stac-auth-proxy.

stac-auth-proxy validates go-api JWTs locally (signature + exp via the go-api JWKS) but
cannot detect a token that go-api has *revoked* before its natural expiry. go-api tracks
revocation centrally and exposes a lightweight introspection endpoint keyed by the token's
`jti`. This module adds that check without forking stac-auth-proxy.

There is no config hook for token validation in stac-auth-proxy v1.1.1, so we monkeypatch
`EnforceAuthMiddleware.validate_token` at import time. This module is imported by
`montandon_filters.py`, which stac-auth-proxy imports at app-construction time (before it
serves any request) when loading the COLLECTIONS_FILTER_CLS / ITEMS_FILTER_CLS classes.

Design notes / decisions (see go-api issue #2794):
- Only go-api *external tokens* reach this proxy; every external token carries a `jti`.
  A token with no `jti`, or a `jti` go-api does not recognise, is rejected (401).
- A static blacklist (env) is checked first and always wins — a permanent kill-switch that
  works even before/without the go-api verify endpoint.
- Positive results only are cached, short TTL, so a revoked token is never served stale.
- Fail policy on go-api outage is configurable; default is fail-closed. It is deployed
  fail-open initially (until the verify endpoint is live in prod goadmin) then flipped.
- If the patch cannot be applied (upstream symbol changed), we raise at import so the pod
  crashes on boot rather than silently serving traffic with revocation disabled.
"""

import inspect
import logging
import os
import threading
import time
from typing import cast
from urllib.parse import urlparse, urlunparse

import httpx
from fastapi import HTTPException, status
from stac_auth_proxy.middleware import EnforceAuthMiddleware

logger = logging.getLogger(__name__)


def _bool_env(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _verify_url_from_oidc() -> str:
    """Derive the go-api verify URL from the OIDC issuer origin.

    The verify endpoint always lives on the same host as the OIDC provider, so we reuse
    OIDC_DISCOVERY_URL rather than taking a separate URL. Raise if it is unset or
    unparseable so the pod crashes on boot instead of running without a verify endpoint.
    """
    oidc = os.environ.get("OIDC_DISCOVERY_URL")
    parts = urlparse(oidc or "")
    if not (parts.scheme and parts.netloc):
        raise RuntimeError(
            "montandon_revocation: cannot derive verify URL; OIDC_DISCOVERY_URL is unset "
            "or invalid (%r)." % (oidc,)
        )
    return urlunparse(
        (parts.scheme, parts.netloc, "/api/v2/external-token/verify/", "", "", "")
    )


# --- Configuration (read once at import) ------------------------------------------------

VERIFY_URL: str = _verify_url_from_oidc()
CACHE_TTL: float = float(os.environ.get("GOAPI_TOKEN_VERIFY_TTL", "300"))
VERIFY_TIMEOUT: float = float(os.environ.get("GOAPI_TOKEN_VERIFY_TIMEOUT", "3"))
FAIL_OPEN: bool = _bool_env("GOAPI_TOKEN_VERIFY_FAIL_OPEN", False)
STATIC_BLACKLIST: frozenset[str] = frozenset(
    jti.strip()
    for jti in os.environ.get("GOAPI_TOKEN_STATIC_BLACKLIST", "").split(",")
    if jti.strip()
)

# --- Positive-only in-memory cache (per pod) --------------------------------------------
# jti -> monotonic expiry. Single-process/single-event-loop deployment, but guard with a
# lock anyway since we are called from a sync context.
_cache: dict[str, float] = {}
_cache_lock = threading.Lock()

_client = httpx.Client(timeout=VERIFY_TIMEOUT)


def _cache_get(jti: str) -> bool:
    with _cache_lock:
        expiry = _cache.get(jti)
        if expiry is None:
            return False
        if expiry <= time.monotonic():
            _cache.pop(jti, None)
            return False
        return True


def _cache_put(jti: str) -> None:
    with _cache_lock:
        _cache[jti] = time.monotonic() + CACHE_TTL


def _reject(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _is_active(jti: str) -> bool:
    """Ask go-api whether the token is still active. Applies fail policy on outage."""
    try:
        resp = _client.post(VERIFY_URL, json={"jti": jti})
    except httpx.HTTPError as exc:
        logger.warning(
            "go-api verify call failed (%s); fail_open=%s",
            type(exc).__name__,
            FAIL_OPEN,
        )
        return FAIL_OPEN

    if resp.status_code == 200:
        try:
            return bool(resp.json().get("active"))
        except ValueError:
            logger.error("go-api verify returned non-JSON 200; rejecting")
            return False
    if resp.status_code == 400:
        # Malformed jti. Should not happen (jti comes from a validated token). Reject.
        logger.error("go-api verify returned 400 for jti; rejecting")
        return False
    # Any other status (incl. 404 before the endpoint is live) -> outage -> fail policy.
    logger.warning(
        "go-api verify returned %s; fail_open=%s", resp.status_code, FAIL_OPEN
    )
    return FAIL_OPEN


def check_revocation(payload: dict | None) -> None:
    """Raise HTTPException(401) if the token behind `payload` is revoked/unknown."""
    if payload is None:
        # Anonymous / public request, no token to check.
        return

    jti = payload.get("jti")
    if not jti:
        raise _reject("Token is missing jti")

    # Static blacklist wins over everything (permanent kill-switch).
    if jti in STATIC_BLACKLIST:
        logger.info("Rejecting statically-blacklisted jti %s", jti)
        raise _reject("Token has been revoked")

    if _cache_get(jti):
        return

    if not _is_active(jti):
        logger.info("Rejecting revoked/unknown jti %s", jti)
        raise _reject("Token has been revoked")

    _cache_put(jti)


# --- Monkeypatch --------------------------------------------------------------------------


def apply_patch() -> None:
    """Wrap EnforceAuthMiddleware.validate_token with the revocation check.

    Called explicitly from montandon_filters.py at import time (app construction,
    before any request is served). Idempotent and raises if the target symbol is
    missing, so revocation can never be silently disabled.
    """
    original = getattr(EnforceAuthMiddleware, "validate_token", None)
    if not callable(original):
        raise RuntimeError(
            "montandon_revocation: EnforceAuthMiddleware.validate_token not found; "
            "stac-auth-proxy internals changed. Refusing to start with revocation disabled."
        )
    # Idempotent: return early if already patched, before inspecting the (wrapper) signature.
    if getattr(original, "_montandon_revocation_patched", False):
        return
    # Guard against upstream signature drift: we rely on it returning the JWT payload.
    params = list(inspect.signature(original).parameters)
    if "auth_header" not in params:
        raise RuntimeError(
            "montandon_revocation: unexpected validate_token signature %r; "
            "refusing to start with revocation disabled." % (params,)
        )

    def validate_token(self, *args, **kwargs):
        payload = cast(dict | None, original(self, *args, **kwargs))
        check_revocation(payload)
        return payload

    validate_token._montandon_revocation_patched = True  # type: ignore[attr-defined]
    EnforceAuthMiddleware.validate_token = validate_token  # type: ignore[assignment]
    logger.info(
        "montandon_revocation: patched EnforceAuthMiddleware.validate_token "
        "(verify_url=%s, ttl=%ss, fail_open=%s, blacklist=%d)",
        VERIFY_URL,
        CACHE_TTL,
        FAIL_OPEN,
        len(STATIC_BLACKLIST),
    )

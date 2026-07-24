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
# Short TTL for a fail-open "allow" served during a go-api outage, so revocation resumes
# within seconds of go-api recovering instead of being masked for a full CACHE_TTL window.
OUTAGE_CACHE_TTL: float = float(os.environ.get("GOAPI_TOKEN_VERIFY_OUTAGE_TTL", "30"))
# TTL for a definitive deny (go-api reported the jti inactive/unknown). Long, since a
# revoked/unknown jti effectively never becomes valid again; avoids re-hitting go-api on
# every request from an abandoned or leaked token. Only definitive denials are cached here
# (never a transient fail-closed outage), so recovery is not masked.
DENY_CACHE_TTL: float = float(os.environ.get("GOAPI_TOKEN_VERIFY_DENY_TTL", "86400"))
VERIFY_TIMEOUT: float = float(os.environ.get("GOAPI_TOKEN_VERIFY_TIMEOUT", "3"))
FAIL_OPEN: bool = _bool_env("GOAPI_TOKEN_VERIFY_FAIL_OPEN", False)
STATIC_BLACKLIST: frozenset[str] = frozenset(
    jti.strip()
    for jti in os.environ.get("GOAPI_TOKEN_STATIC_BLACKLIST", "").split(",")
    if jti.strip()
)

# --- In-memory decision cache (per pod) -------------------------------------------------
# jti -> (allowed, monotonic expiry). Caches both allows (short TTL) and definitive denies
# (long TTL). Single-process/single-event-loop deployment, but guard with a lock anyway
# since we are called from a sync context.
_cache: dict[str, tuple[bool, float]] = {}
_cache_lock = threading.Lock()

_client = httpx.Client(timeout=VERIFY_TIMEOUT)


def _cache_get(jti: str) -> bool | None:
    """Return the cached decision (True=allow, False=deny), or None on miss/expiry."""
    with _cache_lock:
        entry = _cache.get(jti)
        if entry is None:
            return None
        allowed, expiry = entry
        if expiry <= time.monotonic():
            _cache.pop(jti, None)
            return None
        return allowed


def _cache_put(jti: str, allowed: bool, ttl: float) -> None:
    with _cache_lock:
        _cache[jti] = (allowed, time.monotonic() + ttl)


def _reject(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _verify(jti: str) -> tuple[bool, float]:
    """Ask go-api whether the token is active.

    Returns ``(allowed, cache_ttl)`` where cache_ttl is how long THIS decision may be
    cached (0 = do not cache). Outcomes:
    - 200 active:true  -> (True, CACHE_TTL)         verified allow, short TTL
    - 200 active:false -> (False, DENY_CACHE_TTL)   definitive deny, long TTL
    - outage/other     -> fail policy; a fail-open allow caches briefly (OUTAGE_CACHE_TTL),
                          a fail-closed deny is NOT cached (0) so recovery isn't masked
    - 400 / non-JSON   -> (False, 0)                anomalous, reject but don't cache
    """
    try:
        resp = _client.post(VERIFY_URL, json={"jti": jti})
    except httpx.HTTPError as exc:
        logger.warning(
            "go-api verify call failed (%s); fail_open=%s",
            type(exc).__name__,
            FAIL_OPEN,
        )
        return FAIL_OPEN, (OUTAGE_CACHE_TTL if FAIL_OPEN else 0)

    if resp.status_code == 200:
        try:
            active = bool(resp.json().get("active"))
        except ValueError:
            logger.error("go-api verify returned non-JSON 200; rejecting")
            return False, 0
        return active, (CACHE_TTL if active else DENY_CACHE_TTL)
    if resp.status_code == 400:
        # Malformed jti. Should not happen (jti comes from a validated token). Reject.
        logger.error("go-api verify returned 400 for jti; rejecting")
        return False, 0
    # Any other status (incl. 404 before the endpoint is live) -> outage -> fail policy.
    logger.warning(
        "go-api verify returned %s; fail_open=%s", resp.status_code, FAIL_OPEN
    )
    return FAIL_OPEN, (OUTAGE_CACHE_TTL if FAIL_OPEN else 0)


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

    cached = _cache_get(jti)
    if cached is True:
        return
    if cached is False:
        logger.info("Rejecting cached-inactive jti %s", jti)
        raise _reject("Token has been revoked")

    allowed, ttl = _verify(jti)
    if ttl > 0:
        _cache_put(jti, allowed, ttl)
    if not allowed:
        logger.info("Rejecting revoked/unknown jti %s", jti)
        raise _reject("Token has been revoked")


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

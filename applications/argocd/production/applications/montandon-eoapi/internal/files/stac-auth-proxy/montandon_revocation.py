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
- Decisions are cached per outcome with their own TTL: verified allows briefly, definitive
  denies for a long window, fail-open outage allows very briefly; a fail-closed outage is
  never cached so recovery is not masked. The cache is size-bounded.
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


def _num_env(name: str, default: float, *, minimum: float = 0.0) -> float:
    """Parse a numeric env var, failing on boot with a clear message on bad input.

    Empty/unset falls back to ``default``. A non-numeric or out-of-range value raises
    RuntimeError (consistent with _verify_url_from_oidc) instead of an opaque
    ``float()`` ValueError, and prevents footguns like a negative TTL that would make
    every cache entry expire immediately.
    """
    raw = os.environ.get(name)
    if raw is None or not raw.strip():
        return default
    try:
        value = float(raw)
    except ValueError:
        raise RuntimeError(
            "montandon_revocation: %s must be a number, got %r." % (name, raw)
        ) from None
    if value < minimum:
        raise RuntimeError(
            "montandon_revocation: %s must be >= %s, got %s." % (name, minimum, value)
        )
    return value


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
CACHE_TTL: float = _num_env("GOAPI_TOKEN_VERIFY_TTL", 300)
# Short TTL for a fail-open "allow" served during a go-api outage, so revocation resumes
# within seconds of go-api recovering instead of being masked for a full CACHE_TTL window.
OUTAGE_CACHE_TTL: float = _num_env("GOAPI_TOKEN_VERIFY_OUTAGE_TTL", 30)
# TTL for a definitive deny (go-api reported the jti inactive/unknown). Long, since a
# revoked/unknown jti effectively never becomes valid again; avoids re-hitting go-api on
# every request from an abandoned or leaked token. Only definitive denials are cached here
# (never a transient fail-closed outage), so recovery is not masked.
DENY_CACHE_TTL: float = _num_env("GOAPI_TOKEN_VERIFY_DENY_TTL", 86400)
VERIFY_TIMEOUT: float = _num_env("GOAPI_TOKEN_VERIFY_TIMEOUT", 3, minimum=0.001)
# Upper bound on cached jti decisions; keeps memory bounded on a long-lived pod that sees
# many distinct (leaked/rotated/one-off) jtis. On overflow we drop expired entries first,
# then the soonest-to-expire.
CACHE_MAX_ENTRIES: int = int(_num_env("GOAPI_TOKEN_VERIFY_CACHE_MAX", 50000, minimum=1))
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


def _evict_locked(now: float) -> None:
    """Bound cache size. Caller must hold _cache_lock. Drop expired entries first, then,
    if still over the cap, the soonest-to-expire ones."""
    for k in [k for k, (_, exp) in _cache.items() if exp <= now]:
        _cache.pop(k, None)
    overflow = len(_cache) - CACHE_MAX_ENTRIES
    if overflow > 0:
        for k in sorted(_cache, key=lambda k: _cache[k][1])[:overflow]:
            _cache.pop(k, None)


def _cache_put(jti: str, allowed: bool, ttl: float) -> None:
    if ttl <= 0:
        return  # decisions with a 0 ttl (anomalies, uncached outages) are never cached
    now = time.monotonic()
    with _cache_lock:
        _cache[jti] = (allowed, now + ttl)
        if len(_cache) > CACHE_MAX_ENTRIES:
            _evict_locked(now)


def _reject(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _fail_policy() -> tuple[bool, float]:
    """Decision for an outage: fail-open allows briefly (cached OUTAGE_CACHE_TTL); a
    fail-closed deny is NOT cached (ttl 0) so recovery is not masked."""
    return FAIL_OPEN, (OUTAGE_CACHE_TTL if FAIL_OPEN else 0)


def _verify(jti: str) -> tuple[bool, float]:
    """Ask go-api whether the token is active.

    Returns ``(allowed, cache_ttl)`` where cache_ttl is how long THIS decision may be
    cached (0 = do not cache). Outcomes:
    - 200 active is True  -> (True, CACHE_TTL)         verified allow, short TTL
    - 200 active is False -> (False, DENY_CACHE_TTL)   definitive deny, long TTL
    - 200 without a boolean `active` -> (False, 0)     anomalous body: reject, don't cache
    - 400                 -> (False, 0)                anomalous, reject but don't cache
    - outage / other      -> fail policy (see _fail_policy)

    Any unexpected error is treated as an outage rather than propagating, so a token check
    can never surface as an HTTP 500 (which would bypass the intended fail policy).
    """
    try:
        resp = _client.post(VERIFY_URL, json={"jti": jti})

        if resp.status_code == 200:
            active = resp.json().get("active")
            if active is True:
                return True, CACHE_TTL
            if active is False:
                return False, DENY_CACHE_TTL
            # 200 but no boolean `active` (field drift, interstitial served as 200, ...).
            # Do NOT treat as a definitive deny: reject this request but don't cache it,
            # so a valid token is not locked out for DENY_CACHE_TTL.
            logger.error(
                "go-api verify 200 lacked a boolean 'active' (%r); rejecting, not caching",
                active,
            )
            return False, 0
        if resp.status_code == 400:
            # Malformed jti. Should not happen (jti comes from a validated token). Reject.
            logger.error("go-api verify returned 400 for jti; rejecting")
            return False, 0
        # Any other status (incl. 404 before the endpoint is live) -> outage.
        logger.warning(
            "go-api verify returned %s; fail_open=%s", resp.status_code, FAIL_OPEN
        )
        return _fail_policy()
    except Exception as exc:
        # Network error, non-JSON body, or anything unexpected -> honour the fail policy
        # rather than letting it become a 500.
        logger.warning(
            "go-api verify call failed (%s); fail_open=%s", type(exc).__name__, FAIL_OPEN
        )
        return _fail_policy()


def check_revocation(payload: dict | None) -> None:
    """Raise HTTPException(401) if the token behind `payload` is revoked/unknown."""
    if payload is None:
        # Anonymous / public request, no token to check.
        return

    jti = payload.get("jti")
    # Require a non-empty string jti. A non-string would be unhashable as a cache key
    # (500) or bypass the blacklist; a validated external token always carries a str jti.
    if not jti or not isinstance(jti, str):
        raise _reject("Token is missing a valid jti")

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
    _cache_put(jti, allowed, ttl)  # no-op when ttl <= 0
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

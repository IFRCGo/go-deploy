"""
CQL2 filter factories.

These classes will be initialized at the startup of the STAC Auth Proxy service and will
be called for each request to collections/items endpoints in order to generate CQL2
filters based on the JWT permissions.

docs: https://developmentseed.org/stac-auth-proxy/user-guide/record-level-auth/
"""

import asyncio
import dataclasses
import os
import time
import logging
from typing import Any, Literal, Optional, Sequence

import httpx

logger = logging.getLogger(__name__)

if not (UPSTREAM_URL := os.environ.get("UPSTREAM_URL"))
    raise ValueError("Failed to retrieve upstream URL")


def cql2_in_query(
    variable: Literal["collection", "id"], collection_ids: Sequence[str]
) -> str:
    """
    Generate CQL2 query to see if value of variable matches any element of sequence of
    strings. Due to CQL2 syntax ambiguities around single element arrays with the "in"
    operator, we use a direct comparison when there's only one permitted collection.
    """
    if not collection_ids:
        return "1=0"

    if len(collection_ids) == 1:
        return f"{variable} = " + repr(list(collection_ids)[0])

    return f"{variable} IN ({','.join(repr(c_id) for c_id in collection_ids)})"


@dataclasses.dataclass
class CollectionsFilter:
    """
    CQL2 filter factory for collections based on JWT permissions.
    """

    collections_claim: str = "collections"  # JWT claim with allowed collection IDs
    admin_claim: str = "superuser"  # JWT claim indicating superuser status
    public_collections_filter: str = "(private IS NULL OR private = false)"

    async def __call__(self, context: dict[str, Any]) -> str:
        jwt_payload: Optional[dict[str, Any]] = context.get("payload")

        # Anonymous: only public collections
        if not jwt_payload:
            return self.public_collections_filter

        # Superuser: no filter
        if jwt_payload.get(self.admin_claim) == 'true':
            logger.debug(
                f"Superuser detected for sub {jwt_payload.get('sub')}, "
                "no filter applied for collections"
            )
            return "1=1"  # No filter for superusers

        # Authenticated user: Allowed to access collections mentioned in JWT
        permitted_collections = jwt_payload.get(self.collections_claim, [])
        return " OR ".join(
            [
                self.public_collections_filter,
                cql2_in_query("id", permitted_collections),
            ]
        )


@dataclasses.dataclass
class ItemsFilter:
    """
    CQL2 filter factory for items based on JWT permissions.
    """

    collections_claim: str = "collections"  # JWT claim with allowed collection IDs
    admin_claim: str = "superuser"  # JWT claim indicating superuser status
    public_collections_filter: str = "(private IS NULL OR private = false)"

    cache_ttl: int = 30  # TTL for caching public collections, in seconds
    _client: httpx.AsyncClient = dataclasses.field(
        init=False,
        repr=False,
        default_factory=lambda: httpx.AsyncClient(base_url=UPSTREAM_URL),
    )
    _public_collections_cache: Optional[list[str]] = dataclasses.field(
        init=False, default=None, repr=False
    )
    _cache_expiry: float = dataclasses.field(init=False, default=0, repr=False)
    _cache_lock: asyncio.Lock = dataclasses.field(
        init=False, repr=False, default_factory=asyncio.Lock
    )

    @property
    def _cached_public_collections(self) -> Optional[list[str]]:
        """Return cached public collections if still valid, otherwise None."""
        if time.time() < self._cache_expiry:
            return self._public_collections_cache
        return None

    @_cached_public_collections.setter
    def _cached_public_collections(self, value: list[str]) -> None:
        """Set the cache with a new value and expiry time."""
        self._public_collections_cache = value
        self._cache_expiry = time.time() + self.cache_ttl

    async def _get_public_collections_ids(self) -> list[str]:
        """
        Retrieve IDs of public collections from the upstream API.
        Uses a lock to prevent concurrent requests from fetching the same data.
        """
        # Return cached value if still valid (fast path without lock)
        if (cached := self._cached_public_collections) is not None:
            logger.debug("Using cached public collections")
            return cached

        # Acquire lock to prevent concurrent fetches
        async with self._cache_lock:
            # Double-check cache after acquiring lock
            # Another coroutine might have populated it while we waited
            if (cached := self._cached_public_collections) is not None:
                logger.debug("Using cached public collections (after lock)")
                return cached

            logger.debug("Fetching public collections from upstream API")

            # First request uses params dict
            url: Optional[str] = "/collections"
            params: Optional[dict[str, Any]] = {
                "filter": self.public_collections_filter,
                "limit": 100,
            }

            ids = []
            while url:
                try:
                    response = await self._client.get(url, params=params)
                    response.raise_for_status()
                    data = response.json()
                except httpx.HTTPError:
                    logger.exception(f"Failed to fetch {url!r}.")
                    raise
                ids.extend(collection["id"] for collection in data["collections"])

                # Subsequent requests use the "next" link URL directly (already has params)
                url = next(
                    (link["href"] for link in data["links"] if link["rel"] == "next"),
                    None,
                )
                params = None  # Clear params after first request

            # Update cache
            self._cached_public_collections = ids
            return ids

    async def __call__(self, context: dict[str, Any]) -> str:
        jwt_payload: Optional[dict[str, Any]] = context.get("payload")

        # Superuser: no filter
        if jwt_payload and jwt_payload.get(self.admin_claim) == 'true':
            logger.debug(
                f"Superuser detected for sub {jwt_payload.get('sub')}, "
                "no filter applied for items"
            )
            return "1=1"

        # Everyone: Allowed access to items in public collections
        try:
            permitted_collections = set(await self._get_public_collections_ids())
        except httpx.HTTPError:
            logger.warning("Failed to fetch public collections.")
            permitted_collections = set()

        # Authenticated user: Allowed to access items in collections mentioned in JWT
        if jwt_payload:
            permitted_collections.update(jwt_payload.get(self.collections_claim, []))

        return cql2_in_query("collection", permitted_collections)

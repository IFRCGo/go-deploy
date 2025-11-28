"""
Logic for generating CQL2 filters based on JWT.
"""

import dataclasses
import os
import time
import logging
from typing import Any, Optional

import httpx

logger = logging.getLogger(__name__)


@dataclasses.dataclass
class CollectionsFilter:
    """
    CQL2 filter factory for collections based on JWT permissions.
    """

    collections_claim: str = "collections"  # JWT claim with allowed collection IDs
    admin_claim: str = "superuser"  # JWT claim indicating superuser status
    public_collections_filter: str = "private IS NULL OR private = false"

    async def __call__(self, context: dict[str, Any]) -> str:
        jwt_payload = context.get("payload", {})
        if jwt_payload.get(self.admin_claim):
            logger.info(
                f"Superuser detected for sub {jwt_payload.get('sub')}, "
                "no filter applied for collections"
            )
            return "1=1"  # No filter for superusers

        # Allowed to access collections in specified collections
        permitted_collections = jwt_payload.get(self.collections_claim, [])
        return " OR ".join(
            [
                # Include public collections
                self.public_collections_filter,
                # Include permitted collections
                *[f"id = '{collection_id}'" for collection_id in permitted_collections],
            ]
        )


@dataclasses.dataclass
class ItemsFilter:
    """
    CQL2 filter factory for items based on JWT permissions.
    """

    collections_claim: str = "collections"  # JWT claim with allowed collection IDs
    admin_claim: str = "superuser"  # JWT claim indicating superuser status
    public_collections_filter: str = "private IS NULL OR private = false"

    cache_ttl: int = 30  # TTL for caching public collections, in seconds
    _client: httpx.AsyncClient = dataclasses.field(
        init=False,
        repr=False,
        default_factory=lambda: httpx.AsyncClient(base_url=os.environ["UPSTREAM_URL"]),
    )
    _public_collections_cache: Optional[list[str]] = dataclasses.field(
        init=False, default=None, repr=False
    )
    _cache_expiry: float = dataclasses.field(init=False, default=0, repr=False)

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
        """
        # Return cached value if still valid
        if (cached := self._cached_public_collections) is not None:
            logger.debug("Using cached public collections")
            return cached

        logger.info("Fetching public collections from upstream API")

        # First request uses params dict
        url: Optional[str] = "/collections"
        params: Optional[dict[str, Any]] = {
            "filter": self.public_collections_filter,
            "limit": 100,
        }

        ids = []
        while url:
            response = await self._client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
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
        jwt_payload = context.get("payload", {})
        if jwt_payload.get(self.admin_claim):
            logger.info(
                f"Superuser detected for sub {jwt_payload.get('sub')}, "
                "no filter applied for items"
            )
            return "1=1"  # No filter for superusers

        # Allowed to access items in specified collections
        permitted_collections = set(jwt_payload.get(self.collections_claim, []))
        # Allowed to access items in public collections
        permitted_collections.update(await self._get_public_collections_ids())

        return " OR ".join(
            f"collection = '{collection_id}'" for collection_id in permitted_collections
        )

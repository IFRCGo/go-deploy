"""
Logic for generating CQL2 filters based on JWT.
"""

import dataclasses
import os
import time
from functools import wraps
from typing import Any, Callable, Optional

import httpx


PUBLIC_COLLECTIONS_FILTER = "private IS NULL OR private = false"


def async_ttl_cache(default_ttl: int = 30):
    """
    Decorator to cache async method results with a time-to-live.

    Args:
        ttl: Either an integer (seconds) or a string attribute name to read from the instance
    """

    def decorator(func: Callable):
        cache_attr = f"_cache_{func.__name__}"
        expiry_attr = f"_cache_expiry_{func.__name__}"

        @wraps(func)
        async def wrapper(self, *args, **kwargs):
            # Get TTL value (either from instance attribute or fallback to default)
            ttl_value = getattr(self, "cache_ttl", default_ttl)

            # Check if cache exists and is valid
            if (
                hasattr(self, cache_attr)
                and hasattr(self, expiry_attr)
                and time.time() < getattr(self, expiry_attr)
            ):
                return getattr(self, cache_attr)

            # Call the function and cache result
            result = await func(self, *args, **kwargs)
            setattr(self, cache_attr, result)
            setattr(self, expiry_attr, time.time() + ttl_value)
            return result

        return wrapper

    return decorator


@dataclasses.dataclass
class CollectionsFilter:
    collections_claim: str = "collections"

    async def __call__(self, context: dict[str, Any]) -> str:
        """
        CQL2 filter for collections based on JWT permissions.
        """
        jwt_payload = context.get("payload", {})
        permitted_collections = jwt_payload.get(self.collections_claim, [])

        return " OR ".join(
            [
                # Include public collections
                PUBLIC_COLLECTIONS_FILTER,
                # Include permitted collections
                *[f"id = '{collection_id}'" for collection_id in permitted_collections],
            ]
        )


@dataclasses.dataclass
class ItemsFilter:
    collections_claim: str = "collections"
    client: httpx.AsyncClient = dataclasses.field(init=False)
    cache_ttl: Optional[int] = None

    def __post_init__(self):
        self.client = httpx.AsyncClient(base_url=os.environ["UPSTREAM_URL"])

    @async_ttl_cache(
        default_ttl=300
    )  # Read TTL from instance attribute, can be overridden with cache_ttl class param
    async def get_public_collections_ids(self) -> list[str]:
        ids = []

        # First request uses params dict
        url: Optional[str] = "/collections"
        params: Optional[dict[str, Any]] = {
            "filter": PUBLIC_COLLECTIONS_FILTER,
            "limit": 100,
        }

        while url:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            ids.extend([collection["id"] for collection in data["collections"]])

            # Subsequent requests use the "next" link URL directly (already has params)
            url = next(
                (link["href"] for link in data["links"] if link["rel"] == "next"),
                None,
            )
            params = None  # Clear params after first request

        return ids

    async def __call__(self, context: dict[str, Any]) -> str:
        """
        CQL2 filter for items based on JWT permissions.
        """
        jwt_payload = context.get("payload", {})
        permitted_collections = set(
            # Get IDs of public collections (we can't lookup Items by a property of their parent Collection)
            await self.get_public_collections_ids()
            # Include permitted collections
            + jwt_payload.get(self.collections_claim, [])
        )
        return " OR ".join(
            f"collection = '{collection_id}'" for collection_id in permitted_collections
        )

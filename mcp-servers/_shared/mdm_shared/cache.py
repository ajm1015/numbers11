"""TTL-based in-memory cache for API responses."""

import time
from typing import Any, Optional


class TTLCache:
    """Simple TTL-based in-memory cache.

    Stores key-value pairs with per-entry expiration times.
    Thread-safe for single-threaded async usage (no locks needed).
    """

    def __init__(self, default_ttl: int = 300) -> None:
        self._store: dict[str, tuple[float, Any]] = {}
        self._default_ttl = default_ttl

    def get(self, key: str) -> Optional[Any]:
        """Get a value by key, returning None if missing or expired."""
        if key in self._store:
            expiry, value = self._store[key]
            if time.monotonic() < expiry:
                return value
            del self._store[key]
        return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """Set a value with optional custom TTL (seconds)."""
        expiry = time.monotonic() + (ttl if ttl is not None else self._default_ttl)
        self._store[key] = (expiry, value)

    def invalidate(self, key: str) -> None:
        """Remove a specific key from the cache."""
        self._store.pop(key, None)

    def invalidate_prefix(self, prefix: str) -> None:
        """Remove all keys matching a prefix."""
        keys_to_remove = [k for k in self._store if k.startswith(prefix)]
        for key in keys_to_remove:
            del self._store[key]

    def clear(self) -> None:
        """Remove all entries from the cache."""
        self._store.clear()

    @property
    def size(self) -> int:
        """Return the number of entries (including expired but not yet evicted)."""
        return len(self._store)

    def cleanup(self) -> int:
        """Evict all expired entries. Returns count of evicted entries."""
        now = time.monotonic()
        expired = [k for k, (expiry, _) in self._store.items() if now >= expiry]
        for key in expired:
            del self._store[key]
        return len(expired)

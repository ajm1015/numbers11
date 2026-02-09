"""Tests for TTLCache."""

import time
from unittest.mock import patch

from mdm_shared.cache import TTLCache


class TestTTLCache:
    def test_set_and_get(self) -> None:
        cache = TTLCache(default_ttl=300)
        cache.set("key1", "value1")
        assert cache.get("key1") == "value1"

    def test_get_missing_key_returns_none(self) -> None:
        cache = TTLCache()
        assert cache.get("nonexistent") is None

    def test_expired_entry_returns_none(self) -> None:
        cache = TTLCache(default_ttl=300)

        with patch("mdm_shared.cache.time") as mock_time:
            mock_time.monotonic.return_value = 1000.0
            cache.set("key1", "value1", ttl=10)

            # Before expiry
            mock_time.monotonic.return_value = 1009.0
            assert cache.get("key1") == "value1"

            # After expiry
            mock_time.monotonic.return_value = 1011.0
            assert cache.get("key1") is None

    def test_custom_ttl_overrides_default(self) -> None:
        cache = TTLCache(default_ttl=300)

        with patch("mdm_shared.cache.time") as mock_time:
            mock_time.monotonic.return_value = 1000.0
            cache.set("short", "val", ttl=5)
            cache.set("long", "val", ttl=600)

            mock_time.monotonic.return_value = 1006.0
            assert cache.get("short") is None
            assert cache.get("long") == "val"

    def test_invalidate(self) -> None:
        cache = TTLCache()
        cache.set("key1", "value1")
        cache.invalidate("key1")
        assert cache.get("key1") is None

    def test_invalidate_nonexistent_key_is_noop(self) -> None:
        cache = TTLCache()
        cache.invalidate("nonexistent")  # Should not raise

    def test_invalidate_prefix(self) -> None:
        cache = TTLCache()
        cache.set("device:abc", "data1")
        cache.set("device:def", "data2")
        cache.set("blueprint:xyz", "data3")

        cache.invalidate_prefix("device:")

        assert cache.get("device:abc") is None
        assert cache.get("device:def") is None
        assert cache.get("blueprint:xyz") == "data3"

    def test_clear(self) -> None:
        cache = TTLCache()
        cache.set("a", 1)
        cache.set("b", 2)
        cache.clear()
        assert cache.get("a") is None
        assert cache.get("b") is None
        assert cache.size == 0

    def test_size(self) -> None:
        cache = TTLCache()
        assert cache.size == 0
        cache.set("a", 1)
        cache.set("b", 2)
        assert cache.size == 2

    def test_cleanup_evicts_expired(self) -> None:
        cache = TTLCache()

        with patch("mdm_shared.cache.time") as mock_time:
            mock_time.monotonic.return_value = 1000.0
            cache.set("expired", "val", ttl=5)
            cache.set("valid", "val", ttl=600)

            mock_time.monotonic.return_value = 1006.0
            evicted = cache.cleanup()

            assert evicted == 1
            assert cache.size == 1
            assert cache.get("valid") == "val"

    def test_overwrite_existing_key(self) -> None:
        cache = TTLCache()
        cache.set("key", "old")
        cache.set("key", "new")
        assert cache.get("key") == "new"

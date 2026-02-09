"""Tests for the Kandji API client."""

import pytest
import httpx
import respx

from mdm_shared.cache import TTLCache
from mdm_shared.clients.kandji import KandjiClient, KandjiAPIError


BASE_URL = "https://test-tenant.api.kandji.io/api/v1"


@pytest.fixture
def cache() -> TTLCache:
    return TTLCache(default_ttl=300)


@pytest.fixture
def client(cache: TTLCache) -> KandjiClient:
    return KandjiClient(
        subdomain="test-tenant",
        api_token="test-token",
        cache=cache,
    )


@pytest.mark.asyncio
class TestKandjiClient:
    @respx.mock
    async def test_list_devices(self, client: KandjiClient, kandji_devices_json: list[dict]) -> None:
        respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(200, json=kandji_devices_json)
        )

        devices = await client.list_devices()
        assert len(devices) == 2
        assert devices[0].device_name == "Jack's MacBook Pro"
        assert devices[0].serial_number == "C02XYZ12345"
        assert devices[1].platform == "iPad"

        await client.close()

    @respx.mock
    async def test_list_devices_with_platform_filter(self, client: KandjiClient) -> None:
        respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(200, json=[
                {"device_id": "abc", "device_name": "Mac 1", "platform": "Mac"}
            ])
        )

        devices = await client.list_devices(platform="Mac")
        assert len(devices) == 1
        assert devices[0].platform == "Mac"

        await client.close()

    @respx.mock
    async def test_list_devices_pagination(self, client: KandjiClient) -> None:
        """Test that pagination loops until a page returns fewer than page_size items."""
        # Override page size for test
        client._page_size = 2

        page1 = [
            {"device_id": "a", "device_name": "Device A"},
            {"device_id": "b", "device_name": "Device B"},
        ]
        page2 = [
            {"device_id": "c", "device_name": "Device C"},
        ]

        route = respx.get(f"{BASE_URL}/v1/devices")
        route.side_effect = [
            httpx.Response(200, json=page1),
            httpx.Response(200, json=page2),
        ]

        devices = await client.list_devices()
        assert len(devices) == 3
        assert route.call_count == 2

        await client.close()

    @respx.mock
    async def test_get_device_details(self, client: KandjiClient, kandji_device_detail_json: dict) -> None:
        device_id = "abc12345-1234-5678-abcd-1234567890ab"
        respx.get(f"{BASE_URL}/v1/devices/{device_id}/details").mock(
            return_value=httpx.Response(200, json=kandji_device_detail_json)
        )

        details = await client.get_device_details(device_id)
        assert details.hardware_overview is not None
        assert details.hardware_overview["serial_number"] == "C02XYZ12345"
        assert details.filevault is not None
        assert details.filevault["filevault_enabled"] is True

        await client.close()

    @respx.mock
    async def test_get_device_by_serial_found(self, client: KandjiClient, kandji_devices_json: list[dict]) -> None:
        respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(200, json=kandji_devices_json)
        )

        device = await client.get_device_by_serial("C02XYZ12345")
        assert device is not None
        assert device.device_name == "Jack's MacBook Pro"

        await client.close()

    @respx.mock
    async def test_get_device_by_serial_not_found(self, client: KandjiClient) -> None:
        respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(200, json=[])
        )

        device = await client.get_device_by_serial("NONEXISTENT")
        assert device is None

        await client.close()

    @respx.mock
    async def test_rate_limit_retry(self, client: KandjiClient) -> None:
        route = respx.get(f"{BASE_URL}/v1/devices")
        route.side_effect = [
            httpx.Response(429, headers={"Retry-After": "0"}),
            httpx.Response(200, json=[]),
        ]

        devices = await client.list_devices()
        assert len(devices) == 0
        assert route.call_count == 2

        await client.close()

    @respx.mock
    async def test_api_error_raises(self, client: KandjiClient) -> None:
        respx.get(f"{BASE_URL}/v1/devices/bad-id").mock(
            return_value=httpx.Response(404, text="Not Found")
        )

        with pytest.raises(KandjiAPIError) as exc_info:
            await client.get_device("bad-id")

        assert exc_info.value.status_code == 404

        await client.close()

    @respx.mock
    async def test_send_device_action(self, client: KandjiClient) -> None:
        device_id = "abc123"
        respx.post(f"{BASE_URL}/v1/devices/{device_id}/action/blankpush").mock(
            return_value=httpx.Response(200, json={"success": True, "message": "Push sent"})
        )

        result = await client.send_device_action(device_id, "blankpush")
        assert result.success is True

        await client.close()

    @respx.mock
    async def test_cache_hit_skips_api_call(self, client: KandjiClient, kandji_devices_json: list[dict]) -> None:
        route = respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(200, json=kandji_devices_json)
        )

        # First call hits API
        devices1 = await client.list_devices()
        # Second call should hit cache
        devices2 = await client.list_devices()

        assert len(devices1) == len(devices2) == 2
        assert route.call_count == 1  # Only one API call

        await client.close()

    @respx.mock
    async def test_check_connectivity_success(self, client: KandjiClient) -> None:
        respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(200, json=[])
        )

        assert await client.check_connectivity() is True
        await client.close()

    @respx.mock
    async def test_check_connectivity_failure(self, client: KandjiClient) -> None:
        respx.get(f"{BASE_URL}/v1/devices").mock(
            return_value=httpx.Response(401, text="Unauthorized")
        )

        assert await client.check_connectivity() is False
        await client.close()

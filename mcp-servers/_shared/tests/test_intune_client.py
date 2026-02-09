"""Tests for the Intune (Graph API) client."""

import pytest
import httpx
import respx

from mdm_shared.auth.azure import AzureADAuth
from mdm_shared.cache import TTLCache
from mdm_shared.clients.intune import IntuneClient, IntuneAPIError


GRAPH_BASE = "https://graph.microsoft.com/v1.0"
TOKEN_URL = "https://login.microsoftonline.com/test-tenant/oauth2/v2.0/token"

TOKEN_RESPONSE = {
    "access_token": "test-graph-token",
    "token_type": "Bearer",
    "expires_in": 3600,
}


@pytest.fixture
def auth() -> AzureADAuth:
    return AzureADAuth(
        tenant_id="test-tenant",
        client_id="test-client",
        client_secret="test-secret",
    )


@pytest.fixture
def cache() -> TTLCache:
    return TTLCache(default_ttl=300)


@pytest.fixture
def client(auth: AzureADAuth, cache: TTLCache) -> IntuneClient:
    return IntuneClient(auth=auth, cache=cache)


def _mock_token() -> None:
    """Set up the token endpoint mock."""
    respx.post(TOKEN_URL).mock(return_value=httpx.Response(200, json=TOKEN_RESPONSE))


@pytest.mark.asyncio
class TestIntuneClient:
    @respx.mock
    async def test_list_devices(self, client: IntuneClient, intune_devices_json: dict) -> None:
        _mock_token()
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices").mock(
            return_value=httpx.Response(200, json=intune_devices_json)
        )

        devices = await client.list_devices()
        assert len(devices) == 2
        assert devices[0].device_name == "DESKTOP-ABC123"
        assert devices[0].serial_number == "PF4WXYZ1"
        assert devices[1].operating_system == "iOS"

        await client.close()

    @respx.mock
    async def test_list_devices_with_os_filter(self, client: IntuneClient) -> None:
        _mock_token()
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices").mock(
            return_value=httpx.Response(200, json={
                "value": [
                    {"id": "111", "deviceName": "Win PC", "operatingSystem": "Windows"}
                ]
            })
        )

        devices = await client.list_devices(os_filter="Windows")
        assert len(devices) == 1

        await client.close()

    @respx.mock
    async def test_pagination_follows_next_link(self, client: IntuneClient) -> None:
        _mock_token()

        next_link = f"{GRAPH_BASE}/deviceManagement/managedDevices?$skiptoken=abc"

        # Use side_effect to return different responses sequentially.
        # The first request (with $top param) returns a nextLink,
        # the second request (following the nextLink) returns the final page.
        route = respx.get(url__startswith=f"{GRAPH_BASE}/deviceManagement/managedDevices")
        route.side_effect = [
            httpx.Response(200, json={
                "value": [{"id": "1", "deviceName": "Device 1"}],
                "@odata.nextLink": next_link,
            }),
            httpx.Response(200, json={
                "value": [{"id": "2", "deviceName": "Device 2"}],
            }),
        ]

        devices = await client.list_devices()
        assert len(devices) == 2
        assert route.call_count == 2

        await client.close()

    @respx.mock
    async def test_get_device(self, client: IntuneClient, intune_device_detail_json: dict) -> None:
        _mock_token()
        device_id = "11111111-aaaa-bbbb-cccc-dddddddddddd"
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices/{device_id}").mock(
            return_value=httpx.Response(200, json=intune_device_detail_json)
        )

        device = await client.get_device(device_id)
        assert device.device_name == "DESKTOP-ABC123"
        assert device.is_encrypted is True
        assert device.compliance_state is not None
        assert device.compliance_state.value == "compliant"

        await client.close()

    @respx.mock
    async def test_get_device_by_serial(self, client: IntuneClient) -> None:
        _mock_token()
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices").mock(
            return_value=httpx.Response(200, json={
                "value": [
                    {"id": "111", "deviceName": "Found", "serialNumber": "ABC123"}
                ]
            })
        )

        device = await client.get_device_by_serial("ABC123")
        assert device is not None
        assert device.device_name == "Found"

        await client.close()

    @respx.mock
    async def test_get_device_by_serial_not_found(self, client: IntuneClient) -> None:
        _mock_token()
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices").mock(
            return_value=httpx.Response(200, json={"value": []})
        )

        device = await client.get_device_by_serial("NONEXISTENT")
        assert device is None

        await client.close()

    @respx.mock
    async def test_rate_limit_retry(self, client: IntuneClient) -> None:
        _mock_token()
        route = respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices")
        route.side_effect = [
            httpx.Response(429, headers={"Retry-After": "0"}),
            httpx.Response(200, json={"value": []}),
        ]

        devices = await client.list_devices()
        assert len(devices) == 0

        await client.close()

    @respx.mock
    async def test_api_error_raises(self, client: IntuneClient) -> None:
        _mock_token()
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices/bad-id").mock(
            return_value=httpx.Response(404, json={
                "error": {
                    "code": "Request_ResourceNotFound",
                    "message": "Resource not found",
                }
            })
        )

        with pytest.raises(IntuneAPIError) as exc_info:
            await client.get_device("bad-id")

        assert exc_info.value.status_code == 404
        assert exc_info.value.error_code == "Request_ResourceNotFound"

        await client.close()

    @respx.mock
    async def test_send_device_action(self, client: IntuneClient) -> None:
        _mock_token()
        device_id = "111"
        respx.post(f"{GRAPH_BASE}/deviceManagement/managedDevices/{device_id}/syncDevice").mock(
            return_value=httpx.Response(204)
        )

        result = await client.send_device_action(device_id, "syncDevice")
        assert result is True

        await client.close()

    @respx.mock
    async def test_cache_hit_skips_api_call(self, client: IntuneClient, intune_devices_json: dict) -> None:
        _mock_token()
        route = respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices").mock(
            return_value=httpx.Response(200, json=intune_devices_json)
        )

        devices1 = await client.list_devices()
        devices2 = await client.list_devices()

        assert len(devices1) == len(devices2) == 2
        assert route.call_count == 1

        await client.close()

    @respx.mock
    async def test_check_connectivity_success(self, client: IntuneClient) -> None:
        _mock_token()
        respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices").mock(
            return_value=httpx.Response(200, json={"value": []})
        )

        assert await client.check_connectivity() is True
        await client.close()

    @respx.mock
    async def test_401_triggers_token_refresh(self, client: IntuneClient) -> None:
        token_route = respx.post(TOKEN_URL)
        token_route.side_effect = [
            httpx.Response(200, json=TOKEN_RESPONSE),
            httpx.Response(200, json={**TOKEN_RESPONSE, "access_token": "new-token"}),
        ]

        device_route = respx.get(f"{GRAPH_BASE}/deviceManagement/managedDevices")
        device_route.side_effect = [
            httpx.Response(401, json={"error": {"code": "InvalidAuthenticationToken"}}),
            httpx.Response(200, json={"value": []}),
        ]

        devices = await client.list_devices()
        assert len(devices) == 0
        assert device_route.call_count == 2
        assert token_route.call_count == 2

        await client.close()

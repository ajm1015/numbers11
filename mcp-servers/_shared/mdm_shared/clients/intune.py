"""Async HTTP client for the Microsoft Intune (Graph API)."""

import asyncio
import logging
from typing import Any, Optional

import httpx

from mdm_shared.auth.azure import AzureADAuth, AzureAuthError
from mdm_shared.cache import TTLCache
from mdm_shared.models.intune import (
    IntuneCompliancePolicy,
    IntuneDeviceConfiguration,
    IntuneManagedDevice,
    IntuneMobileApp,
)

logger = logging.getLogger(__name__)

GRAPH_BASE_URL = "https://graph.microsoft.com"
DEFAULT_PAGE_SIZE = 100
DEFAULT_MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30.0


class IntuneAPIError(Exception):
    """Raised when an Intune/Graph API request fails."""

    def __init__(
        self,
        message: str,
        status_code: int | None = None,
        error_code: str | None = None,
        response_body: str = "",
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.error_code = error_code
        self.response_body = response_body


class IntuneClient:
    """Async client for Microsoft Intune via the Graph API.

    Handles OAuth2 authentication, OData pagination (@odata.nextLink),
    rate limiting (429 with Retry-After), and response parsing.
    """

    def __init__(
        self,
        auth: AzureADAuth,
        api_version: str = "v1.0",
        page_size: int = DEFAULT_PAGE_SIZE,
        max_retries: int = DEFAULT_MAX_RETRIES,
        timeout: float = DEFAULT_TIMEOUT,
        cache: TTLCache | None = None,
    ) -> None:
        self._auth = auth
        self._base_url = f"{GRAPH_BASE_URL}/{api_version}"
        self._page_size = page_size
        self._max_retries = max_retries
        self._timeout = timeout
        self._cache = cache or TTLCache()
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create the shared httpx client."""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(timeout=self._timeout)
        return self._client

    async def close(self) -> None:
        """Close the underlying HTTP client."""
        if self._client and not self._client.is_closed:
            await self._client.aclose()

    async def _get_auth_headers(self) -> dict[str, str]:
        """Get authorization headers with a valid token."""
        client = await self._get_client()
        token = await self._auth.get_token(client)
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    async def _request(
        self,
        method: str,
        url: str,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> httpx.Response:
        """Make an HTTP request with retry and rate limit handling.

        The url can be either a relative path (joined with base_url) or an
        absolute URL (used when following @odata.nextLink).
        """
        client = await self._get_client()

        if not url.startswith("https://"):
            url = f"{self._base_url}{url}"

        for attempt in range(1, self._max_retries + 1):
            headers = await self._get_auth_headers()

            try:
                response = await client.request(
                    method, url, headers=headers, params=params, json=json_body
                )

                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", "10"))
                    logger.warning(
                        "Graph API rate limited (429), retrying in %ds (attempt %d/%d)",
                        retry_after,
                        attempt,
                        self._max_retries,
                    )
                    await asyncio.sleep(retry_after)
                    continue

                if response.status_code == 401:
                    # Token may have expired between check and use
                    self._auth.invalidate()
                    if attempt < self._max_retries:
                        logger.warning("Got 401, refreshing token (attempt %d/%d)", attempt, self._max_retries)
                        continue

                if response.status_code >= 400:
                    error_body = response.text
                    error_code = None
                    try:
                        error_json = response.json()
                        error_code = error_json.get("error", {}).get("code")
                        error_msg = error_json.get("error", {}).get("message", error_body)
                    except Exception:
                        error_msg = error_body

                    raise IntuneAPIError(
                        f"Graph API error: {response.status_code} - {error_msg}",
                        status_code=response.status_code,
                        error_code=error_code,
                        response_body=error_body,
                    )

                return response

            except httpx.TimeoutException as exc:
                if attempt == self._max_retries:
                    raise IntuneAPIError(f"Request timed out after {self._max_retries} attempts: {exc}") from exc
                backoff = 2 ** (attempt - 1)
                logger.warning("Graph request timeout, retrying in %ds (attempt %d/%d)", backoff, attempt, self._max_retries)
                await asyncio.sleep(backoff)

            except httpx.HTTPError as exc:
                if attempt == self._max_retries:
                    raise IntuneAPIError(f"HTTP error after {self._max_retries} attempts: {exc}") from exc
                backoff = 2 ** (attempt - 1)
                logger.warning("Graph HTTP error, retrying in %ds (attempt %d/%d)", backoff, attempt, self._max_retries)
                await asyncio.sleep(backoff)

        raise IntuneAPIError(f"Request failed after {self._max_retries} attempts")

    async def _paginate(
        self,
        path: str,
        params: dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        """Fetch all pages from a paginated Graph API endpoint."""
        all_items: list[dict[str, Any]] = []
        base_params = dict(params) if params else {}

        if "$top" not in base_params:
            base_params["$top"] = self._page_size

        response = await self._request("GET", path, params=base_params)
        data = response.json()
        all_items.extend(data.get("value", []))

        next_link = data.get("@odata.nextLink")
        while next_link:
            response = await self._request("GET", next_link)
            data = response.json()
            all_items.extend(data.get("value", []))
            next_link = data.get("@odata.nextLink")

        return all_items

    # --- Device endpoints ---

    async def list_devices(
        self,
        os_filter: str | None = None,
        compliance_filter: str | None = None,
        select: list[str] | None = None,
    ) -> list[IntuneManagedDevice]:
        """List all managed devices with optional OData filters."""
        cache_key = f"devices:{os_filter or 'all'}:{compliance_filter or 'all'}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        params: dict[str, Any] = {}
        filters: list[str] = []

        if os_filter:
            filters.append(f"operatingSystem eq '{os_filter}'")
        if compliance_filter:
            filters.append(f"complianceState eq '{compliance_filter}'")

        if filters:
            params["$filter"] = " and ".join(filters)
        if select:
            params["$select"] = ",".join(select)

        raw_devices = await self._paginate("/deviceManagement/managedDevices", params=params)
        devices = [IntuneManagedDevice.model_validate(d) for d in raw_devices]
        self._cache.set(cache_key, devices)
        return devices

    async def get_device(self, device_id: str) -> IntuneManagedDevice:
        """Get a single managed device by ID."""
        cache_key = f"device:{device_id}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        response = await self._request("GET", f"/deviceManagement/managedDevices/{device_id}")
        device = IntuneManagedDevice.model_validate(response.json())
        self._cache.set(cache_key, device)
        return device

    async def get_device_by_serial(self, serial_number: str) -> IntuneManagedDevice | None:
        """Look up a device by serial number using OData filter."""
        params: dict[str, Any] = {
            "$filter": f"serialNumber eq '{serial_number}'",
            "$top": 1,
        }
        response = await self._request(
            "GET", "/deviceManagement/managedDevices", params=params
        )
        data = response.json()
        items = data.get("value", [])
        if items:
            return IntuneManagedDevice.model_validate(items[0])
        return None

    # --- Compliance policies ---

    async def list_compliance_policies(self) -> list[IntuneCompliancePolicy]:
        """List all device compliance policies."""
        cache_key = "compliance_policies"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        raw = await self._paginate("/deviceManagement/deviceCompliancePolicies")
        policies = [IntuneCompliancePolicy.model_validate(p) for p in raw]
        self._cache.set(cache_key, policies, ttl=900)
        return policies

    # --- Device configurations ---

    async def list_device_configurations(self) -> list[IntuneDeviceConfiguration]:
        """List all device configuration profiles."""
        cache_key = "device_configurations"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        raw = await self._paginate("/deviceManagement/deviceConfigurations")
        configs = [IntuneDeviceConfiguration.model_validate(c) for c in raw]
        self._cache.set(cache_key, configs, ttl=900)
        return configs

    # --- App management ---

    async def list_apps(
        self, app_type: str | None = None
    ) -> list[IntuneMobileApp]:
        """List managed mobile apps."""
        cache_key = f"apps:{app_type or 'all'}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        params: dict[str, Any] = {}
        if app_type:
            params["$filter"] = f"isof('{app_type}')"

        raw = await self._paginate("/deviceAppManagement/mobileApps", params=params)
        apps = [IntuneMobileApp.model_validate(a) for a in raw]
        self._cache.set(cache_key, apps)
        return apps

    # --- Remote actions ---

    async def send_device_action(self, device_id: str, action: str, payload: dict[str, Any] | None = None) -> bool:
        """Send a remote action to a managed device.

        Args:
            device_id: Intune device ID (GUID).
            action: Action name (syncDevice, rebootNow, remoteLock, shutdown, retire, wipe, etc.).
            payload: Optional JSON body for the action (e.g., wipe options).

        Returns:
            True if the action was accepted (204 No Content).
        """
        response = await self._request(
            "POST",
            f"/deviceManagement/managedDevices/{device_id}/{action}",
            json_body=payload,
        )

        # Invalidate cached device data after action
        self._cache.invalidate(f"device:{device_id}")
        self._cache.invalidate_prefix("devices:")

        return response.status_code in (200, 204)

    async def check_connectivity(self) -> bool:
        """Check if the Graph API is reachable with current credentials."""
        try:
            await self._request(
                "GET",
                "/deviceManagement/managedDevices",
                params={"$top": 1, "$select": "id"},
            )
            return True
        except (IntuneAPIError, AzureAuthError):
            return False

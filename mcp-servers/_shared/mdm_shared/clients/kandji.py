"""Async HTTP client for the Kandji API."""

import asyncio
import logging
from typing import Any, Optional

import httpx

from mdm_shared.cache import TTLCache
from mdm_shared.models.kandji import (
    KandjiActionResponse,
    KandjiApp,
    KandjiBlueprint,
    KandjiCustomApp,
    KandjiDevice,
    KandjiDeviceDetails,
)

logger = logging.getLogger(__name__)

US_API_URL = "https://{subdomain}.api.kandji.io/api/v1"
EU_API_URL = "https://{subdomain}.api.eu.kandji.io/api/v1"
DEFAULT_PAGE_SIZE = 300
DEFAULT_MAX_RETRIES = 3
DEFAULT_TIMEOUT = 30.0


class KandjiAPIError(Exception):
    """Raised when a Kandji API request fails."""

    def __init__(
        self, message: str, status_code: int | None = None, response_body: str = ""
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.response_body = response_body


class KandjiClient:
    """Async client for the Kandji MDM API.

    Handles authentication, pagination (limit/offset), rate limiting (429 retry),
    and response parsing into Pydantic models.
    """

    def __init__(
        self,
        subdomain: str,
        api_token: str,
        region: str = "us",
        page_size: int = DEFAULT_PAGE_SIZE,
        max_retries: int = DEFAULT_MAX_RETRIES,
        timeout: float = DEFAULT_TIMEOUT,
        cache: TTLCache | None = None,
    ) -> None:
        url_template = EU_API_URL if region == "eu" else US_API_URL
        self._base_url = url_template.format(subdomain=subdomain)
        self._headers = {
            "Authorization": f"Bearer {api_token}",
            "Accept": "application/json",
            "Content-Type": "application/json;charset=utf-8",
        }
        self._page_size = min(page_size, 300)
        self._max_retries = max_retries
        self._timeout = timeout
        self._cache = cache or TTLCache()
        self._client: httpx.AsyncClient | None = None

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create the shared httpx client."""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                base_url=self._base_url,
                headers=self._headers,
                timeout=self._timeout,
            )
        return self._client

    async def close(self) -> None:
        """Close the underlying HTTP client."""
        if self._client and not self._client.is_closed:
            await self._client.aclose()

    async def _request(
        self,
        method: str,
        path: str,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> httpx.Response:
        """Make an HTTP request with retry logic for rate limiting."""
        client = await self._get_client()

        for attempt in range(1, self._max_retries + 1):
            try:
                response = await client.request(
                    method, path, params=params, json=json_body
                )

                if response.status_code == 429:
                    retry_after = int(response.headers.get("Retry-After", "5"))
                    logger.warning(
                        "Kandji rate limited (429), retrying in %ds (attempt %d/%d)",
                        retry_after,
                        attempt,
                        self._max_retries,
                    )
                    await asyncio.sleep(retry_after)
                    continue

                if response.status_code >= 400:
                    raise KandjiAPIError(
                        f"Kandji API error: {response.status_code} on {method} {path}",
                        status_code=response.status_code,
                        response_body=response.text,
                    )

                return response

            except httpx.TimeoutException as exc:
                if attempt == self._max_retries:
                    raise KandjiAPIError(f"Request timed out after {self._max_retries} attempts: {exc}") from exc
                backoff = 2 ** (attempt - 1)
                logger.warning("Kandji request timeout, retrying in %ds (attempt %d/%d)", backoff, attempt, self._max_retries)
                await asyncio.sleep(backoff)

            except httpx.HTTPError as exc:
                if attempt == self._max_retries:
                    raise KandjiAPIError(f"HTTP error after {self._max_retries} attempts: {exc}") from exc
                backoff = 2 ** (attempt - 1)
                logger.warning("Kandji HTTP error, retrying in %ds (attempt %d/%d)", backoff, attempt, self._max_retries)
                await asyncio.sleep(backoff)

        raise KandjiAPIError(f"Request failed after {self._max_retries} attempts")

    async def _paginate(
        self, path: str, params: dict[str, Any] | None = None
    ) -> list[dict[str, Any]]:
        """Fetch all pages from a paginated Kandji endpoint."""
        all_items: list[dict[str, Any]] = []
        offset = 0
        base_params = dict(params) if params else {}

        while True:
            page_params = {**base_params, "limit": self._page_size, "offset": offset}
            response = await self._request("GET", path, params=page_params)
            items = response.json()

            if not isinstance(items, list):
                # Some endpoints return a dict with a key containing the list
                break

            all_items.extend(items)

            if len(items) < self._page_size:
                break

            offset += self._page_size

        return all_items

    # --- Device endpoints ---

    async def list_devices(
        self,
        platform: str | None = None,
        blueprint_id: str | None = None,
    ) -> list[KandjiDevice]:
        """List all devices with optional filters."""
        cache_key = f"devices:{platform or 'all'}:{blueprint_id or 'all'}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        params: dict[str, Any] = {}
        if platform:
            params["platform"] = platform
        if blueprint_id:
            params["blueprint_id"] = blueprint_id

        raw_devices = await self._paginate("/v1/devices", params=params)
        devices = [KandjiDevice.model_validate(d) for d in raw_devices]
        self._cache.set(cache_key, devices)
        return devices

    async def get_device(self, device_id: str) -> dict[str, Any]:
        """Get summary info for a single device."""
        cache_key = f"device:{device_id}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        response = await self._request("GET", f"/v1/devices/{device_id}")
        data = response.json()
        self._cache.set(cache_key, data)
        return data

    async def get_device_details(self, device_id: str) -> KandjiDeviceDetails:
        """Get full details for a single device."""
        cache_key = f"device_details:{device_id}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        response = await self._request("GET", f"/v1/devices/{device_id}/details")
        details = KandjiDeviceDetails.model_validate(response.json())
        self._cache.set(cache_key, details)
        return details

    async def get_device_by_serial(self, serial_number: str) -> KandjiDevice | None:
        """Look up a device by serial number."""
        devices = await self.list_devices()
        for device in devices:
            if device.serial_number and device.serial_number.upper() == serial_number.upper():
                return device
        return None

    async def get_device_apps(self, device_id: str) -> list[KandjiApp]:
        """List apps installed on a device."""
        cache_key = f"device_apps:{device_id}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        response = await self._request("GET", f"/v1/devices/{device_id}/apps")
        data = response.json()
        apps_list = data if isinstance(data, list) else data.get("apps", [])
        apps = [KandjiApp.model_validate(a) for a in apps_list]
        self._cache.set(cache_key, apps)
        return apps

    # --- Blueprint endpoints ---

    async def list_blueprints(self) -> list[KandjiBlueprint]:
        """List all blueprints."""
        cache_key = "blueprints"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        response = await self._request("GET", "/v1/blueprints")
        data = response.json()
        items = data if isinstance(data, list) else data.get("results", [])
        blueprints = [KandjiBlueprint.model_validate(b) for b in items]
        self._cache.set(cache_key, blueprints, ttl=1800)  # 30 min — blueprints change rarely
        return blueprints

    async def get_blueprint(self, blueprint_id: str) -> KandjiBlueprint:
        """Get a single blueprint."""
        cache_key = f"blueprint:{blueprint_id}"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        response = await self._request("GET", f"/v1/blueprints/{blueprint_id}")
        blueprint = KandjiBlueprint.model_validate(response.json())
        self._cache.set(cache_key, blueprint, ttl=1800)
        return blueprint

    # --- Library / Custom Apps ---

    async def list_custom_apps(self) -> list[KandjiCustomApp]:
        """List all custom apps in the library."""
        cache_key = "custom_apps"
        cached = self._cache.get(cache_key)
        if cached is not None:
            return cached

        raw_apps = await self._paginate("/v1/library/custom-apps")
        apps = [KandjiCustomApp.model_validate(a) for a in raw_apps]
        self._cache.set(cache_key, apps)
        return apps

    # --- Device actions ---

    async def send_device_action(
        self,
        device_id: str,
        action: str,
        payload: dict[str, Any] | None = None,
    ) -> KandjiActionResponse:
        """Send a device action command.

        Args:
            device_id: Target device UUID.
            action: Action name (blankpush, lock, restart, shutdown, erase, etc.).
            payload: Optional request body for the action.
        """
        response = await self._request(
            "POST",
            f"/v1/devices/{device_id}/action/{action}",
            json_body=payload,
        )

        # Invalidate device cache after action
        self._cache.invalidate_prefix(f"device:{device_id}")
        self._cache.invalidate_prefix(f"device_details:{device_id}")

        if response.status_code == 200:
            return KandjiActionResponse.model_validate(response.json())
        # Some actions return 204 No Content
        return KandjiActionResponse(success=True, message=f"Action '{action}' sent successfully")

    async def check_connectivity(self) -> bool:
        """Check if the Kandji API is reachable with current credentials."""
        try:
            await self._request("GET", "/v1/devices", params={"limit": 1})
            return True
        except KandjiAPIError:
            return False

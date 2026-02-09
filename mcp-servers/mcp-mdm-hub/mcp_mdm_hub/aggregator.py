"""Concurrent fetching and merging from multiple MDM backends."""

import asyncio
import logging
from typing import Optional

from mdm_shared.clients.kandji import KandjiClient, KandjiAPIError
from mdm_shared.clients.intune import IntuneClient, IntuneAPIError

from mcp_mdm_hub.models.unified import (
    DeviceSource,
    FleetSummary,
    UnifiedDevice,
)
from mcp_mdm_hub.normalizer import normalize_kandji_device, normalize_intune_device

logger = logging.getLogger(__name__)


class Aggregator:
    """Fetches device data from all configured MDM backends concurrently."""

    def __init__(
        self,
        kandji_client: KandjiClient,
        intune_client: IntuneClient,
    ) -> None:
        self._kandji = kandji_client
        self._intune = intune_client

    async def list_all_devices(
        self,
        platform_filter: str | None = None,
        source_filter: str | None = None,
    ) -> list[UnifiedDevice]:
        """Fetch devices from all MDMs concurrently, normalize, and merge.

        Args:
            platform_filter: Filter by unified platform name (macOS, Windows, iOS, etc.).
            source_filter: Filter by source (kandji, intune). If set, only queries that MDM.
        """
        tasks = []

        if source_filter is None or source_filter == "kandji":
            tasks.append(self._fetch_kandji_devices())
        if source_filter is None or source_filter == "intune":
            tasks.append(self._fetch_intune_devices())

        results = await asyncio.gather(*tasks, return_exceptions=True)

        all_devices: list[UnifiedDevice] = []
        for result in results:
            if isinstance(result, Exception):
                logger.error("MDM fetch error: %s", result)
                continue
            all_devices.extend(result)

        # Apply platform filter
        if platform_filter:
            normalized_filter = platform_filter.lower()
            all_devices = [
                d for d in all_devices
                if d.platform.value.lower() == normalized_filter
            ]

        return all_devices

    async def _fetch_kandji_devices(self) -> list[UnifiedDevice]:
        """Fetch and normalize all Kandji devices."""
        try:
            raw_devices = await self._kandji.list_devices()
            return [normalize_kandji_device(d) for d in raw_devices]
        except KandjiAPIError as exc:
            logger.error("Kandji API error: %s", exc)
            return []

    async def _fetch_intune_devices(self) -> list[UnifiedDevice]:
        """Fetch and normalize all Intune devices."""
        try:
            raw_devices = await self._intune.list_devices()
            return [normalize_intune_device(d) for d in raw_devices]
        except IntuneAPIError as exc:
            logger.error("Intune API error: %s", exc)
            return []

    async def get_device_by_serial(self, serial_number: str) -> list[UnifiedDevice]:
        """Search for a device by serial across all MDMs.

        Returns a list because the same serial could exist in both MDMs.
        """
        tasks = [
            self._search_kandji_serial(serial_number),
            self._search_intune_serial(serial_number),
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        devices: list[UnifiedDevice] = []
        for result in results:
            if isinstance(result, Exception):
                logger.error("Serial search error: %s", result)
                continue
            if result is not None:
                devices.append(result)

        return devices

    async def _search_kandji_serial(self, serial: str) -> UnifiedDevice | None:
        """Search Kandji for a device by serial."""
        try:
            device = await self._kandji.get_device_by_serial(serial)
            if device:
                return normalize_kandji_device(device)
        except KandjiAPIError as exc:
            logger.error("Kandji serial search error: %s", exc)
        return None

    async def _search_intune_serial(self, serial: str) -> UnifiedDevice | None:
        """Search Intune for a device by serial."""
        try:
            device = await self._intune.get_device_by_serial(serial)
            if device:
                return normalize_intune_device(device)
        except IntuneAPIError as exc:
            logger.error("Intune serial search error: %s", exc)
        return None

    async def fleet_summary(self) -> FleetSummary:
        """Generate aggregate fleet statistics across all MDMs."""
        all_devices = await self.list_all_devices()

        summary = FleetSummary(total_devices=len(all_devices))

        for device in all_devices:
            # By source
            source_key = device.source.value
            summary.by_source[source_key] = summary.by_source.get(source_key, 0) + 1

            # By platform
            platform_key = device.platform.value
            summary.by_platform[platform_key] = summary.by_platform.get(platform_key, 0) + 1

            # By compliance
            compliance_key = device.compliance_status.value
            summary.by_compliance[compliance_key] = summary.by_compliance.get(compliance_key, 0) + 1

            # By ownership
            ownership_key = device.ownership.value
            summary.by_ownership[ownership_key] = summary.by_ownership.get(ownership_key, 0) + 1

        return summary

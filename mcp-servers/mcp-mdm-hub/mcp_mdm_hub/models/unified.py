"""Unified device schema — the design center of the MDM hub.

This module defines the canonical normalized device model that maps
fields from both Kandji and Intune into a single queryable schema.
"""

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


class DeviceSource(str, Enum):
    """Which MDM platform a device comes from."""

    KANDJI = "kandji"
    INTUNE = "intune"


class DevicePlatform(str, Enum):
    """Normalized device platform."""

    MACOS = "macOS"
    IOS = "iOS"
    IPADOS = "iPadOS"
    WINDOWS = "Windows"
    ANDROID = "Android"
    TVOS = "tvOS"
    LINUX = "Linux"
    UNKNOWN = "Unknown"


class ComplianceStatus(str, Enum):
    """Normalized compliance status across MDM platforms."""

    COMPLIANT = "compliant"
    NONCOMPLIANT = "noncompliant"
    UNKNOWN = "unknown"
    NOT_APPLICABLE = "not_applicable"


class OwnershipType(str, Enum):
    """Device ownership classification."""

    CORPORATE = "corporate"
    PERSONAL = "personal"
    UNKNOWN = "unknown"


class UnifiedDeviceUser(BaseModel):
    """Normalized user assignment."""

    name: Optional[str] = None
    email: Optional[str] = None
    principal_name: Optional[str] = None


class UnifiedDeviceHardware(BaseModel):
    """Normalized hardware information."""

    serial_number: Optional[str] = None
    model: Optional[str] = None
    model_identifier: Optional[str] = None
    manufacturer: Optional[str] = None
    processor: Optional[str] = None
    memory_bytes: Optional[int] = None
    total_storage_bytes: Optional[int] = None
    free_storage_bytes: Optional[int] = None


class UnifiedDeviceNetwork(BaseModel):
    """Normalized network information."""

    ip_address: Optional[str] = None
    public_ip: Optional[str] = None
    hostname: Optional[str] = None
    wifi_mac: Optional[str] = None
    ethernet_mac: Optional[str] = None


class UnifiedDeviceSecurity(BaseModel):
    """Normalized security posture."""

    encryption_enabled: Optional[bool] = None
    firewall_enabled: Optional[bool] = None
    supervised: Optional[bool] = None
    jailbroken: Optional[bool] = None
    activation_lock_enabled: Optional[bool] = None


class UnifiedDevice(BaseModel):
    """The canonical normalized device record.

    Maps fields from both Kandji and Intune into one unified schema.
    This is the primary data structure returned by all hub tools.
    """

    # Source tracking
    source: DeviceSource = Field(description="Which MDM this device comes from")
    source_id: str = Field(description="Original device ID in the source MDM")

    # Core identity
    device_name: Optional[str] = Field(None, description="Device display name")
    serial_number: Optional[str] = Field(None, description="Hardware serial number")
    platform: DevicePlatform = Field(DevicePlatform.UNKNOWN, description="Normalized platform")
    os_version: Optional[str] = Field(None, description="OS version string")

    # Management
    compliance_status: ComplianceStatus = Field(
        ComplianceStatus.UNKNOWN, description="Compliance status"
    )
    ownership: OwnershipType = Field(
        OwnershipType.UNKNOWN, description="Device ownership type"
    )
    enrolled_at: Optional[datetime] = Field(None, description="Enrollment timestamp")
    last_seen: Optional[datetime] = Field(None, description="Last check-in/sync timestamp")

    # Nested details
    user: Optional[UnifiedDeviceUser] = None
    hardware: Optional[UnifiedDeviceHardware] = None
    network: Optional[UnifiedDeviceNetwork] = None
    security: Optional[UnifiedDeviceSecurity] = None

    # Source-specific overflow
    source_metadata: Optional[dict[str, Any]] = Field(
        None, description="Source-specific fields not in the unified schema"
    )


class DeviceActionResult(BaseModel):
    """Result of a device action dispatched through the hub."""

    source: DeviceSource
    source_id: str
    action: str
    success: bool
    message: str


class FleetSummary(BaseModel):
    """Aggregate fleet statistics."""

    total_devices: int = 0
    by_source: dict[str, int] = Field(default_factory=dict)
    by_platform: dict[str, int] = Field(default_factory=dict)
    by_compliance: dict[str, int] = Field(default_factory=dict)
    by_ownership: dict[str, int] = Field(default_factory=dict)

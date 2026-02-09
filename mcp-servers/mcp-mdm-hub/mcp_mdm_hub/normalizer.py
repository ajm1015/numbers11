"""Normalization logic: Kandji + Intune raw data → UnifiedDevice.

This is the most critical and most tested module in the hub. Every field
mapping from source MDM data to the unified schema is defined here.
"""

from datetime import datetime
from typing import Any, Optional

from mdm_shared.models.kandji import KandjiDevice, KandjiDeviceDetails
from mdm_shared.models.intune import IntuneManagedDevice

from mcp_mdm_hub.models.unified import (
    ComplianceStatus,
    DevicePlatform,
    DeviceSource,
    OwnershipType,
    UnifiedDevice,
    UnifiedDeviceHardware,
    UnifiedDeviceNetwork,
    UnifiedDeviceSecurity,
    UnifiedDeviceUser,
)


# --- Platform normalization maps ---

KANDJI_PLATFORM_MAP: dict[str, DevicePlatform] = {
    "mac": DevicePlatform.MACOS,
    "iphone": DevicePlatform.IOS,
    "ipad": DevicePlatform.IPADOS,
    "appletv": DevicePlatform.TVOS,
}

INTUNE_PLATFORM_MAP: dict[str, DevicePlatform] = {
    "windows": DevicePlatform.WINDOWS,
    "ios": DevicePlatform.IOS,
    "macos": DevicePlatform.MACOS,
    "android": DevicePlatform.ANDROID,
    "linux": DevicePlatform.LINUX,
}


def _parse_datetime(value: Any) -> Optional[datetime]:
    """Safely parse a datetime string or return None."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _normalize_kandji_platform(platform: str | None) -> DevicePlatform:
    """Map Kandji platform string to unified enum."""
    if not platform:
        return DevicePlatform.UNKNOWN
    return KANDJI_PLATFORM_MAP.get(platform.lower(), DevicePlatform.UNKNOWN)


def _normalize_intune_platform(os: str | None) -> DevicePlatform:
    """Map Intune operatingSystem string to unified enum."""
    if not os:
        return DevicePlatform.UNKNOWN
    return INTUNE_PLATFORM_MAP.get(os.lower(), DevicePlatform.UNKNOWN)


def normalize_kandji_device(
    device: KandjiDevice,
    details: KandjiDeviceDetails | None = None,
) -> UnifiedDevice:
    """Transform a Kandji device into the unified schema.

    Args:
        device: Summary device from the list endpoint.
        details: Optional full details from the device details endpoint.
    """
    user_data = device.user or {}
    user = UnifiedDeviceUser(
        name=user_data.get("name"),
        email=user_data.get("email"),
    ) if user_data else None

    hardware: UnifiedDeviceHardware | None = None
    network: UnifiedDeviceNetwork | None = None
    security: UnifiedDeviceSecurity | None = None

    if details:
        hw = details.hardware_overview or {}
        hardware = UnifiedDeviceHardware(
            serial_number=hw.get("serial_number") or device.serial_number,
            model=hw.get("model_name") or device.model,
            model_identifier=hw.get("model_identifier"),
            processor=hw.get("processor_name"),
            manufacturer="Apple",
        )

        net = details.network or {}
        network = UnifiedDeviceNetwork(
            ip_address=net.get("ip_address"),
            public_ip=net.get("public_ip"),
            hostname=net.get("local_hostname"),
            wifi_mac=net.get("mac_address"),
        )

        fv = details.filevault or {}
        sec = details.security_information or {}
        al = details.activation_lock or {}
        security = UnifiedDeviceSecurity(
            encryption_enabled=fv.get("filevault_enabled"),
            firewall_enabled=sec.get("firewall_enabled"),
            activation_lock_enabled=al.get("activation_lock_enabled"),
        )

    return UnifiedDevice(
        source=DeviceSource.KANDJI,
        source_id=device.device_id,
        device_name=device.device_name,
        serial_number=device.serial_number,
        platform=_normalize_kandji_platform(device.platform),
        os_version=device.os_version,
        compliance_status=ComplianceStatus.NOT_APPLICABLE,  # Kandji doesn't expose a compliance state
        ownership=OwnershipType.UNKNOWN,  # Kandji doesn't expose ownership type
        last_seen=_parse_datetime(device.last_check_in),
        user=user,
        hardware=hardware,
        network=network,
        security=security,
        source_metadata={
            "blueprint_id": device.blueprint_id,
            "blueprint_name": device.blueprint_name,
            "asset_tag": device.asset_tag,
            "mdm_enabled": device.mdm_enabled,
        },
    )


def normalize_intune_device(device: IntuneManagedDevice) -> UnifiedDevice:
    """Transform an Intune managed device into the unified schema."""
    # Map compliance state
    compliance = ComplianceStatus.UNKNOWN
    if device.compliance_state:
        state_map = {
            "compliant": ComplianceStatus.COMPLIANT,
            "noncompliant": ComplianceStatus.NONCOMPLIANT,
        }
        compliance = state_map.get(device.compliance_state.value, ComplianceStatus.UNKNOWN)

    # Map ownership
    ownership = OwnershipType.UNKNOWN
    if device.owner_type:
        owner_map = {
            "company": OwnershipType.CORPORATE,
            "personal": OwnershipType.PERSONAL,
        }
        ownership = owner_map.get(device.owner_type.value, OwnershipType.UNKNOWN)

    # Map jailbroken string to bool
    jailbroken: bool | None = None
    if device.jail_broken is not None:
        jailbroken = device.jail_broken.lower() not in ("false", "unknown", "")

    user = UnifiedDeviceUser(
        name=device.user_display_name,
        email=device.email_address,
        principal_name=device.user_principal_name,
    )

    hardware = UnifiedDeviceHardware(
        serial_number=device.serial_number,
        model=device.model,
        manufacturer=device.manufacturer,
        total_storage_bytes=device.total_storage_bytes,
        free_storage_bytes=device.free_storage_bytes,
        memory_bytes=device.physical_memory_bytes,
    )

    security = UnifiedDeviceSecurity(
        encryption_enabled=device.is_encrypted,
        supervised=device.is_supervised,
        jailbroken=jailbroken,
    )

    return UnifiedDevice(
        source=DeviceSource.INTUNE,
        source_id=device.id,
        device_name=device.device_name,
        serial_number=device.serial_number,
        platform=_normalize_intune_platform(device.operating_system),
        os_version=device.os_version,
        compliance_status=compliance,
        ownership=ownership,
        enrolled_at=device.enrolled_date_time,
        last_seen=device.last_sync_date_time,
        user=user,
        hardware=hardware,
        security=security,
        source_metadata={
            "azure_ad_device_id": device.azure_ad_device_id,
            "management_agent": device.management_agent.value if device.management_agent else None,
            "device_enrollment_type": device.device_enrollment_type,
            "device_category": device.device_category_display_name,
        },
    )

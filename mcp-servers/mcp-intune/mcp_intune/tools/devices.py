"""Intune device management tools."""

from typing import Optional

from mcp_intune.server import intune_client, mcp


@mcp.tool()
async def intune_list_devices(
    os_filter: Optional[str] = None,
    compliance_filter: Optional[str] = None,
) -> str:
    """List all Intune managed devices.

    Paginates internally via @odata.nextLink to return all results.
    Optionally filter by operating system or compliance state.

    Args:
        os_filter: Filter by OS (e.g., 'Windows', 'iOS', 'macOS', 'Android').
        compliance_filter: Filter by compliance state (compliant, noncompliant, unknown).
    """
    devices = await intune_client.list_devices(
        os_filter=os_filter, compliance_filter=compliance_filter
    )
    if not devices:
        return "No managed devices found matching the given filters."

    lines = [f"Found {len(devices)} managed device(s):\n"]
    for d in devices:
        compliance = d.compliance_state.value if d.compliance_state else "unknown"
        last_sync = str(d.last_sync_date_time) if d.last_sync_date_time else "Never"
        lines.append(
            f"- {d.device_name or 'Unnamed'} | {d.serial_number or 'N/A'} | "
            f"{d.operating_system or 'Unknown'} {d.os_version or ''} | "
            f"Compliance: {compliance} | Last Sync: {last_sync}"
        )
    return "\n".join(lines)


@mcp.tool()
async def intune_get_device(device_id: str) -> str:
    """Get full details for a single Intune managed device.

    Args:
        device_id: The Intune device ID (GUID).
    """
    d = await intune_client.get_device(device_id)

    storage_total = f"{d.total_storage_bytes / (1024**3):.1f} GB" if d.total_storage_bytes else "N/A"
    storage_free = f"{d.free_storage_bytes / (1024**3):.1f} GB" if d.free_storage_bytes else "N/A"
    memory = f"{d.physical_memory_bytes / (1024**3):.1f} GB" if d.physical_memory_bytes else "N/A"

    return (
        f"Device: {d.device_name or 'Unknown'} ({d.id})\n"
        f"\nIdentity:\n"
        f"  Serial: {d.serial_number or 'N/A'}\n"
        f"  Azure AD ID: {d.azure_ad_device_id or 'N/A'}\n"
        f"  Model: {d.model or 'N/A'}\n"
        f"  Manufacturer: {d.manufacturer or 'N/A'}\n"
        f"\nOS:\n"
        f"  System: {d.operating_system or 'N/A'}\n"
        f"  Version: {d.os_version or 'N/A'}\n"
        f"\nManagement:\n"
        f"  Compliance: {d.compliance_state.value if d.compliance_state else 'unknown'}\n"
        f"  Owner: {d.owner_type.value if d.owner_type else 'unknown'}\n"
        f"  Enrolled: {d.enrolled_date_time or 'N/A'}\n"
        f"  Last Sync: {d.last_sync_date_time or 'N/A'}\n"
        f"\nUser:\n"
        f"  Name: {d.user_display_name or 'N/A'}\n"
        f"  UPN: {d.user_principal_name or 'N/A'}\n"
        f"  Email: {d.email_address or 'N/A'}\n"
        f"\nHardware:\n"
        f"  Storage: {storage_total} total, {storage_free} free\n"
        f"  Memory: {memory}\n"
        f"\nSecurity:\n"
        f"  Encrypted: {d.is_encrypted}\n"
        f"  Supervised: {d.is_supervised}\n"
        f"  Jailbroken: {d.jail_broken or 'N/A'}"
    )


@mcp.tool()
async def intune_get_device_by_serial(serial_number: str) -> str:
    """Look up an Intune managed device by serial number.

    Uses OData $filter for efficient server-side search.

    Args:
        serial_number: The hardware serial number.
    """
    device = await intune_client.get_device_by_serial(serial_number)
    if device is None:
        return f"No managed device found with serial number '{serial_number}'."

    return (
        f"Found device:\n"
        f"  Name: {device.device_name or 'Unnamed'}\n"
        f"  ID: {device.id}\n"
        f"  Serial: {device.serial_number}\n"
        f"  OS: {device.operating_system or 'Unknown'} {device.os_version or ''}\n"
        f"  Compliance: {device.compliance_state.value if device.compliance_state else 'unknown'}\n"
        f"  User: {device.user_display_name or 'N/A'}\n"
        f"  Last Sync: {device.last_sync_date_time or 'N/A'}"
    )

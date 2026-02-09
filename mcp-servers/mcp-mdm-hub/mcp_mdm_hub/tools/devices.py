"""Unified device query tools."""

from typing import Optional

from mcp_mdm_hub.server import aggregator, mcp


def _format_device(d) -> str:
    """Format a UnifiedDevice into a readable string."""
    compliance = d.compliance_status.value
    user_info = d.user.email or d.user.name if d.user else "Unassigned"
    last_seen = str(d.last_seen) if d.last_seen else "Never"

    return (
        f"  [{d.source.value.upper()}] {d.device_name or 'Unnamed'}\n"
        f"    Serial: {d.serial_number or 'N/A'} | Platform: {d.platform.value} | "
        f"OS: {d.os_version or 'N/A'}\n"
        f"    Compliance: {compliance} | User: {user_info} | Last Seen: {last_seen}"
    )


def _format_device_detail(d) -> str:
    """Format a UnifiedDevice with all nested details."""
    sections = [f"Device: {d.device_name or 'Unknown'} [{d.source.value.upper()}]"]
    sections.append(f"  Source ID: {d.source_id}")
    sections.append(f"  Serial: {d.serial_number or 'N/A'}")
    sections.append(f"  Platform: {d.platform.value} | OS: {d.os_version or 'N/A'}")
    sections.append(f"  Compliance: {d.compliance_status.value}")
    sections.append(f"  Ownership: {d.ownership.value}")
    sections.append(f"  Enrolled: {d.enrolled_at or 'N/A'}")
    sections.append(f"  Last Seen: {d.last_seen or 'N/A'}")

    if d.user:
        sections.append(f"\n  User:")
        sections.append(f"    Name: {d.user.name or 'N/A'}")
        sections.append(f"    Email: {d.user.email or 'N/A'}")
        if d.user.principal_name:
            sections.append(f"    UPN: {d.user.principal_name}")

    if d.hardware:
        h = d.hardware
        sections.append(f"\n  Hardware:")
        sections.append(f"    Model: {h.model or 'N/A'}")
        if h.manufacturer:
            sections.append(f"    Manufacturer: {h.manufacturer}")
        if h.processor:
            sections.append(f"    Processor: {h.processor}")
        if h.memory_bytes:
            sections.append(f"    Memory: {h.memory_bytes / (1024**3):.1f} GB")
        if h.total_storage_bytes:
            free = f", {h.free_storage_bytes / (1024**3):.1f} GB free" if h.free_storage_bytes else ""
            sections.append(f"    Storage: {h.total_storage_bytes / (1024**3):.1f} GB total{free}")

    if d.security:
        s = d.security
        sections.append(f"\n  Security:")
        if s.encryption_enabled is not None:
            sections.append(f"    Encryption: {'Enabled' if s.encryption_enabled else 'Disabled'}")
        if s.firewall_enabled is not None:
            sections.append(f"    Firewall: {'Enabled' if s.firewall_enabled else 'Disabled'}")
        if s.supervised is not None:
            sections.append(f"    Supervised: {s.supervised}")
        if s.jailbroken is not None:
            sections.append(f"    Jailbroken: {s.jailbroken}")

    if d.network:
        n = d.network
        sections.append(f"\n  Network:")
        if n.ip_address:
            sections.append(f"    IP: {n.ip_address}")
        if n.hostname:
            sections.append(f"    Hostname: {n.hostname}")

    return "\n".join(sections)


@mcp.tool()
async def mdm_list_all_devices(
    platform: Optional[str] = None,
    source: Optional[str] = None,
) -> str:
    """List devices from all connected MDMs in a unified view.

    Fetches concurrently from Kandji and Intune, normalizes into a unified
    schema, and returns a merged list.

    Args:
        platform: Filter by platform (macOS, Windows, iOS, iPadOS, Android, tvOS).
        source: Filter by MDM source (kandji, intune). Omit to query both.
    """
    devices = await aggregator.list_all_devices(
        platform_filter=platform, source_filter=source
    )
    if not devices:
        return "No devices found across connected MDMs."

    lines = [f"Found {len(devices)} device(s) across all MDMs:\n"]
    for d in devices:
        lines.append(_format_device(d))
    return "\n".join(lines)


@mcp.tool()
async def mdm_get_device_by_serial(serial_number: str) -> str:
    """Look up a device by serial number across all connected MDMs.

    Searches both Kandji and Intune concurrently. Returns all matches
    (a device could exist in both MDMs).

    Args:
        serial_number: The hardware serial number.
    """
    devices = await aggregator.get_device_by_serial(serial_number)
    if not devices:
        return f"No device found with serial '{serial_number}' in any connected MDM."

    lines = [f"Found {len(devices)} record(s) for serial '{serial_number}':\n"]
    for d in devices:
        lines.append(_format_device_detail(d))
    return "\n".join(lines)


@mcp.tool()
async def mdm_search_devices(query: str) -> str:
    """Search for devices by name, serial, user email, or model across all MDMs.

    Performs a case-insensitive substring match across key fields.

    Args:
        query: Search string to match against device name, serial, user email, or model.
    """
    all_devices = await aggregator.list_all_devices()
    query_lower = query.lower()

    matches = []
    for d in all_devices:
        searchable = " ".join(filter(None, [
            d.device_name,
            d.serial_number,
            d.user.email if d.user else None,
            d.user.name if d.user else None,
            d.hardware.model if d.hardware else None,
        ])).lower()

        if query_lower in searchable:
            matches.append(d)

    if not matches:
        return f"No devices matching '{query}' found across connected MDMs."

    lines = [f"Found {len(matches)} device(s) matching '{query}':\n"]
    for d in matches:
        lines.append(_format_device(d))
    return "\n".join(lines)

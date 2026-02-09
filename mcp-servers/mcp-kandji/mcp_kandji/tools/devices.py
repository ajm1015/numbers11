"""Kandji device management tools."""

from typing import Optional

from mcp_kandji.server import kandji_client, mcp


@mcp.tool()
async def kandji_list_devices(
    platform: Optional[str] = None,
    blueprint_id: Optional[str] = None,
) -> str:
    """List all devices in the Kandji tenant.

    Paginates internally to return all results. Optionally filter by platform
    (Mac, iPhone, iPad, AppleTV) or blueprint ID.

    Args:
        platform: Filter by device platform (Mac, iPhone, iPad, AppleTV).
        blueprint_id: Filter by blueprint UUID.
    """
    devices = await kandji_client.list_devices(
        platform=platform, blueprint_id=blueprint_id
    )
    if not devices:
        return "No devices found matching the given filters."

    lines = [f"Found {len(devices)} device(s):\n"]
    for d in devices:
        status = f"Last check-in: {d.last_check_in}" if d.last_check_in else "No check-in recorded"
        lines.append(
            f"- {d.device_name or 'Unnamed'} | {d.serial_number or 'N/A'} | "
            f"{d.platform or 'Unknown'} | {d.os_version or 'N/A'} | "
            f"{d.model or 'N/A'} | {status}"
        )
    return "\n".join(lines)


@mcp.tool()
async def kandji_get_device(device_id: str) -> str:
    """Get full details for a single Kandji device by its device ID.

    Returns hardware info, security posture, network details, and management status.

    Args:
        device_id: The Kandji device UUID.
    """
    summary = await kandji_client.get_device(device_id)
    details = await kandji_client.get_device_details(device_id)

    sections = [f"Device: {summary.get('device_name', 'Unknown')} ({device_id})"]

    if details.hardware_overview:
        hw = details.hardware_overview
        sections.append(
            f"\nHardware:\n"
            f"  Serial: {hw.get('serial_number', 'N/A')}\n"
            f"  Model: {hw.get('model_name', 'N/A')}\n"
            f"  Processor: {hw.get('processor_name', 'N/A')}\n"
            f"  Memory: {hw.get('memory', 'N/A')}"
        )

    if details.network:
        net = details.network
        sections.append(
            f"\nNetwork:\n"
            f"  IP: {net.get('ip_address', 'N/A')}\n"
            f"  Hostname: {net.get('local_hostname', 'N/A')}\n"
            f"  MAC: {net.get('mac_address', 'N/A')}"
        )

    if details.filevault:
        fv = details.filevault
        sections.append(
            f"\nFileVault:\n"
            f"  Enabled: {fv.get('filevault_enabled', 'N/A')}\n"
            f"  PRK Escrowed: {fv.get('filevault_prk_escrowed', 'N/A')}"
        )

    if details.security_information:
        sec = details.security_information
        sections.append(
            f"\nSecurity:\n"
            f"  Firewall: {sec.get('firewall_enabled', 'N/A')}\n"
            f"  SIP: {sec.get('sip_enabled', 'N/A')}\n"
            f"  Remote Desktop: {sec.get('remote_desktop_enabled', 'N/A')}"
        )

    if details.kandji_agent:
        agent = details.kandji_agent
        sections.append(
            f"\nKandji Agent:\n"
            f"  Installed: {agent.get('agent_installed', 'N/A')}\n"
            f"  Version: {agent.get('agent_version', 'N/A')}\n"
            f"  Last Check-in: {agent.get('last_check_in', 'N/A')}"
        )

    return "\n".join(sections)


@mcp.tool()
async def kandji_get_device_by_serial(serial_number: str) -> str:
    """Look up a Kandji device by its hardware serial number.

    Searches the full device list and returns details if found.

    Args:
        serial_number: The hardware serial number to search for.
    """
    device = await kandji_client.get_device_by_serial(serial_number)
    if device is None:
        return f"No device found with serial number '{serial_number}'."

    return (
        f"Found device:\n"
        f"  Name: {device.device_name or 'Unnamed'}\n"
        f"  Device ID: {device.device_id}\n"
        f"  Serial: {device.serial_number}\n"
        f"  Platform: {device.platform or 'Unknown'}\n"
        f"  Model: {device.model or 'N/A'}\n"
        f"  OS: {device.os_version or 'N/A'}\n"
        f"  Blueprint: {device.blueprint_name or 'N/A'}\n"
        f"  Last Check-in: {device.last_check_in or 'N/A'}"
    )


@mcp.tool()
async def kandji_get_device_apps(device_id: str) -> str:
    """List all apps installed on a specific Kandji device.

    Args:
        device_id: The Kandji device UUID.
    """
    apps = await kandji_client.get_device_apps(device_id)
    if not apps:
        return f"No apps found on device {device_id}."

    lines = [f"Found {len(apps)} app(s) on device {device_id}:\n"]
    for app in apps:
        lines.append(
            f"- {app.app_name or 'Unknown'} | "
            f"v{app.version or 'N/A'} | "
            f"{app.bundle_id or 'N/A'}"
        )
    return "\n".join(lines)

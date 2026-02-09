"""Intune device configuration tools."""

from mcp_intune.server import intune_client, mcp


@mcp.tool()
async def intune_list_device_configurations() -> str:
    """List all Intune device configuration profiles.

    Returns profile names, IDs, types, and last modified dates.
    """
    configs = await intune_client.list_device_configurations()
    if not configs:
        return "No device configuration profiles found."

    lines = [f"Found {len(configs)} configuration profile(s):\n"]
    for c in configs:
        modified = str(c.last_modified_date_time) if c.last_modified_date_time else "N/A"
        profile_type = c.odata_type.split(".")[-1] if c.odata_type else "Unknown"
        lines.append(
            f"- {c.display_name or 'Unnamed'} | Type: {profile_type} | "
            f"ID: {c.id} | Modified: {modified}"
        )
    return "\n".join(lines)

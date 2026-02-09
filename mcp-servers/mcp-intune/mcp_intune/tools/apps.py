"""Intune app management tools."""

from typing import Optional

from mcp_intune.server import intune_client, mcp


@mcp.tool()
async def intune_list_apps(app_type: Optional[str] = None) -> str:
    """List managed mobile apps in Intune.

    Args:
        app_type: Optional OData type filter (e.g., 'microsoft.graph.iosVppApp').
    """
    apps = await intune_client.list_apps(app_type=app_type)
    if not apps:
        return "No managed apps found."

    lines = [f"Found {len(apps)} app(s):\n"]
    for a in apps:
        app_kind = a.odata_type.split(".")[-1] if a.odata_type else "Unknown"
        assigned = "Assigned" if a.is_assigned else "Unassigned"
        lines.append(
            f"- {a.display_name or 'Unnamed'} | Type: {app_kind} | "
            f"Publisher: {a.publisher or 'N/A'} | {assigned}"
        )
    return "\n".join(lines)

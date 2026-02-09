"""Kandji app management tools."""

from mcp_kandji.server import kandji_client, mcp


@mcp.tool()
async def kandji_list_custom_apps() -> str:
    """List all custom apps in the Kandji library.

    Returns app names, installation types, and enforcement policies.
    """
    apps = await kandji_client.list_custom_apps()
    if not apps:
        return "No custom apps found in the library."

    lines = [f"Found {len(apps)} custom app(s):\n"]
    for app in apps:
        status = "Active" if app.active else "Inactive"
        self_service = "Yes" if app.show_in_self_service else "No"
        lines.append(
            f"- {app.name or 'Unnamed'} | {status} | "
            f"Install: {app.install_type or 'N/A'} | "
            f"Enforcement: {app.install_enforcement or 'N/A'} | "
            f"Self-Service: {self_service}"
        )
    return "\n".join(lines)

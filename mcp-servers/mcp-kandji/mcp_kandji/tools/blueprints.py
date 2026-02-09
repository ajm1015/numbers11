"""Kandji blueprint management tools."""

from mcp_kandji.server import kandji_client, mcp


@mcp.tool()
async def kandji_list_blueprints() -> str:
    """List all blueprints in the Kandji tenant.

    Returns blueprint names, IDs, and enrollment status.
    """
    blueprints = await kandji_client.list_blueprints()
    if not blueprints:
        return "No blueprints found."

    lines = [f"Found {len(blueprints)} blueprint(s):\n"]
    for bp in blueprints:
        enrollment = "Active" if bp.enrollment_code_is_active else "Inactive"
        lines.append(f"- {bp.name} | ID: {bp.id} | Enrollment: {enrollment}")
    return "\n".join(lines)


@mcp.tool()
async def kandji_get_blueprint(blueprint_id: str) -> str:
    """Get details of a specific Kandji blueprint.

    Args:
        blueprint_id: The blueprint UUID.
    """
    bp = await kandji_client.get_blueprint(blueprint_id)
    return (
        f"Blueprint: {bp.name}\n"
        f"  ID: {bp.id}\n"
        f"  Description: {bp.description or 'None'}\n"
        f"  Enrollment Active: {bp.enrollment_code_is_active}\n"
        f"  Enrollment Code: {bp.enrollment_code or 'N/A'}"
    )

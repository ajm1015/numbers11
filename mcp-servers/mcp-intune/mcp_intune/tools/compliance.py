"""Intune compliance policy tools."""

from mcp_intune.server import intune_client, mcp


@mcp.tool()
async def intune_list_compliance_policies() -> str:
    """List all Intune device compliance policies.

    Returns policy names, IDs, and last modified dates.
    """
    policies = await intune_client.list_compliance_policies()
    if not policies:
        return "No compliance policies found."

    lines = [f"Found {len(policies)} compliance policy(ies):\n"]
    for p in policies:
        modified = str(p.last_modified_date_time) if p.last_modified_date_time else "N/A"
        lines.append(
            f"- {p.display_name or 'Unnamed'} | ID: {p.id} | "
            f"Modified: {modified}"
        )
    return "\n".join(lines)

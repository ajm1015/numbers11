"""Intune server status resource."""

from mcp_intune.server import auth, cache, intune_client, mcp


@mcp.resource("intune://status")
async def get_status() -> str:
    """Intune MCP server health status.

    Returns Graph API connectivity, token status, and cache statistics.
    """
    connected = await intune_client.check_connectivity()
    token_valid = auth.is_token_valid

    return (
        f"Intune MCP Server Status\n"
        f"========================\n"
        f"Graph API Connected: {connected}\n"
        f"Token Valid: {token_valid}\n"
        f"Cache Entries: {cache.size}\n"
    )

"""Kandji server status resource."""

from mcp_kandji.server import cache, kandji_client, mcp


@mcp.resource("kandji://status")
async def get_status() -> str:
    """Kandji MCP server health status.

    Returns API connectivity, cache statistics, and server info.
    """
    connected = await kandji_client.check_connectivity()

    return (
        f"Kandji MCP Server Status\n"
        f"========================\n"
        f"API Connected: {connected}\n"
        f"Cache Entries: {cache.size}\n"
    )

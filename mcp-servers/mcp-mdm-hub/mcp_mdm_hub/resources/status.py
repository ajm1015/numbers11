"""Hub status resources."""

from mcp_mdm_hub.server import (
    hub_cache,
    intune_client,
    kandji_cache,
    kandji_client,
    intune_cache,
    mcp,
)


@mcp.resource("mdm://status")
async def get_hub_status() -> str:
    """Unified MDM hub health status.

    Returns connectivity status for both backends and cache statistics.
    """
    kandji_ok = await kandji_client.check_connectivity()
    intune_ok = await intune_client.check_connectivity()

    return (
        f"MDM Hub Status\n"
        f"==============\n"
        f"Kandji API: {'Connected' if kandji_ok else 'Disconnected'}\n"
        f"Intune API: {'Connected' if intune_ok else 'Disconnected'}\n"
        f"Kandji Cache: {kandji_cache.size} entries\n"
        f"Intune Cache: {intune_cache.size} entries\n"
        f"Hub Cache: {hub_cache.size} entries\n"
    )


@mcp.resource("mdm://sources")
async def get_sources() -> str:
    """List configured MDM backend sources and their connection status."""
    kandji_ok = await kandji_client.check_connectivity()
    intune_ok = await intune_client.check_connectivity()

    return (
        f"Configured MDM Sources\n"
        f"======================\n"
        f"1. Kandji — {'Online' if kandji_ok else 'Offline'}\n"
        f"2. Intune (Graph API) — {'Online' if intune_ok else 'Offline'}\n"
    )

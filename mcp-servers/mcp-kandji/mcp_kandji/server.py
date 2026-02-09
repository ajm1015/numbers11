"""Kandji MCP server definition and tool registration."""

from mcp.server.fastmcp import FastMCP

from mdm_shared.cache import TTLCache
from mdm_shared.clients.kandji import KandjiClient

from mcp_kandji.config import KandjiSettings

# Load settings from environment
settings = KandjiSettings()  # type: ignore[call-arg]

# Initialize shared cache and API client
cache = TTLCache(default_ttl=settings.kandji_cache_ttl)
kandji_client = KandjiClient(
    subdomain=settings.kandji_subdomain,
    api_token=settings.kandji_api_token,
    region=settings.kandji_region,
    page_size=settings.kandji_page_size,
    max_retries=settings.kandji_max_retries,
    cache=cache,
)

# Create the MCP server
mcp = FastMCP(
    "mcp-kandji",
    description=(
        "Kandji MDM management server. "
        "Query devices, blueprints, apps, and execute device actions "
        "against a Kandji tenant."
    ),
)

# Register tools and resources via imports
from mcp_kandji.tools import devices, blueprints, apps, actions  # noqa: F401, E402
from mcp_kandji.resources import status  # noqa: F401, E402

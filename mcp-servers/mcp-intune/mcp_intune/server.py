"""Intune MCP server definition and tool registration."""

from mcp.server.fastmcp import FastMCP

from mdm_shared.auth.azure import AzureADAuth
from mdm_shared.cache import TTLCache
from mdm_shared.clients.intune import IntuneClient

from mcp_intune.config import IntuneSettings

# Load settings from environment
settings = IntuneSettings()  # type: ignore[call-arg]

# Initialize auth, cache, and API client
auth = AzureADAuth(
    tenant_id=settings.azure_tenant_id,
    client_id=settings.azure_client_id,
    client_secret=settings.azure_client_secret,
)
cache = TTLCache(default_ttl=settings.intune_cache_ttl)
intune_client = IntuneClient(
    auth=auth,
    api_version=settings.graph_api_version,
    page_size=settings.intune_page_size,
    max_retries=settings.intune_max_retries,
    cache=cache,
)

# Create the MCP server
mcp = FastMCP(
    "mcp-intune",
    description=(
        "Microsoft Intune MDM management server. "
        "Query managed devices, compliance policies, configuration profiles, "
        "apps, and execute remote device actions via the Graph API."
    ),
)

# Register tools and resources via imports
from mcp_intune.tools import devices, compliance, configurations, apps, actions  # noqa: F401, E402
from mcp_intune.resources import status  # noqa: F401, E402

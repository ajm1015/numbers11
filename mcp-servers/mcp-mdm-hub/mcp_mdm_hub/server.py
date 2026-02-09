"""Unified MDM hub server definition."""

from mcp.server.fastmcp import FastMCP

from mdm_shared.auth.azure import AzureADAuth
from mdm_shared.cache import TTLCache
from mdm_shared.clients.intune import IntuneClient
from mdm_shared.clients.kandji import KandjiClient

from mcp_mdm_hub.aggregator import Aggregator
from mcp_mdm_hub.config import HubSettings

# Load settings from environment
settings = HubSettings()  # type: ignore[call-arg]

# Initialize shared caches
kandji_cache = TTLCache(default_ttl=settings.kandji_cache_ttl)
intune_cache = TTLCache(default_ttl=settings.intune_cache_ttl)
hub_cache = TTLCache(default_ttl=settings.hub_cache_ttl)

# Initialize API clients
kandji_client = KandjiClient(
    subdomain=settings.kandji_subdomain,
    api_token=settings.kandji_api_token,
    region=settings.kandji_region,
    cache=kandji_cache,
)

intune_auth = AzureADAuth(
    tenant_id=settings.azure_tenant_id,
    client_id=settings.azure_client_id,
    client_secret=settings.azure_client_secret,
)
intune_client = IntuneClient(auth=intune_auth, cache=intune_cache)

# Initialize aggregator
aggregator = Aggregator(kandji_client=kandji_client, intune_client=intune_client)

# Create the MCP server
mcp = FastMCP(
    "mcp-mdm-hub",
    description=(
        "Unified MDM hub. Query devices across Kandji and Intune "
        "with a normalized schema. Search, compare, and manage your "
        "entire fleet from a single context surface."
    ),
)

# Register tools, resources, and prompts
from mcp_mdm_hub.tools import devices, fleet, actions  # noqa: F401, E402
from mcp_mdm_hub.resources import status  # noqa: F401, E402
from mcp_mdm_hub.prompts import device_audit, compliance_review  # noqa: F401, E402

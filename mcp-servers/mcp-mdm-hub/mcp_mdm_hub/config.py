"""Configuration for the MDM hub server."""

from pydantic_settings import BaseSettings


class HubSettings(BaseSettings):
    """Environment-based settings for the unified MDM hub."""

    # Kandji backend
    kandji_subdomain: str
    kandji_api_token: str
    kandji_region: str = "us"
    kandji_cache_ttl: int = 300

    # Intune backend
    azure_tenant_id: str
    azure_client_id: str
    azure_client_secret: str
    intune_cache_ttl: int = 300

    # Hub settings
    hub_cache_ttl: int = 120
    transport: str = "stdio"
    server_host: str = "127.0.0.1"
    server_port: int = 8003

    model_config = {"env_prefix": "", "env_file": ".env", "extra": "ignore"}

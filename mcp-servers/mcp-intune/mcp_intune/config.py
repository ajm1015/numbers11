"""Configuration for the Intune MCP server."""

from pydantic_settings import BaseSettings


class IntuneSettings(BaseSettings):
    """Environment-based settings for the Intune MCP server."""

    azure_tenant_id: str
    azure_client_id: str
    azure_client_secret: str
    intune_cache_ttl: int = 300
    intune_page_size: int = 100
    intune_max_retries: int = 3
    graph_api_version: str = "v1.0"
    transport: str = "stdio"
    server_host: str = "127.0.0.1"
    server_port: int = 8002

    model_config = {"env_prefix": "", "env_file": ".env", "extra": "ignore"}

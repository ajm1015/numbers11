"""Configuration for the Kandji MCP server."""

from pydantic_settings import BaseSettings


class KandjiSettings(BaseSettings):
    """Environment-based settings for the Kandji MCP server."""

    kandji_subdomain: str
    kandji_api_token: str
    kandji_region: str = "us"
    kandji_cache_ttl: int = 300
    kandji_page_size: int = 300
    kandji_max_retries: int = 3
    transport: str = "stdio"
    server_host: str = "127.0.0.1"
    server_port: int = 8001

    model_config = {"env_prefix": "", "env_file": ".env", "extra": "ignore"}

"""Entry point for the MDM hub server."""

import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()],
)

from mcp_mdm_hub.server import mcp, settings  # noqa: E402

if __name__ == "__main__":
    if settings.transport == "http":
        mcp.run(transport="streamable-http", host=settings.server_host, port=settings.server_port)
    else:
        mcp.run(transport="stdio")

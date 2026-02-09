# mcp-kandji

MCP server for Kandji MDM management. Query devices, blueprints, apps, and execute remote device actions against a Kandji tenant.

## Tools (14)

### Devices
| Tool | Parameters | Description |
|------|-----------|-------------|
| `kandji_list_devices` | `platform?`, `blueprint_id?` | List all devices, with optional platform or blueprint filter |
| `kandji_get_device` | `device_id` | Full device details by Kandji device ID |
| `kandji_get_device_by_serial` | `serial_number` | Look up a device by hardware serial number |
| `kandji_get_device_apps` | `device_id` | List all apps installed on a specific device |

### Blueprints
| Tool | Parameters | Description |
|------|-----------|-------------|
| `kandji_list_blueprints` | — | List all blueprints in the tenant |
| `kandji_get_blueprint` | `blueprint_id` | Get details of a specific blueprint |

### Apps
| Tool | Parameters | Description |
|------|-----------|-------------|
| `kandji_list_custom_apps` | — | List all custom apps in the Kandji library |

### Actions
| Tool | Parameters | Description |
|------|-----------|-------------|
| `kandji_send_blankpush` | `device_id` | Trigger an MDM check-in (non-destructive) |
| `kandji_update_inventory` | `device_id` | Trigger an inventory update (non-destructive) |
| `kandji_renew_mdm_profile` | `device_id` | Reinstall the root MDM profile |
| `kandji_lock_device` | `device_id`, `pin` (6-digit) | Lock a device with a PIN code |
| `kandji_restart_device` | `device_id` | Restart a device remotely |
| `kandji_shutdown_device` | `device_id` | Shut down a device remotely |
| `kandji_erase_device` | `device_id`, `pin` | **DESTRUCTIVE** — Factory reset, cannot be undone |

### Resources
| URI | Description |
|-----|-------------|
| `kandji://status` | Server status and connectivity check |

## Prerequisites

- Kandji admin access with an API token
- Generate a token in Kandji: **Settings > Access > API Token**
- Token needs read access for queries, write access for device actions

## Configuration

Copy `.env.example` to `.env` and fill in your values:

```bash
KANDJI_SUBDOMAIN=your-tenant        # Your Kandji subdomain
KANDJI_API_TOKEN=your-api-token     # Bearer token from Kandji admin
KANDJI_REGION=us                    # us or eu
KANDJI_CACHE_TTL=300                # Cache TTL in seconds
TRANSPORT=stdio                     # stdio or http
SERVER_HOST=127.0.0.1               # Bind address (http mode)
SERVER_PORT=8001                    # Port (http mode)
```

## Running

### Local (stdio)
```bash
cd mcp-servers/mcp-kandji
uv run python -m mcp_kandji
```

### Local (HTTP)
```bash
TRANSPORT=http uv run python -m mcp_kandji
```

### Docker
```bash
cd mcp-servers
docker compose -f docker-compose.mcp.yml up mcp-kandji
```

## Development

```bash
cd mcp-servers/mcp-kandji
uv sync --dev
uv run pytest tests/ -v --cov
uv run ruff check .
uv run mypy mcp_kandji/
```

## Architecture

```
mcp-kandji/
├── mcp_kandji/
│   ├── __main__.py         # Entry point (stdio/http transport)
│   ├── server.py           # FastMCP instance + registration
│   ├── config.py           # KandjiSettings (pydantic-settings)
│   ├── tools/
│   │   ├── devices.py      # Device query tools
│   │   ├── blueprints.py   # Blueprint tools
│   │   ├── apps.py         # Custom apps tool
│   │   └── actions.py      # Remote device actions
│   └── resources/
│       └── status.py       # Server status resource
├── tests/
├── Dockerfile
└── pyproject.toml
```

Depends on `_shared/` (mdm-shared) for the Kandji API client, TTL cache, and Pydantic models.

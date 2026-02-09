# mcp-intune

MCP server for Microsoft Intune MDM management. Query managed devices, compliance policies, configuration profiles, apps, and execute remote device actions via the Microsoft Graph API.

## Tools (12)

### Devices
| Tool | Parameters | Description |
|------|-----------|-------------|
| `intune_list_devices` | `os_filter?`, `compliance_filter?` | List managed devices with optional OS or compliance filters |
| `intune_get_device` | `device_id` | Full device details by Intune device ID |
| `intune_get_device_by_serial` | `serial_number` | Look up a managed device by serial number |

### Compliance & Configuration
| Tool | Parameters | Description |
|------|-----------|-------------|
| `intune_list_compliance_policies` | — | List all device compliance policies |
| `intune_list_device_configurations` | — | List all device configuration profiles |

### Apps
| Tool | Parameters | Description |
|------|-----------|-------------|
| `intune_list_apps` | `app_type?` | List managed mobile apps, optionally filtered by type |

### Actions
| Tool | Parameters | Description |
|------|-----------|-------------|
| `intune_sync_device` | `device_id` | Trigger an Intune sync (non-destructive) |
| `intune_reboot_device` | `device_id` | Reboot a device remotely |
| `intune_lock_device` | `device_id` | Remotely lock a device |
| `intune_shutdown_device` | `device_id` | Shut down a device remotely |
| `intune_retire_device` | `device_id` | **DESTRUCTIVE** — Remove company data + MDM management |
| `intune_wipe_device` | `device_id`, `keep_user_data?` | **DESTRUCTIVE** — Factory reset |

### Resources
| URI | Description |
|-----|-------------|
| `intune://status` | Server status and Graph API connectivity check |

## Prerequisites

- Azure AD app registration with the following Microsoft Graph API **application** permissions:
  - `DeviceManagementManagedDevices.Read.All` (device queries)
  - `DeviceManagementManagedDevices.ReadWrite.All` (device actions)
  - `DeviceManagementConfiguration.Read.All` (compliance policies, config profiles)
  - `DeviceManagementApps.Read.All` (managed apps)
- Admin consent granted for the above permissions

## Configuration

Copy `.env.example` to `.env` and fill in your values:

```bash
AZURE_TENANT_ID=your-tenant-id       # Azure AD tenant ID
AZURE_CLIENT_ID=your-client-id       # App registration client ID
AZURE_CLIENT_SECRET=your-secret      # App registration client secret
INTUNE_CACHE_TTL=300                  # Cache TTL in seconds
GRAPH_API_VERSION=v1.0                # Graph API version (v1.0 or beta)
TRANSPORT=stdio                       # stdio or http
SERVER_HOST=127.0.0.1                 # Bind address (http mode)
SERVER_PORT=8002                      # Port (http mode)
```

## Running

### Local (stdio)
```bash
cd mcp-servers/mcp-intune
uv run python -m mcp_intune
```

### Local (HTTP)
```bash
TRANSPORT=http uv run python -m mcp_intune
```

### Docker
```bash
cd mcp-servers
docker compose -f docker-compose.mcp.yml up mcp-intune
```

## Development

```bash
cd mcp-servers/mcp-intune
uv sync --dev
uv run pytest tests/ -v --cov
uv run ruff check .
uv run mypy mcp_intune/
```

## Architecture

```
mcp-intune/
├── mcp_intune/
│   ├── __main__.py            # Entry point (stdio/http transport)
│   ├── server.py              # FastMCP instance + registration
│   ├── config.py              # IntuneSettings (pydantic-settings)
│   ├── tools/
│   │   ├── devices.py         # Device query tools
│   │   ├── compliance.py      # Compliance policy tools
│   │   ├── configurations.py  # Configuration profile tools
│   │   ├── apps.py            # Managed apps tool
│   │   └── actions.py         # Remote device actions
│   └── resources/
│       └── status.py          # Server status resource
├── tests/
├── Dockerfile
└── pyproject.toml
```

Depends on `_shared/` (mdm-shared) for the Intune Graph API client, Azure AD OAuth2 auth, TTL cache, and Pydantic models.

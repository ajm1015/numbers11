# mcp-mdm-hub

Unified MDM hub MCP server. Queries devices across Kandji and Microsoft Intune, normalizes them into a unified schema, and provides a single context surface for fleet management.

This is the **design center** of the MDM MCP architecture — it aggregates, normalizes, and routes actions across all connected MDM platforms.

## Tools (10)

### Devices
| Tool | Parameters | Description |
|------|-----------|-------------|
| `mdm_list_all_devices` | `platform?`, `source?` | List devices from all MDMs in a unified view |
| `mdm_get_device_by_serial` | `serial_number` | Look up a device by serial across all MDMs |
| `mdm_search_devices` | `query` | Free-text search by name, serial, user, or model |

### Fleet Analytics
| Tool | Parameters | Description |
|------|-----------|-------------|
| `mdm_fleet_summary` | — | Aggregate counts by platform, source, compliance, ownership |
| `mdm_compare_platforms` | — | Cross-MDM comparison and fleet-wide stats |

### Actions (routed to correct MDM)
| Tool | Parameters | Description |
|------|-----------|-------------|
| `mdm_sync_device` | `source`, `source_id` | Trigger MDM sync (blankpush for Kandji, syncDevice for Intune) |
| `mdm_lock_device` | `source`, `source_id`, `pin?` | Lock a device via the correct MDM |
| `mdm_restart_device` | `source`, `source_id` | Restart a device via the correct MDM |
| `mdm_erase_device` | `source`, `source_id`, `pin?` | **DESTRUCTIVE** — Factory reset via the correct MDM |

## Prompts (2)

| Prompt | Parameters | Description |
|--------|-----------|-------------|
| `device_audit` | `serial_number` | Step-by-step audit: lookup, compliance, encryption, user, summary |
| `compliance_review` | `platform?` | Fleet review: summary, non-compliant list, prioritize, report |

### Resources
| URI | Description |
|-----|-------------|
| `mdm://status` | Hub status and backend connectivity |
| `mdm://sources` | Connected MDM sources and their capabilities |

## Unified Device Schema

The hub normalizes Kandji and Intune devices into a single `UnifiedDevice` model:

```
UnifiedDevice
├── source          (kandji | intune)
├── source_id       (original MDM device ID)
├── device_name
├── serial_number
├── platform        (macOS | iOS | iPadOS | Windows | Android | tvOS | unknown)
├── os_version
├── compliance      (compliant | noncompliant | unknown | not_applicable)
├── ownership       (corporate | personal | unknown)
├── enrolled_at
├── last_seen
├── user            (name, email, principal_name)
├── hardware        (model, manufacturer, memory, storage, processor)
├── network         (ip, hostname, wifi_mac, ethernet_mac)
├── security        (encryption, firewall, supervised, jailbroken, activation_lock)
└── source_metadata (raw fields not in the unified schema)
```

## Prerequisites

Requires credentials for **both** Kandji and Intune:
- Kandji API token (see mcp-kandji README)
- Azure AD app registration with Graph API permissions (see mcp-intune README)

## Configuration

Copy `.env.example` to `.env` and fill in your values:

```bash
# Kandji Backend
KANDJI_SUBDOMAIN=your-tenant
KANDJI_API_TOKEN=your-api-token
KANDJI_REGION=us
KANDJI_CACHE_TTL=300

# Intune Backend (Azure AD)
AZURE_TENANT_ID=your-tenant-id
AZURE_CLIENT_ID=your-client-id
AZURE_CLIENT_SECRET=your-secret
INTUNE_CACHE_TTL=300

# Hub Settings
HUB_CACHE_TTL=120
TRANSPORT=stdio
SERVER_HOST=127.0.0.1
SERVER_PORT=8003
```

## Running

### Local (stdio)
```bash
cd mcp-servers/mcp-mdm-hub
uv run python -m mcp_mdm_hub
```

### Local (HTTP)
```bash
TRANSPORT=http uv run python -m mcp_mdm_hub
```

### Docker (all 3 servers)
```bash
cd mcp-servers
docker compose -f docker-compose.mcp.yml up
```

## Development

```bash
cd mcp-servers/mcp-mdm-hub
uv sync --dev
uv run pytest tests/ -v --cov
uv run ruff check .
uv run mypy mcp_mdm_hub/
```

## Architecture

```
mcp-mdm-hub/
├── mcp_mdm_hub/
│   ├── __main__.py          # Entry point (stdio/http transport)
│   ├── server.py            # FastMCP instance, initializes both API clients
│   ├── config.py            # HubSettings (all Kandji + Intune + hub vars)
│   ├── normalizer.py        # Kandji + Intune → UnifiedDevice mapping
│   ├── aggregator.py        # Concurrent fetch, merge, fleet stats
│   ├── models/
│   │   └── unified.py       # UnifiedDevice schema (the design center)
│   ├── tools/
│   │   ├── devices.py       # Unified device queries
│   │   ├── fleet.py         # Fleet analytics tools
│   │   └── actions.py       # Action routing to correct MDM
│   ├── prompts/
│   │   ├── device_audit.py  # Device audit workflow template
│   │   └── compliance_review.py  # Fleet compliance review template
│   └── resources/
│       └── status.py        # Hub status + sources resources
├── tests/
│   └── test_normalizer.py   # 23 tests for field mapping correctness
├── Dockerfile
└── pyproject.toml
```

The hub does **not** call through other MCP servers (they're isolated by spec). It uses the same shared clients from `_shared/` to query APIs directly.

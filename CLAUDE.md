# CLAUDE.md — Project Intelligence

> This file is automatically loaded into context for every Claude Code session in this repo.
> It defines standards, conventions, and expectations for all work performed here.

## Repository Identity

This is Jack's **multi-project monorepo** for macOS development, MCP development, dashboard tooling, deployment automation, and dev environment configuration. All projects share a commitment to production-ready, secure, performant, and scalable code.

## Core Principles

1. **Code Efficiency** — Minimal code to achieve the goal. No premature abstractions, no dead code, no "just in case" patterns.
2. **Production-Ready** — Every output should be deployable. No TODOs left behind, no placeholder logic, no hardcoded secrets.
3. **Security-First** — Validate at boundaries, sanitize inputs, never trust external data. Follow OWASP top 10 awareness. No secrets in code.
4. **Performance** — Choose the right algorithm, avoid unnecessary allocations, minimize network calls, lazy-load where appropriate.
5. **Scalability** — Design for growth without over-engineering. Stateless where possible, clean interfaces, composable components.

## Interaction Protocol

### Always Ask Clarifying Questions

Before building anything non-trivial:
- **Planning phase**: Ask 3-5 clarifying questions about requirements, constraints, and preferences before proposing architecture.
- **Building phase**: Ask about edge cases, error handling expectations, and integration points before writing code.
- **Use `EnterPlanMode`** for any feature that touches 3+ files or introduces new patterns.

### Self-Audit Expectations

When asked to audit, systematically check:
- Security vulnerabilities (injection, XSS, auth issues, exposed secrets)
- Performance bottlenecks (N+1 queries, unnecessary re-renders, blocking calls)
- Error handling completeness (missing catch blocks, unhandled promise rejections)
- Code duplication and dead code
- Dependency health (outdated, deprecated, vulnerable packages)
- Test coverage gaps

## Project Map

| Directory | Stack | Purpose |
|-----------|-------|---------|
| `dashboard/frontend` | React 18, Vite 5, Tailwind CSS, React Query | Status dashboard UI |
| `dashboard/backend` | Python FastAPI, Uvicorn, Pydantic, httpx | Status checking API |
| `bash-dev-env` | Bash, Bats, ShellCheck, shfmt | Bash scripting framework |
| `zen-dev-setup` | Zsh, Python, Ghostty, Cursor, Starship | macOS dev environment |
| `WIN11 INSTALL SCRIPT` | PowerShell 5.1+ | Windows 11 deployment automation |
| `Deployments` | PowerShell, Intune | Win32 app deployment packages |
| `Templates` | PowerShell | Intune script templates |
| `Scripts` | Shell | Standalone utilities |
| `MACOS SCRIPTS` | Shell | macOS automation (early stage) |
| `mcp-servers/*` | TypeScript + Python, MCP SDK, Docker | Context-everywhere MCP tool servers |

## Language & Framework Standards

### JavaScript / React
- React 18 with functional components and hooks only
- React Query for server state, local state kept minimal
- Tailwind CSS utility-first — no custom CSS unless absolutely necessary
- Vite for bundling — keep config minimal
- ESLint enforced, no warnings tolerated
- Import order: React → third-party → local components → local utils → styles

### Python
- FastAPI with Pydantic v2 models for all request/response types
- Type hints on all function signatures
- `async` endpoints by default — sync only when calling blocking libs
- httpx for HTTP calls (async-compatible)
- Use `python-dotenv` for env config, never hardcode connection strings

### Bash / Shell
- `set -euo pipefail` in every script
- 2-space indentation (enforced by .editorconfig)
- ShellCheck clean — no suppressed warnings without documented reason
- Use `lib/common.sh` logging functions: `log_info`, `log_warn`, `log_err`
- Bats tests for any non-trivial logic
- shfmt for formatting

### PowerShell
- PowerShell 5.1+ compatibility
- `try/catch` with structured error handling
- Consistent logging pattern matching existing templates
- Exit codes: 0 (success), 1 (failure), 3010 (reboot required)
- SYSTEM execution context awareness for Intune scripts

## MCP Server Development — "Context Everywhere"

### Philosophy

Every MCP server is a **context surface** — a focused microservice that makes one domain of ambient knowledge available to any LLM-powered tool. The goal: dev state, personal knowledge, and system health are always queryable, always composable, never siloed.

### Architecture

```
Host (Claude Code / Claude Desktop / Custom Agent)
├── Client 1 ─── MCP Server A (Dev Context)      [TypeScript]
├── Client 2 ─── MCP Server B (Knowledge Base)    [Python]
├── Client 3 ─── MCP Server C (System Monitor)    [TypeScript]
└── Client N ─── ...
```

- **Servers are isolated** — no server can see another server's context or conversation history. The host orchestrates.
- **One server, one domain** — each server owns a single bounded context (files, git, docker, notes, etc.).
- **Shared state via backing services** — if servers need coordination, use a shared DB or message queue behind the scenes, never MCP-level coupling.

### Dual Runtime Strategy

| Runtime | Use When | Package Manager |
|---------|----------|-----------------|
| **TypeScript** | Lightweight tools, filesystem ops, CLI wrappers, fast I/O | npm with lockfile |
| **Python** | AI/ML pipelines, heavy compute, data processing, existing FastAPI patterns | uv (preferred) or pip |

### Project Structure Convention

Every MCP server lives in its own directory under a `mcp-servers/` top-level folder:

```
mcp-servers/
├── server-name/
│   ├── src/
│   │   ├── index.ts          # Entry point + transport setup
│   │   ├── tools/            # Tool definitions (one file per tool or logical group)
│   │   ├── resources/        # Resource definitions
│   │   └── prompts/          # Prompt templates
│   ├── tests/
│   ├── Dockerfile
│   ├── package.json          # or pyproject.toml
│   └── README.md
```

Python variant:
```
mcp-servers/
├── server-name/
│   ├── server_name/
│   │   ├── __init__.py
│   │   ├── __main__.py       # Entry point
│   │   ├── server.py         # MCPServer instance + registration
│   │   ├── tools/
│   │   ├── resources/
│   │   └── prompts/
│   ├── tests/
│   ├── Dockerfile
│   ├── pyproject.toml
│   └── README.md
```

### SDK Versions & Pinning

- **TypeScript**: `@modelcontextprotocol/sdk@^1.26` (pin major, track minor)
- **Python**: `mcp>=1.25,<2` (pin to v1.x until v2 stabilizes)
- **Zod** (TS): `zod@^3.25` (required peer dependency for schema validation)
- **Pydantic** (Python): `pydantic>=2.5` (for structured tool outputs)

### When to Use Resources vs. Tools vs. Prompts

| Primitive | Control | Side Effects | Use When |
|-----------|---------|-------------|----------|
| **Resource** | Host decides | None (read-only) | Exposing data/context — file contents, configs, schemas |
| **Tool** | LLM decides | Yes (actions) | Taking actions — API calls, writes, queries, computations |
| **Prompt** | User decides | None | Reusable templates — code review, debugging workflows |

Decision rule: If it reads, it's a **resource**. If it acts, it's a **tool**. If it templates user intent, it's a **prompt**.

### Naming Conventions

- **Tool names**: `snake_case`, max 128 chars, unique per server. Dot-namespace for grouping: `git.status`, `git.diff`, `docker.ps`.
- **Resource URIs**: RFC 3986 compliant. Use meaningful schemes: `file://`, `git://`, `config://`, `note://`, `docker://`. Use URI templates for parameterized access: `file://projects/{name}/readme`.
- **Prompt names**: `snake_case`, descriptive of the workflow: `code_review`, `debug_crash`, `summarize_changes`.
- **Server names**: `kebab-case`, prefixed by domain: `dev-context`, `knowledge-base`, `system-monitor`.

### Transport

- **Streamable HTTP** for all Docker-deployed servers (single endpoint, supports POST/GET/DELETE)
- **stdio** only for local dev/testing or servers spawned as subprocesses
- Never use deprecated HTTP+SSE transport
- Bind to `127.0.0.1` when running locally — never `0.0.0.0` outside containers

### Input Validation & Error Handling

- **All tool inputs validated** via Zod schemas (TS) or Pydantic models (Python) — no raw parameter access
- **Tool execution errors** return `isError: true` with actionable messages: what happened, why, and what valid input looks like
- **Protocol errors** use standard JSON-RPC codes (`-32700` parse, `-32600` invalid request, `-32601` method not found, `-32602` invalid params)
- Never swallow errors — every failure path returns a meaningful message the LLM can act on

### Security Requirements (MCP-Specific)

- Validate `Origin` header on all incoming HTTP connections (DNS rebinding protection)
- Rate-limit tool invocations — no unbounded loops
- Sanitize all tool outputs before returning to client
- Validate and sanitize all resource URIs (prevent path traversal)
- Only JSON-RPC on stdout; all logs to stderr (stdio transport)
- Secrets via environment variables only — never in tool schemas, resource URIs, or prompt templates
- Run containers as non-root (`USER mcp` in Dockerfile)

### Docker Deployment (All MCP Servers)

Every MCP server ships with:
1. **Multi-stage Dockerfile** — build stage + minimal production image (Alpine-based)
2. **Health check endpoint** — required for Docker orchestration
3. **Non-root user** — `mcp` user/group in all containers
4. **Resource limits** — CPU and memory caps in docker-compose
5. **Signal handling** — `dumb-init` (Node.js) or proper SIGTERM handling

Docker Compose orchestrates all MCP servers alongside the dashboard:
```yaml
# mcp-servers are added to the shared mcp-network
# Each server gets its own service definition
# Environment variables from .env file, never hardcoded
```

### Testing MCP Servers

- **Unit tests**: Test tool logic in isolation (no transport). Mock external dependencies.
- **Integration tests**: Spin up the server with stdio transport, send JSON-RPC messages, assert responses.
- **Schema tests**: Verify all tools have valid input schemas and error responses match expected format.
- **Container tests**: Build image, run health check, verify startup.

### Context Domain Map

| Domain | Server | Status | Context Surfaces |
|--------|--------|--------|-----------------|
| MDM — Kandji | `mcp-kandji` | **Built** | Devices, blueprints, apps, device actions (Apple fleet) |
| MDM — Intune | `mcp-intune` | **Built** | Managed devices, compliance, configs, apps, remote actions (Windows/cross-platform) |
| MDM — Unified | `mcp-mdm-hub` | **Built** | Normalized cross-MDM device view, fleet analytics, routed actions |
| Dev state | `dev-context` | Planned | Git status, branches, recent commits, open TODOs, file tree, project metadata |
| Knowledge | `knowledge-base` | Planned | Notes, bookmarks, snippets, docs — searchable and injectable |
| System | `system-monitor` | Planned | Docker containers, processes, network, disk, hardware metrics |
| Clipboard | `clipboard-history` | Planned | Recent clipboard entries with type detection |
| Calendar/Tasks | `personal-planner` | Planned | Schedule, reminders, task lists |

_This map evolves as servers are built. Update it when adding new servers._

## Docker & Deployment
- Docker Compose for local multi-service development
- Separate Dockerfiles per service, multi-stage builds preferred
- Nginx for frontend static serving in production containers
- Environment variables for all runtime config — no baked-in values

## Git Conventions
- Branch from `main` for all work
- Commit messages: imperative mood, concise subject, body for "why" not "what"
- No force pushes to `main`
- Keep commits atomic — one logical change per commit

## Security Checklist (apply to every PR)
- [ ] No secrets, tokens, or API keys in code or config
- [ ] Input validation at all API boundaries
- [ ] CORS configured restrictively (not wildcard in production)
- [ ] Dependencies checked for known vulnerabilities
- [ ] No `eval()`, `exec()`, or dynamic code execution from user input
- [ ] SQL/NoSQL injection prevention via parameterized queries
- [ ] File paths validated and sanitized (no path traversal)

## Memory & Continuous Improvement

Claude maintains learned patterns in `~/.claude/projects/-Users-jack-morton-GitHub-1/memory/`:
- `MEMORY.md` — Key learnings loaded every session
- Topic-specific files for detailed patterns and past decisions

After every significant session, update memory with:
- What worked well and should be repeated
- Mistakes made and how to avoid them
- Architecture decisions and their rationale
- User preferences discovered during the session

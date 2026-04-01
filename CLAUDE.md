# CLAUDE.md — Repo Root

> Loaded into every Claude Code session. Per-project CLAUDE.md files inherit from this and add local context.

## Repository Identity

Jack's **multi-project monorepo** — macOS dev tooling, MCP servers, dashboard, Intune deployments, shell frameworks. All projects share these root standards; project-specific conventions live in their own CLAUDE.md.

## Core Principles

1. **Code Efficiency** — Minimal code to achieve the goal. No premature abstractions, no dead code, no "just in case."
2. **Production-Ready** — Every output deployable. No TODOs left behind, no placeholder logic, no hardcoded secrets.
3. **Security-First** — Validate at boundaries, sanitize inputs, never trust external data. No secrets in code.
4. **Performance** — Right algorithm, minimal allocations, minimal network calls, lazy-load where appropriate.
5. **Scalability** — Design for growth without over-engineering. Stateless where possible, clean interfaces, composable.

## Interaction Protocol

### Planning

- **3+ files or new patterns** → `EnterPlanMode` first. Ask 3–5 clarifying questions about requirements, constraints, preferences before proposing architecture.
- **Building phase** → Ask about edge cases, error handling expectations, and integration points before writing code.

### Self-Audit Checklist

When asked to audit, systematically check: security vulnerabilities, performance bottlenecks, error handling completeness, code duplication/dead code, dependency health, test coverage gaps.

## Project Map

| Directory | Stack | Purpose |
|-----------|-------|---------|
| `dashboard/` | React 18 + Vite / FastAPI | Status dashboard |
| `bash-dev-env/` | Bash, Bats, ShellCheck | Bash scripting framework |
| `zen-dev-setup/` | Zsh, Python, Ghostty, Starship | macOS dev environment |
| `WIN11 INSTALL SCRIPT/` | PowerShell 5.1+ | Windows 11 deployment automation |
| `Deployments/` | PowerShell, Intune | Win32 app deployment packages |
| `Templates/` | PowerShell | Intune script templates |
| `Scripts/` | Shell | Standalone utilities |
| `MACOS SCRIPTS/` | Shell | macOS automation |
| `mcp-servers/` | TypeScript + Python, MCP SDK, Docker | Context-everywhere MCP tool servers |

## Git Conventions

- Branch from `main` for all work
- Commit messages: imperative mood, concise subject, body for "why" not "what"
- No force pushes to `main`
- Atomic commits — one logical change per commit

## Security Checklist (every PR)

- [ ] No secrets, tokens, or API keys in code or config
- [ ] Input validation at all API boundaries
- [ ] CORS configured restrictively (no wildcard in prod)
- [ ] Dependencies checked for known vulnerabilities
- [ ] No `eval()`, `exec()`, or dynamic code execution from user input
- [ ] Parameterized queries (no SQL/NoSQL injection)
- [ ] File paths validated and sanitized (no path traversal)

## Shared Code Standards

### All Languages

- Error handling on every external call. No bare catches. No swallowed exceptions.
- If a name needs a comment, rename it.
- Flat over nested. Early returns over else chains.

### Shell (Bash/Zsh)

- `set -euo pipefail` in every script
- 2-space indent (enforced by .editorconfig)
- ShellCheck clean — no suppressed warnings without documented reason
- shfmt for formatting

### PowerShell

- PowerShell 5.1+ compatibility
- `try/catch` with structured error handling
- Exit codes: 0 (success), 1 (failure), 3010 (reboot required)
- SYSTEM execution context awareness for Intune scripts

## Memory & Continuous Improvement

Claude maintains learned patterns in `~/.claude/projects/-Users-jack-morton-GitHub-1/memory/`. After significant sessions, update memory with: what worked, mistakes to avoid, architecture decisions and rationale, discovered preferences.

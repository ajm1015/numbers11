# Bash script dev environment

A ready-to-use directory layout and tooling for building and maintaining bash scripts.

## Layout

```
bash-dev-env/
├── bin/           # Executables and entry points
├── lib/           # Reusable bash library (source from scripts)
├── scripts/       # Main bash scripts
├── tests/         # Bats tests
├── templates/     # Script templates
├── examples/      # Example scripts
├── Makefile       # lint, format, test
└── config         # .shellcheckrc, .editorconfig
```

## Quick start

1. **Install deps** (macOS):

   ```bash
   make install-deps
   ```

   Or manually: `brew install shellcheck shfmt bats-core`

2. **Lint, format, test**:

   ```bash
   make lint      # ShellCheck
   make format    # shfmt
   make test      # Bats
   make all       # all of the above
   ```

3. **Add scripts**: put new `.sh` files in `scripts/` (or `bin/` for entry points). Source shared helpers from `lib/common.sh`.

4. **Use the template**: copy `templates/script-template.sh` when starting a new script.

## Conventions

- Use `set -euo pipefail` in all scripts.
- Prefer `lib/common.sh` for logging (`log_info`, `log_warn`, `log_err`) and `SCRIPT_ROOT`.
- Keep scripts in `scripts/`; use `bin/` for thin wrappers or CLI entry points.
- Add Bats tests in `tests/` for `scripts/` and `lib/`.

## Tooling

| Tool       | Purpose              |
|-----------|----------------------|
| ShellCheck| Static analysis      |
| shfmt     | Formatting           |
| Bats      | Automated tests      |

Config: `.shellcheckrc`, `.editorconfig` (indent 2, LF, trim trailing WS).

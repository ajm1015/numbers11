# syntax=docker/dockerfile:1
# Multi-stage build for mcp-kandji MCP server.
# Runs as non-root 'mcp' user with dumb-init for proper signal handling.

# ── Build stage ──────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build tools
RUN pip install --no-cache-dir uv

# Copy shared package first (dependency)
COPY _shared/ /build/_shared/

# Copy server package
COPY mcp-kandji/ /build/mcp-kandji/

# Install shared package, then server package
RUN cd /build/_shared && uv pip install --system . \
    && cd /build/mcp-kandji && uv pip install --system .

# ── Production stage ─────────────────────────────────────────
FROM python:3.12-slim AS runtime

# Install dumb-init for proper PID 1 signal handling
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid 1000 mcp && useradd --uid 1000 --gid mcp --shell /bin/sh mcp

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY mcp-kandji/mcp_kandji /app/mcp_kandji

WORKDIR /app

# Switch to non-root user
USER mcp

# Health check — verifies the process is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import socket; s=socket.create_connection(('127.0.0.1', ${SERVER_PORT:-8001}), timeout=3); s.close()" || exit 1

EXPOSE 8001

ENTRYPOINT ["dumb-init", "--"]
CMD ["python", "-m", "mcp_kandji"]

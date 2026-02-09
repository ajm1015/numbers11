"""FastAPI backend for the Personal Dashboard Console."""

from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from status_checker import (
    CheckType,
    StatusResult,
    batch_check,
    check_http,
    check_tcp,
)

app = FastAPI(
    title="Dashboard Status API",
    description="API for checking status of machines and services",
    version="1.0.0",
)

# Configure CORS to allow frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your frontend URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response models
class PingRequest(BaseModel):
    host: str
    port: int
    timeout: float = 5.0


class HttpCheckRequest(BaseModel):
    url: str
    timeout: float = 10.0


class BatchCheckItem(BaseModel):
    id: str
    type: str = "tcp"  # tcp, http, https
    host: str
    port: Optional[int] = None
    url: Optional[str] = None


class BatchCheckRequest(BaseModel):
    checks: list[BatchCheckItem]
    timeout: float = 5.0


class StatusResponse(BaseModel):
    host: str
    status: str
    latency_ms: Optional[float] = None
    error: Optional[str] = None
    checked_at: Optional[float] = None


class BatchStatusResponse(BaseModel):
    results: dict[str, StatusResponse]


@app.get("/")
async def root():
    """Health check endpoint."""
    return {"status": "ok", "service": "Dashboard Status API"}


@app.get("/api/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.post("/api/status/ping", response_model=StatusResponse)
async def ping_host(request: PingRequest):
    """Check if a TCP port is open on a host."""
    result = await check_tcp(request.host, request.port, request.timeout)
    return StatusResponse(**result.to_dict())


@app.post("/api/status/http", response_model=StatusResponse)
async def check_http_endpoint(request: HttpCheckRequest):
    """Check if an HTTP/HTTPS endpoint is healthy."""
    result = await check_http(request.url, request.timeout)
    return StatusResponse(**result.to_dict())


@app.post("/api/status/batch", response_model=BatchStatusResponse)
async def batch_status_check(request: BatchCheckRequest):
    """Check multiple targets at once."""
    checks = [
        {
            "id": item.id,
            "type": item.type,
            "host": item.host,
            "port": item.port,
            "url": item.url,
        }
        for item in request.checks
    ]
    
    results = await batch_check(checks, request.timeout)
    
    # Map results back to IDs
    response_results = {}
    for i, item in enumerate(request.checks):
        result = results[i]
        response_results[item.id] = StatusResponse(**result.to_dict())
    
    return BatchStatusResponse(results=response_results)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

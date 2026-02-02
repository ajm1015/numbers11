"""Status checker module for checking machine and service health."""

import asyncio
import socket
import time
from dataclasses import dataclass
from enum import Enum
from typing import Optional

import httpx


class CheckType(str, Enum):
    TCP = "tcp"
    HTTP = "http"
    HTTPS = "https"
    ICMP = "icmp"


@dataclass
class StatusResult:
    """Result of a status check."""
    host: str
    status: str  # "online", "offline", "unknown"
    latency_ms: Optional[float] = None
    error: Optional[str] = None
    checked_at: Optional[float] = None

    def to_dict(self) -> dict:
        return {
            "host": self.host,
            "status": self.status,
            "latency_ms": self.latency_ms,
            "error": self.error,
            "checked_at": self.checked_at,
        }


async def check_tcp(host: str, port: int, timeout: float = 5.0) -> StatusResult:
    """Check if a TCP port is open on a host."""
    start_time = time.time()
    try:
        # Run the blocking socket operation in a thread pool
        loop = asyncio.get_event_loop()
        
        def _check():
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            try:
                result = sock.connect_ex((host, port))
                return result == 0
            finally:
                sock.close()
        
        is_open = await loop.run_in_executor(None, _check)
        latency = (time.time() - start_time) * 1000
        
        return StatusResult(
            host=f"{host}:{port}",
            status="online" if is_open else "offline",
            latency_ms=round(latency, 2),
            checked_at=time.time(),
        )
    except socket.timeout:
        return StatusResult(
            host=f"{host}:{port}",
            status="offline",
            error="Connection timed out",
            checked_at=time.time(),
        )
    except Exception as e:
        return StatusResult(
            host=f"{host}:{port}",
            status="unknown",
            error=str(e),
            checked_at=time.time(),
        )


async def check_http(url: str, timeout: float = 10.0) -> StatusResult:
    """Check if an HTTP/HTTPS endpoint is healthy."""
    start_time = time.time()
    try:
        async with httpx.AsyncClient(verify=False, follow_redirects=True) as client:
            response = await client.get(url, timeout=timeout)
            latency = (time.time() - start_time) * 1000
            
            # Consider 2xx and 3xx as healthy
            is_healthy = 200 <= response.status_code < 400
            
            return StatusResult(
                host=url,
                status="online" if is_healthy else "offline",
                latency_ms=round(latency, 2),
                error=None if is_healthy else f"HTTP {response.status_code}",
                checked_at=time.time(),
            )
    except httpx.TimeoutException:
        return StatusResult(
            host=url,
            status="offline",
            error="Request timed out",
            checked_at=time.time(),
        )
    except httpx.ConnectError as e:
        return StatusResult(
            host=url,
            status="offline",
            error=f"Connection failed: {str(e)}",
            checked_at=time.time(),
        )
    except Exception as e:
        return StatusResult(
            host=url,
            status="unknown",
            error=str(e),
            checked_at=time.time(),
        )


async def check_status(
    check_type: CheckType,
    host: str,
    port: Optional[int] = None,
    url: Optional[str] = None,
    timeout: float = 5.0,
) -> StatusResult:
    """Unified status check function."""
    if check_type == CheckType.TCP:
        if port is None:
            return StatusResult(
                host=host,
                status="unknown",
                error="Port is required for TCP check",
                checked_at=time.time(),
            )
        return await check_tcp(host, port, timeout)
    
    elif check_type in (CheckType.HTTP, CheckType.HTTPS):
        check_url = url or f"{check_type.value}://{host}"
        if port:
            # Insert port into URL
            from urllib.parse import urlparse, urlunparse
            parsed = urlparse(check_url)
            check_url = urlunparse(parsed._replace(netloc=f"{parsed.hostname}:{port}"))
        return await check_http(check_url, timeout)
    
    else:
        return StatusResult(
            host=host,
            status="unknown",
            error=f"Unsupported check type: {check_type}",
            checked_at=time.time(),
        )


async def batch_check(checks: list[dict], timeout: float = 5.0) -> list[StatusResult]:
    """Run multiple status checks concurrently."""
    tasks = []
    for check in checks:
        check_type = CheckType(check.get("type", "tcp"))
        host = check.get("host", "")
        port = check.get("port")
        url = check.get("url")
        
        tasks.append(check_status(check_type, host, port, url, timeout))
    
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # Convert exceptions to error results
    processed_results = []
    for i, result in enumerate(results):
        if isinstance(result, Exception):
            processed_results.append(StatusResult(
                host=checks[i].get("host", "unknown"),
                status="unknown",
                error=str(result),
                checked_at=time.time(),
            ))
        else:
            processed_results.append(result)
    
    return processed_results

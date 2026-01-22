#!/usr/bin/env python3
"""
AI Model Router - Intelligent routing between local and cloud models.
Provides OpenAI-compatible API endpoint at http://localhost:8080

Routes requests based on:
- Explicit model selection (local, claude, auto)
- Task classification (autocomplete, debug, refactor, etc.)
- Token limits (short responses -> local)

Usage:
    python ai-router.py
    
Then query:
    curl http://localhost:8080/v1/chat/completions -d '{"messages":[...]}'
"""

import os
import sys
import json
import re
import asyncio
from enum import Enum
from typing import Optional
import logging

try:
    import httpx
    from fastapi import FastAPI, Request, HTTPException
    from fastapi.responses import StreamingResponse, JSONResponse
    import uvicorn
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install fastapi uvicorn httpx")
    sys.exit(1)

# ============================================================================
# Configuration
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="AI Model Router", version="1.0.0")

class TaskType(Enum):
    AUTOCOMPLETE = "autocomplete"      # Fast, local
    QUICK_QUESTION = "quick"           # Fast, local
    EXPLANATION = "explanation"        # Can be local
    DOCUMENTATION = "documentation"    # Can be local
    REFACTOR = "refactor"              # Claude Pro
    DEBUG = "debug"                    # Claude Pro
    GENERATION = "generation"          # Claude Pro
    COMPLEX = "complex"                # Claude Pro

# Model endpoints and capabilities
MODELS = {
    "local_fast": {
        "endpoint": "http://localhost:11434/api/chat",
        "model": "deepseek-coder-v2:16b",
        "tasks": [TaskType.AUTOCOMPLETE, TaskType.QUICK_QUESTION],
        "max_context": 16000
    },
    "local_strong": {
        "endpoint": "http://localhost:11434/api/chat",
        "model": "qwen2.5-coder:32b",
        "tasks": [TaskType.EXPLANATION, TaskType.DOCUMENTATION],
        "max_context": 32000
    },
    "claude": {
        "endpoint": "https://api.anthropic.com/v1/messages",
        "model": "claude-sonnet-4-20250514",
        "tasks": [TaskType.REFACTOR, TaskType.DEBUG, TaskType.GENERATION, TaskType.COMPLEX],
        "max_context": 200000
    }
}

# ============================================================================
# Task Classification
# ============================================================================

def classify_task(messages: list, max_tokens: Optional[int] = None) -> TaskType:
    """Classify the task based on message content and parameters."""
    if not messages:
        return TaskType.QUICK_QUESTION
    
    last_message = messages[-1].get("content", "").lower()
    
    # Short responses are likely autocomplete
    if max_tokens and max_tokens < 100:
        return TaskType.AUTOCOMPLETE
    
    # Very short prompts are quick questions
    if len(last_message) < 50:
        return TaskType.QUICK_QUESTION
    
    # Pattern matching for task classification
    patterns = {
        TaskType.DEBUG: [
            r'\bfix\b', r'\bbug\b', r'\berror\b', r'\bdebug\b',
            r'\bwhy.*not.*work', r'\bfailing\b', r'\bbroken\b',
            r'\bissue\b', r'\bproblem\b'
        ],
        TaskType.REFACTOR: [
            r'\brefactor\b', r'\bimprove\b', r'\boptimize\b',
            r'\bclean\s*up', r'\brestructure\b', r'\bsimplify\b'
        ],
        TaskType.EXPLANATION: [
            r'\bexplain\b', r'\bhow\s+does\b', r'\bwhat\s+is\b',
            r'\bwhy\b', r'\bdescribe\b', r'\bunderstand\b'
        ],
        TaskType.DOCUMENTATION: [
            r'\bdocument\b', r'\bcomment\b', r'\breadme\b',
            r'\bdocstring\b', r'\bannotate\b'
        ],
        TaskType.GENERATION: [
            r'\bcreate\b', r'\bwrite\b', r'\bgenerate\b',
            r'\bbuild\b', r'\bimplement\b', r'\bmake\b',
            r'\badd\b.*\bfunction\b', r'\badd\b.*\bmethod\b'
        ],
        TaskType.COMPLEX: [
            r'\barchitect', r'\bdesign\b.*\bsystem\b',
            r'\bmultiple\s+files\b', r'\bentire\b',
            r'\bcomprehensive\b', r'\bfull\b.*\bimplementation\b'
        ]
    }
    
    for task_type, task_patterns in patterns.items():
        for pattern in task_patterns:
            if re.search(pattern, last_message):
                return task_type
    
    # Default to quick question for unmatched queries
    return TaskType.QUICK_QUESTION

def get_model_for_task(task: TaskType) -> dict:
    """Get the appropriate model configuration for a task."""
    for name, config in MODELS.items():
        if task in config["tasks"]:
            return config
    return MODELS["local_fast"]

# ============================================================================
# Ollama Integration
# ============================================================================

async def check_ollama_available() -> bool:
    """Check if Ollama is running."""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get("http://localhost:11434/api/tags", timeout=2.0)
            return response.status_code == 200
    except:
        return False

async def proxy_to_ollama(config: dict, messages: list, stream: bool, max_tokens: int):
    """Proxy request to Ollama."""
    ollama_messages = [{"role": m["role"], "content": m["content"]} for m in messages]
    
    async with httpx.AsyncClient() as client:
        if stream:
            async def generate():
                try:
                    async with client.stream(
                        "POST",
                        config["endpoint"],
                        json={
                            "model": config["model"],
                            "messages": ollama_messages,
                            "stream": True,
                            "options": {"num_predict": max_tokens}
                        },
                        timeout=120.0
                    ) as response:
                        async for line in response.aiter_lines():
                            if line:
                                try:
                                    data = json.loads(line)
                                    content = data.get("message", {}).get("content", "")
                                    if content:
                                        yield f"data: {json.dumps({'choices': [{'delta': {'content': content}}]})}\n\n"
                                except json.JSONDecodeError:
                                    continue
                    yield "data: [DONE]\n\n"
                except Exception as e:
                    logger.error(f"Ollama stream error: {e}")
                    yield f"data: {json.dumps({'error': str(e)})}\n\n"
            
            return StreamingResponse(generate(), media_type="text/event-stream")
        else:
            try:
                response = await client.post(
                    config["endpoint"],
                    json={
                        "model": config["model"],
                        "messages": ollama_messages,
                        "stream": False,
                        "options": {"num_predict": max_tokens}
                    },
                    timeout=120.0
                )
                data = response.json()
                return JSONResponse({
                    "choices": [{
                        "message": {
                            "role": "assistant",
                            "content": data.get("message", {}).get("content", "")
                        },
                        "finish_reason": "stop"
                    }],
                    "model": config["model"],
                    "usage": {"prompt_tokens": 0, "completion_tokens": 0}
                })
            except Exception as e:
                logger.error(f"Ollama error: {e}")
                raise HTTPException(status_code=502, detail=f"Ollama error: {e}")

# ============================================================================
# Claude Integration
# ============================================================================

async def proxy_to_claude(config: dict, body: dict):
    """Proxy request to Claude API."""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="ANTHROPIC_API_KEY not set. Add it to the LaunchAgent plist."
        )
    
    messages = body.get("messages", [])
    system_prompt = None
    anthropic_messages = []
    
    for msg in messages:
        if msg["role"] == "system":
            system_prompt = msg["content"]
        else:
            anthropic_messages.append({
                "role": msg["role"],
                "content": msg["content"]
            })
    
    # Ensure messages alternate properly
    if anthropic_messages and anthropic_messages[0]["role"] != "user":
        anthropic_messages.insert(0, {"role": "user", "content": "Hello"})
    
    async with httpx.AsyncClient() as client:
        try:
            anthropic_body = {
                "model": config["model"],
                "max_tokens": body.get("max_tokens", 4096),
                "messages": anthropic_messages
            }
            if system_prompt:
                anthropic_body["system"] = system_prompt
            
            response = await client.post(
                config["endpoint"],
                headers={
                    "x-api-key": api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                },
                json=anthropic_body,
                timeout=120.0
            )
            
            if response.status_code != 200:
                error_data = response.json()
                raise HTTPException(
                    status_code=response.status_code,
                    detail=error_data.get("error", {}).get("message", "Claude API error")
                )
            
            data = response.json()
            
            # Extract text content
            content = ""
            for block in data.get("content", []):
                if block.get("type") == "text":
                    content += block.get("text", "")
            
            return JSONResponse({
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": content
                    },
                    "finish_reason": "stop"
                }],
                "model": config["model"],
                "usage": data.get("usage", {})
            })
            
        except httpx.TimeoutException:
            raise HTTPException(status_code=504, detail="Claude API timeout")
        except Exception as e:
            logger.error(f"Claude error: {e}")
            raise HTTPException(status_code=502, detail=f"Claude error: {e}")

# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    ollama_ok = await check_ollama_available()
    claude_ok = bool(os.environ.get("ANTHROPIC_API_KEY"))
    
    return {
        "status": "ok",
        "ollama": "available" if ollama_ok else "unavailable",
        "claude": "configured" if claude_ok else "missing_api_key"
    }

@app.get("/v1/models")
async def list_models():
    """List available models."""
    models = []
    for name, config in MODELS.items():
        models.append({
            "id": name,
            "object": "model",
            "owned_by": "local" if "ollama" in config["endpoint"] else "anthropic"
        })
    return {"data": models, "object": "list"}

@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    """OpenAI-compatible chat completions endpoint with intelligent routing."""
    try:
        body = await request.json()
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON")
    
    messages = body.get("messages", [])
    if not messages:
        raise HTTPException(status_code=400, detail="Messages required")
    
    max_tokens = body.get("max_tokens", 1000)
    stream = body.get("stream", False)
    requested_model = body.get("model", "auto").lower()
    
    # Determine which model to use
    if "local" in requested_model:
        model_config = MODELS["local_fast"]
        routing_reason = "explicit local request"
    elif "claude" in requested_model or "anthropic" in requested_model:
        model_config = MODELS["claude"]
        routing_reason = "explicit Claude request"
    elif "strong" in requested_model:
        model_config = MODELS["local_strong"]
        routing_reason = "explicit strong local request"
    else:
        # Auto-route based on task classification
        task = classify_task(messages, max_tokens)
        model_config = get_model_for_task(task)
        routing_reason = f"auto-classified as {task.value}"
    
    logger.info(f"Routing to {model_config['model']} ({routing_reason})")
    
    # Check if Ollama is needed but unavailable
    if "ollama" in model_config["endpoint"] or "11434" in model_config["endpoint"]:
        if not await check_ollama_available():
            # Fallback to Claude if Ollama is down
            if os.environ.get("ANTHROPIC_API_KEY"):
                logger.warning("Ollama unavailable, falling back to Claude")
                model_config = MODELS["claude"]
            else:
                raise HTTPException(
                    status_code=503,
                    detail="Ollama is not running. Start with: brew services start ollama"
                )
        return await proxy_to_ollama(model_config, messages, stream, max_tokens)
    else:
        return await proxy_to_claude(model_config, body)

# ============================================================================
# Main
# ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("AI Model Router")
    print("=" * 60)
    print(f"Endpoint: http://127.0.0.1:8080/v1/chat/completions")
    print(f"Health:   http://127.0.0.1:8080/health")
    print("")
    print("Models configured:")
    for name, config in MODELS.items():
        print(f"  - {name}: {config['model']}")
    print("=" * 60)
    
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8080,
        log_level="warning"  # Reduce uvicorn noise
    )

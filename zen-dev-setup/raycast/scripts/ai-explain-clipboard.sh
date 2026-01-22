#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Explain Clipboard
# @raycast.mode fullOutput
# @raycast.packageName AI Workflow

# Optional parameters:
# @raycast.icon 📋

# Documentation:
# @raycast.description Explain code or text from clipboard using AI
# @raycast.author Your Name

clipboard=$(pbpaste)

if [[ -z "$clipboard" ]]; then
    echo "Clipboard is empty"
    exit 1
fi

echo "📋 Analyzing clipboard content..."
echo ""

# Escape the content for JSON
escaped=$(echo "$clipboard" | jq -Rs '.')

# Query with auto-routing (will use appropriate model based on complexity)
response=$(curl -s http://localhost:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"auto\",
        \"messages\": [{
            \"role\": \"user\",
            \"content\": \"Explain this concisely. If it's code, explain what it does. If it's text, summarize the key points:\n\n$clipboard\"
        }],
        \"max_tokens\": 1000
    }" 2>/dev/null)

if [[ -z "$response" ]]; then
    echo "❌ AI Router not running"
    exit 1
fi

echo "$response" | jq -r '.choices[0].message.content // "Error processing response"'

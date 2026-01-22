#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title AI Quick
# @raycast.mode fullOutput
# @raycast.packageName AI Workflow

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Question" }

# Documentation:
# @raycast.description Quick query to local AI model
# @raycast.author Your Name

query="$1"

if [[ -z "$query" ]]; then
    echo "Please provide a question"
    exit 1
fi

# Query the AI router (local model for quick questions)
response=$(curl -s http://localhost:8080/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"local\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$query\"}],
        \"max_tokens\": 500
    }" 2>/dev/null)

# Check if router is running
if [[ -z "$response" ]]; then
    echo "❌ AI Router not running"
    echo "Start it with: launchctl load ~/Library/LaunchAgents/com.local.ai-router.plist"
    exit 1
fi

# Extract and display response
echo "$response" | jq -r '.choices[0].message.content // "Error processing response"'

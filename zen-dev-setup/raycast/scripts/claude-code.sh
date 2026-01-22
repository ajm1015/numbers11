#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Claude Code
# @raycast.mode silent
# @raycast.packageName AI Workflow

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Task (optional)", "optional": true }

# Documentation:
# @raycast.description Open Claude Code in terminal with optional initial task
# @raycast.author Your Name

task="$1"

# Open Ghostty and run Claude Code
if [[ -n "$task" ]]; then
    open -a Ghostty --args -e "claude \"$task\""
else
    open -a Ghostty --args -e "claude"
fi

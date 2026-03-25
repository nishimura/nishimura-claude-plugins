#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

LISTDIR="/tmp/claude-trailing-ws"
mkdir -p "$LISTDIR"
echo "$FILE_PATH" >> "${LISTDIR}/${SESSION_ID}"

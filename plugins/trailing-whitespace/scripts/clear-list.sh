#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
LISTFILE="/tmp/claude-trailing-ws/${SESSION_ID}"
rm -f "$LISTFILE"

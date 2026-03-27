#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
LISTFILE="/tmp/claude-trailing-ws/${SESSION_ID}"

if [ ! -f "$LISTFILE" ]; then
    exit 0
fi

sort -u "$LISTFILE" | while read -r file; do
    if [ -f "$file" ]; then
        # Remove trailing whitespace (only if found)
        if grep -qP '[[:space:]]+$' "$file"; then
            sed -i -E 's/[[:space:]]+$//' "$file"
        fi
        # Add final newline if missing
        if [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
            echo >> "$file"
        fi
    fi
done

rm -f "$LISTFILE"

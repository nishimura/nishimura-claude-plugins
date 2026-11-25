#!/bin/bash
# Record files changed by Write/Edit, or by a Bash command (sed -i, heredoc, ...).
#
# A PostToolUse hook matching Write|Edit does not run when Bash rewrites a file,
# so Bash is matched as well. Since 2.1.269 the files a Bash command changed are
# passed in tool_response.bashEditDiff ({changedFiles, files[].filePath, moreFiles}).
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

FILES=$(echo "$INPUT" | jq -r '
  .tool_input.file_path? // empty,
  (.tool_response | objects | .bashEditDiff | objects |
    ((.changedFiles // [])[], ((.files // [])[] | objects | .filePath // empty)))
  | strings | select(. != "")
' | sort -u)

if [ -z "$FILES" ]; then
    exit 0
fi

LISTDIR="/tmp/claude-trailing-ws"
mkdir -p "$LISTDIR"
while read -r file; do
    case "$file" in
        /*) ;;
        *) [ -n "$CWD" ] && file="${CWD}/${file}" ;;
    esac
    echo "$file" >> "${LISTDIR}/${SESSION_ID}"
done <<< "$FILES"

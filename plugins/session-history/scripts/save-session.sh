#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
CWD=$(echo "$INPUT" | jq -r '.cwd')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

OUTDIR="${CLAUDE_SESSION_HISTORY_DIR:-$HOME/.local/share/claude-session-history}/logs"
mkdir -p "$OUTDIR"
OUTFILE="${OUTDIR}/${SESSION_ID}.txt"

FIRST_TS=$(jq -r 'select(.timestamp) | .timestamp' "$TRANSCRIPT_PATH" | head -1)
LAST_TS=$(tac "$TRANSCRIPT_PATH" | jq -r 'select(.timestamp) | .timestamp' | head -1)

FIRST_DATE=$(date -d "$FIRST_TS" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$FIRST_TS")
LAST_DATE=$(date -d "$LAST_TS" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$LAST_TS")

cat > "$OUTFILE" <<EOF
Session: $SESSION_ID
Directory: $CWD
Period: $FIRST_DATE ~ $LAST_DATE

EOF

jq -r '
  if .type == "user" and .userType == "external" then
    if (.message | type) == "object" and (.message.content | type) == "string" then
      if (.message.content | test("<command-message>")) then
        (.message.content | capture("<command-message>(?<cmd>[^<]+)</command-message>")) as $m |
        if (.message.content | test("<command-args>")) then
          (.message.content | capture("<command-args>(?<args>[^<]*)</command-args>")) as $a |
          if $a.args != "" then "\n❯ /" + $m.cmd + " " + $a.args + "\n"
          else "\n❯ /" + $m.cmd + "\n"
          end
        else
          "\n❯ /" + $m.cmd + "\n"
        end
      else
        "\n❯ " + .message.content + "\n"
      end
    else
      empty
    end
  elif .type == "assistant" then
    if (.message | type) == "object" and (.message.content | type) == "array" then
      .message.content[] |
      if .type == "text" then
        "\n● " + .text + "\n"
      elif .type == "tool_use" then
        "[" + .name + "] " + (
          if .name == "Read" or .name == "Edit" or .name == "Write" then
            .input.file_path // ""
          elif .name == "Glob" then
            .input.pattern // ""
          elif .name == "Grep" then
            .input.pattern // ""
          elif .name == "Bash" then
            (.input.command // "")[:80]
          elif .name == "Agent" then
            (.input.description // "")[:60]
          else
            (.input | tostring)[:80]
          end
        )
      else
        empty
      end
    else
      empty
    end
  else
    empty
  end
' "$TRANSCRIPT_PATH" >> "$OUTFILE"

#!/bin/bash
# Convert a Claude Code session transcript (JSONL) to readable text.
#
# Hook mode (no args): reads hook JSON from stdin, writes to logs directory.
# Command mode:        takes a transcript file path, outputs to stdout.
#
# Usage:
#   save-session.sh                          # hook mode (stdin JSON)
#   save-session.sh <transcript_path>        # command mode (stdout)

convert() {
    local TRANSCRIPT_PATH="$1"
    local SESSION_ID="$2"
    local CWD="$3"

    local FIRST_TS LAST_TS FIRST_DATE LAST_DATE
    FIRST_TS=$(jq -r 'select(.timestamp) | .timestamp' "$TRANSCRIPT_PATH" | head -1)
    LAST_TS=$(tac "$TRANSCRIPT_PATH" | jq -r 'select(.timestamp) | .timestamp' | head -1)
    FIRST_DATE=$(date -d "$FIRST_TS" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$FIRST_TS")
    LAST_DATE=$(date -d "$LAST_TS" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$LAST_TS")

    cat <<EOF
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
        elif (.message | type) == "object" and (.message.content | type) == "array"
             and (.toolUseResult | type) == "object" and (.toolUseResult.answers | type) == "object" then
          # AskUserQuestion answer: use the structured result. The tool_result
          # text has changed without notice (e.g. "User has answered your
          # questions:" -> "Your questions have been answered:"), so do not parse it.
          .toolUseResult as $r |
          ($r.answers // {}) as $ans |
          ($r.annotations // {}) as $ann |
          ([($r.questions // [])[] | .question | strings]) as $qs |
          ($qs + ([$ans | keys_unsorted[]] - $qs)) as $order |
          [ $order[] | . as $q | select($ans | has($q)) |
            ($ans[$q] | if type == "array" then join(", ") else tostring end) as $a |
            (($ann[$q] // {}) | if type == "object" then (.notes // "") else "" end | tostring) as $n |
            "  Q: " + ($q | gsub("\r"; "\n")) + "\n  A: " + ($a | gsub("\r"; "\n"))
              + (if $n != "" then "\n     notes: " + ($n | gsub("\r"; "\n")) else "" end)
          ] |
          if length > 0 then "\n[AskUserQuestion Answer]\n" + join("\n\n") + "\n" else empty end
        elif (.message | type) == "object" and (.message.content | type) == "array" then
          .message.content[] |
          # Fallback for old transcripts without a structured toolUseResult.
          if (type == "object" and .type == "tool_result" and (.content | type) == "string" and (.content | test("^User has answered your questions:"))) then
            "\n[AskUserQuestion Answer]\n" + (
              .content
              | sub("^User has answered your questions: "; "")
              | split(". You can now continue")[0]
              | gsub(", \""; "\u0001\"")
              | split("\u0001")
              | map(
                  capture("\"(?<q>[^\"]+)\"=\"(?<a>[^\"]*)\"( user notes: (?<n>.*))?") |
                  (.q | gsub("\r"; "\n")) as $q |
                  (.a | gsub("\r"; "\n")) as $a |
                  ((.n // "") | gsub("\r"; "\n")) as $n |
                  "  Q: " + $q + "\n  A: " + $a + (if $n != "" then "\n     notes: " + $n else "" end)
                )
              | join("\n\n")
            ) + "\n"
          else
            empty
          end
        else
          empty
        end
      elif .type == "assistant" then
        if (.message | type) == "object" and (.message.content | type) == "array" then
          .message.content[] |
          if .type == "text" then
            "\n● " + .text + "\n"
          elif .type == "thinking" then
            "\n✻ Thinking\n" + .thinking + "\n"
          elif .type == "tool_use" then
            if .name == "AskUserQuestion" then
              "[AskUserQuestion]" + (
                [.input.questions[] |
                  "\n  Q: " + .question + "\n" +
                  ([.options[] | "    - " + .label] | join("\n"))
                ] | join("\n")
              )
            else
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
            end
          else
            empty
          end
        else
          empty
        end
      else
        empty
      end
    ' "$TRANSCRIPT_PATH"
}

if [ -n "$1" ]; then
    # Command mode
    TRANSCRIPT_PATH="$1"
    if [ ! -f "$TRANSCRIPT_PATH" ]; then
        echo "File not found: $TRANSCRIPT_PATH" >&2
        exit 1
    fi
    SESSION_ID=$(jq -r 'select(.sessionId) | .sessionId' "$TRANSCRIPT_PATH" | head -1)
    CWD=$(jq -r 'select(.cwd) | .cwd' "$TRANSCRIPT_PATH" | head -1)
    convert "$TRANSCRIPT_PATH" "$SESSION_ID" "$CWD"
else
    # Hook mode
    INPUT=$(cat)
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')

    if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
        exit 0
    fi

    # Use launch cwd from transcript (hook's cwd may have been changed by Bash cd)
    CWD=$(jq -r 'select(.cwd) | .cwd' "$TRANSCRIPT_PATH" | head -1)

    # Skip if no user messages (excluding system tags)
    if ! jq -c 'select(.type == "user" and .userType == "external" and (.message | type) == "object" and (.message.content | type) == "string" and (.message.content | test("^<") | not))' "$TRANSCRIPT_PATH" 2>/dev/null | head -1 | grep -q .; then
        exit 0
    fi

    OUTDIR="${CLAUDE_SESSION_HISTORY_DIR:-$HOME/.local/share/claude-session-history}/logs"
    mkdir -p "$OUTDIR"

    # The Stop hook can fire before the final assistant messages are flushed
    # to the transcript. Return immediately and convert in the background
    # once the transcript has stopped growing (stable for 1s, max ~10s).
    (
        prev=-1
        stable=0
        for _ in $(seq 20); do
            sleep 0.5
            cur=$(stat -c %s "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
            if [ "$cur" = "$prev" ]; then
                stable=$((stable + 1))
                [ "$stable" -ge 2 ] && break
            else
                stable=0
            fi
            prev=$cur
        done
        OUTFILE="${OUTDIR}/${SESSION_ID}.txt"
        TMPFILE=$(mktemp "${OUTFILE}.XXXXXX") || exit 0
        if convert "$TRANSCRIPT_PATH" "$SESSION_ID" "$CWD" > "$TMPFILE"; then
            chmod 664 "$TMPFILE"
            mv -f "$TMPFILE" "$OUTFILE"
        else
            rm -f "$TMPFILE"
        fi
    ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
fi

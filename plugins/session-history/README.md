# session-history

Save session conversation logs as readable text files for later search and review.

## Problem

Claude Code's built-in `resume`/`continue` does not always list all sessions. When working across multiple directories and sessions, it's hard to find and resume them later.

## Solution

On every `Stop`, convert the session transcript (JSONL) into a human-readable text file. A CLI tool lists sessions, and `rg` can search the logs directly.

## Output format

```
Session: abc123-def456-...
Directory: /home/user/project
Period: 2026-04-01 10:00 ~ 2026-04-02 15:30

❯ User prompt here

● Assistant response here

[Read] /path/to/file
[Edit] /path/to/file
[Bash] npm test

● More assistant text

❯ /plugin install foo

[AskUserQuestion]
  Q: Question text?
    - Option A
    - Option B

[AskUserQuestion Answer]
  Q: Question text?
  A: Option A
     notes: user's additional comment
```

- User messages: `❯` prefix
- Assistant text: `●` prefix
- Tool calls: `[ToolName] argument`
- Slash commands: converted to `❯ /command args` format
- AskUserQuestion: questions with options, followed by answers with optional notes

## Logs location

`~/.local/share/claude-session-history/logs/`

Override with `CLAUDE_SESSION_HISTORY_DIR` env var.

## CLI

```bash
claude-sessions                        # List recent 10 sessions
claude-sessions -n 50                  # List recent 50 sessions
claude-sessions -a                     # List all sessions
claude-sessions -g "keyword"           # Filter sessions containing keyword
claude-sessions -d "ISSUE-123"         # Filter sessions by directory (partial match)
claude-sessions -d "ISSUE-123" -g "test"  # Combine filters
claude-sessions --remove SESSION_ID    # Remove a session log

rg 'keyword' ~/.local/share/claude-session-history/logs/   # Search log contents
```

### List output

Each session shows: last active date, first active date, session ID, directory, and a preview of the first user message, last user message, and last assistant response. Header lines are highlighted when output is a terminal.

```
2026-04-02 15:00 ~ 2026-03-25 10:42  f5f6dda2-...  /home/user/project
  ❯ First user message in session
  ...
  ❯ Last user message
  ● Last assistant response
```

### Command mode

The hook script can also be used directly to convert a transcript file:

```bash
plugins/session-history/scripts/save-session.sh ~/.claude/projects/.../session.jsonl | less
```

## Setup

```bash
# Add CLI to PATH
ln -s /path/to/nishimura-claude-plugins/plugins/session-history/bin/claude-sessions ~/bin/
```

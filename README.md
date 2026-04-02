# nishimura-claude-plugins

Personal Claude Code plugin marketplace.

## Plugins

### trailing-whitespace

Removes trailing whitespace from files edited by Claude Code.

**Problem:** Running `sed` on every `PostToolUse` changes the file mtime, which forces Claude to `Read` the file again before the next `Edit`. This breaks consecutive edits.

**Solution:** Defer the cleanup to the `Stop` hook. Record file paths during editing, then process them all at once when Claude finishes responding.

**Flow:**

```
UserPromptSubmit  -->  clear file list
        |
PostToolUse(Edit/Write)  -->  record file path (no file modification)
        |
Stop / StopFailure  -->  grep check + sed trailing whitespace + ensure final newline
```

### session-history

Saves session conversation logs as readable text files for later search and review.

**Problem:** Claude Code's built-in `resume`/`continue` does not always list all sessions. When working across multiple directories and sessions, it's hard to find and resume them later.

**Solution:** On every `Stop`, convert the session transcript (JSONL) into a human-readable text file. A CLI tool lists sessions, and `rg` can search the logs directly.

**Output format:**

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
```

**Logs location:** `~/.local/share/claude-session-history/logs/`
(Override with `CLAUDE_SESSION_HISTORY_DIR` env var)

**CLI:**

```bash
claude-sessions          # List recent 20 sessions
claude-sessions -n 50    # List recent 50 sessions
claude-sessions -a       # List all sessions
rg 'keyword' ~/.local/share/claude-session-history/logs/   # Search logs
```

## Installation

```bash
# Add this marketplace
/plugin marketplace add /path/to/nishimura-claude-plugins

# Install plugins
/plugin install trailing-whitespace@nishimura-claude-plugins
/plugin install session-history@nishimura-claude-plugins

# Add CLI to PATH (optional)
ln -s /path/to/nishimura-claude-plugins/plugins/session-history/bin/claude-sessions ~/bin/
```

## License

[MIT](LICENSE)

# nishimura-claude-plugins

Personal Claude Code plugin marketplace.

## Plugins

### trailing-whitespace

Removes trailing whitespace from files edited by Claude Code.

**Problem:** Running `sed` on every `PostToolUse` changes the file content, which forces Claude to `Read` the file again before the next `Edit`. This breaks consecutive edits and causes Claude to give up or try alternative approaches.

**Solution:** Defer the cleanup to the end of the response. Record file paths during editing, then process them all at once when Claude stops.

**Flow:**

```
User prompt
  |
  v
UserPromptSubmit --- clear /tmp/claude-trailing-ws/{session_id}
  |
  v
Claude editing files...
  |
  +-- Edit file A --> PostToolUse --- record path to tmp file
  +-- Edit file A --> PostToolUse --- record path (no file modification)
  +-- Edit file B --> PostToolUse --- record path
  |
  v
Stop / StopFailure --- sort -u paths, sed trailing whitespace, ensure final newline
```

**What it does:**
- Removes trailing whitespace (`sed 's/[[:space:]]*$//'`)
- Adds a final newline if missing

## Installation

```bash
# Add this marketplace
/plugin marketplace add /path/to/nishimura-claude-plugins

# Install the plugin
/plugin install trailing-whitespace@nishimura-claude-plugins
```

## License

[MIT](LICENSE)

# nishimura-claude-plugins

Personal Claude Code plugin marketplace.

## Plugins

### trailing-whitespace

Removes trailing whitespace from files edited by Claude Code.

Instead of running on every `Edit`/`Write` (which breaks consecutive edits), it records edited file paths during the response and processes them all at once when Claude stops.

**Hooks:**

| Event | Action |
|-------|--------|
| `UserPromptSubmit` | Clear the file list |
| `PostToolUse` (Write/Edit) | Record the file path |
| `Stop` / `StopFailure` | Remove trailing whitespace and ensure final newline |

## Installation

```bash
# Add this marketplace
/plugin marketplace add /path/to/nishimura-claude-plugins

# Install the plugin
/plugin install trailing-whitespace@nishimura-claude-plugins
```

## License

[MIT](LICENSE)

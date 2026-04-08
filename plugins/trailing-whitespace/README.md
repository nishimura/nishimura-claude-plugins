# trailing-whitespace

Removes trailing whitespace from files edited by Claude Code.

## Problem

Running `sed` on every `PostToolUse` changes the file mtime, which forces Claude to `Read` the file again before the next `Edit`. This breaks consecutive edits.

## Solution

Defer the cleanup to the `Stop` hook. Record file paths during editing, then process them all at once when Claude finishes responding.

## Flow

```
UserPromptSubmit  -->  clear file list
        |
PostToolUse(Edit/Write)  -->  record file path (no file modification)
        |
Stop / StopFailure  -->  grep check + sed trailing whitespace + ensure final newline
```

## What it does

- Removes trailing whitespace (`sed -E 's/[[:space:]]+$//'`)
- Adds a final newline if missing
- Only modifies files that actually have trailing whitespace (pre-checked with `grep`)

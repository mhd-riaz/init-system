# Path placeholders

Skills in this bundle write paths as placeholders so one file works on every provider.
Resolve them like this:

| Placeholder | Resolves to | Notes |
|---|---|---|
| `{{STATE_REPO}}` | `<repository root>/.agent/` | per-repo agent state; add `.agent/` to `.gitignore` |
| `{{STATE_GLOBAL}}` | `$AGENT_STATE_HOME`, else `~/.agent/state/` | cross-repo state; survives repo changes |
| `{{SKILLS_DIR}}` | the installed root of this bundle | where `SPEC.md` and `skills/` live |

Create the directory if it does not exist before writing. If the current working
directory is not inside a repository, `{{STATE_REPO}}` falls back to `{{STATE_GLOBAL}}`.

Never write agent state into the repository's tracked files.

## These must be real filesystem paths

Resolve to a path that exists on disk and is writable. **Never substitute a provider's
virtual or in-memory path.** `/memories/...` is a VS Code-only virtual path; skills that
used it wrote nothing at all on every other agent, and the failure was silent
(`AUDIT-LOG.md` B10).

Verify before depending on a cache or a log:

```sh
mkdir -p "$DIR" && test -w "$DIR"
```

If the location is not writable, state it in one line and continue without persistence.
Do not report cached or logged state that was never written.

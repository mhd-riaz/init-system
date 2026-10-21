# Outcome logging

Every skill appends one record when its invocation ends — completed or not. This file
holds the schema so no skill inlines it — it was previously duplicated near-verbatim
across all ten.

## Where

| Scope | Path | Use for |
|---|---|---|
| Repo-scoped | `{{STATE_REPO}}/skill-outcomes.md` | work tied to one repository |
| Global | `{{STATE_GLOBAL}}/skill-outcomes.md` | skills reusable everywhere (`ado-item`, `gh-issue`, `devlog`, `doc-lookup`, `study-notes`) |

Write via `CAP:MEMORY`, or append to the file directly if that capability is absent.
Create the file and parent directory if missing.

**Easiest path:** `agent-tools/outcome-log.sh <skill> <version> <outcome> "<correction>"
"<evidence>" [--global]`. It resolves the path, proves it is writable, and fails loudly
rather than silently. See [`../agent-tools/README.md`](../agent-tools/README.md).

### Verify the path before relying on it

**A previous generation of these skills logged to `/memories/...`, a VS Code virtual
path that does not exist in any other agent. Every record written outside VS Code was
silently lost, so the retrospective loop had nothing to mine** (`AUDIT-LOG.md` B10).

Before writing:

1. Resolve `{{STATE_REPO}}` / `{{STATE_GLOBAL}}` per
   [`../rules/paths.md`](../rules/paths.md) to a **real filesystem path**.
2. Create the directory if absent.
3. If the write fails, **say so in one line** — do not continue as though it succeeded.

A silent logging failure is forbidden. Losing a record is tolerable; believing a lost
record was written is what broke the loop last time.

## Schema

```markdown
## <ISO-8601 UTC timestamp> — <skill-name> v<version>
- session: <id, or "unavailable">
- outcome: success | corrected | abandoned | error
- correction: <one line on what had to be fixed or clarified, or "none">
- evidence: <file:line, command output, or URL proving the outcome>
```

## Outcome values

| Value | Means |
|---|---|
| `success` | Completed; the user accepted it without correcting the approach |
| `corrected` | Completed, but the user had to redirect, fix, or clarify something the skill should have handled |
| `abandoned` | Started and stopped — scope changed, blocked, or the user walked away |
| `error` | The skill's own instructions produced a wrong or failing result |

**`corrected` is the valuable one.** It is the signal `skill-retrospective` mines. Record
it honestly; a log of nothing but `success` is a log that improves nothing.

## Rules

- One record per skill invocation, appended at the end of the file.
- Write the record **when the invocation terminates**, whatever the outcome — completed,
  failed, abandoned or declined. Waiting for the completion criteria would mean `error`
  and `abandoned` are never recorded, which deletes exactly the evidence the
  retrospective needs. Never write it before the work stops.
- `correction` must be specific. "user clarified scope" is useless; "assumed ADO, repo
  was GitHub" is actionable.
- Never rewrite or delete an existing record. The log is append-only.
- If logging fails, continue — never block the user's task on bookkeeping.

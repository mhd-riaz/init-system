---
name: gh-issue
description: >
  Create and refine GitHub issues to a consistent standard — Markdown body, task-list
  acceptance criteria, real repo labels, assignee, milestone and sub-issue links. USE
  FOR: create a GitHub issue, file an issue, open an issue for this bug, add a sub-issue,
  break this down into issues, label and assign an issue, improve this issue. DO NOT USE
  FOR: Azure DevOps work items (use ado-item); reviewing or fixing PRs (use pr-review or
  resolve-pr); writing code (use write-code).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Owns GitHub issues: creating one, labelling and assigning it, and wiring parent/sub-issue
relationships. The GitHub mirror of `ado-item` — same discipline, different platform.

**The key difference from `ado-item`: the body is GitHub-Flavored Markdown, never HTML.**
ADO rich-text fields render HTML; GitHub renders GFM and shows raw HTML tags as clutter.
Carrying `ado-item`'s HTML conventions across is the single most likely mistake here.

This is a **low-freedom skill** ([SPEC §5](../../SPEC.md)) for formats, labels and
assignment — those are exact. Issue body *content* is high-freedom.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/work-item-context.md`](../../_shared/work-item-context.md) — identity,
  org, repo resolution and caching, and the full resolution ladder
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

### Use the `gh` CLI

Prefer the `gh` CLI over GitHub MCP tools for every operation in this skill. It is
faster, scriptable, authenticates from existing credentials, and costs no deferred-tool
search. `CAP:GH` resolves to it first; fall back to MCP, then REST, per
[`capabilities.md`](../../_shared/capabilities.md).

## Step 1 — Resolve repo and identity

Run the resolution ladder in
[`work-item-context.md`](../../_shared/work-item-context.md) **only for values you do not
already have**. Login, organization, repository and cached default labels all live there
— do not re-derive them and do not re-ask.

If `tracker.system` is not `github`, stop and hand off: `ado` → `ado-item`, `none` →
decline in one line. Route on the tracker, never on the remote — a GitHub remote with
`tracker.system: ado` means the work item belongs in Azure DevOps (`AUDIT-LOG.md` B21,
B31).

## Step 2 — Detect what the repo actually offers

Never invent a label, milestone, issue type or template. Enumerate them from the repo
before composing anything:

| Need | Resolve by |
|---|---|
| Labels | `gh label list` via `CAP:GH` — the repo's taxonomy is authoritative |
| Milestones | `gh api repos/:owner/:repo/milestones` |
| Issue types | Repo/org issue types where the org has them enabled |
| Templates | `.github/ISSUE_TEMPLATE/` via `CAP:GLOB` — match the template to the request |

If a template matches the request type (bug, feature, chore), fill **its** sections rather
than imposing a different shape. A template exists because the maintainers wanted it.

A label the user asked for that does not exist is reported back with the closest existing
matches — never created silently, never approximated.

## Step 3 — Ask once, batched

Collect everything still missing and ask it in **a single round** via `CAP:ASK`: title,
body content, acceptance criteria, labels, assignee, milestone, parent issue, and any
required template section.

Never interrogate across turns.

## Step 4 — Compose the body in GitHub-Flavored Markdown

| Need | GFM |
|---|---|
| Headings | `###` within the body — never `#` |
| Bullets | `- item` |
| Ordered steps | `1. step` |
| Code or log output | fenced block with a language tag |
| Acceptance criteria | task list — `- [ ] criterion` |
| Related issue | `#id` |
| Closing issue | `Closes #id` in the body of the PR or issue that resolves it |

Acceptance criteria are always GFM task lists, one `- [ ]` per independently verifiable
criterion. No HTML checkboxes, no `<p>`, no `<ul>` — this is the inverse of `ado-item`.

Reference related issues as `#id` so GitHub cross-links them. Use `Closes #id` only where
the closure is intended and automatic.

## Step 5 — Confirm the target, then create

> **Gate — before anything visible to the team.**
> Show the **exact target repository** (`owner/repo`) and the full field set — title,
> body, labels, assignee, milestone, parent — and stop. An issue notifies watchers and
> assignees the moment it exists; filing into the wrong repo cannot be quietly undone.
> See [`approval-gate.md`](../../_shared/approval-gate.md).

On approval, create the issue via `CAP:GH` with body, labels, assignee and milestone set
in the same call. Assignment is mandatory — default to the cached identity unless the
user names someone else.

## Step 6 — Link relationships

1. For a sub-issue, attach it to its parent using the repo's sub-issue support; where
   that is unavailable, add an explicit `Parent: #id` line and a task-list entry on the
   parent instead, and say which path was used.
2. For a breakdown, create the children first, then edit the parent body once with the
   full task list — not once per child.
3. Verify the link came back on the issue rather than assuming the call succeeded.

For any update to an existing issue: **fetch the live issue first.** Caches hold repo
context, never the issue's current state.

## Step 7 — Report

```
## #<number> — <title>
<issue url>

| Field | Value |
|---|---|
| Repository | <owner/repo> |
| State      | <open / closed> |
| Assignee   | <login> |
| Labels     | <comma-separated, or "none"> |
| Milestone  | <title, or "none"> |
| Parent     | #<id> <title>, or "none" |
| Children   | <#ids, or "none"> |
```

Report any degraded capability in one line rather than omitting a row.

## Related skills

| Situation | Skill |
|---|---|
| The tracker is Azure DevOps, not GitHub | `ado-item` |
| Implementing the issue once it exists | `write-code` |
| Reviewing a pull request | `pr-review` |
| Acting on reviewer comments | `resolve-pr` |
| Writing the PR body | `pr-description` |
| Recording the session afterwards | `devlog` |

## Rules

- When breaking an issue into sub-issues, size each so it can be completed in half a day
  or less **including code review and test cases** (`AUDIT-LOG.md` B19).
- Before closing any issue, verify every check in
  [`../../_shared/definition-of-done.md`](../../_shared/definition-of-done.md) against
  live state, including the closing comment describing what was delivered.
- Never write HTML into an issue body — GitHub renders GFM, and raw tags ship as visible
  clutter the maintainers then have to strip.
- Always express acceptance criteria as GFM task lists, one `- [ ]` per criterion.
- Never apply a label, milestone or issue type that does not already exist in the repo;
  enumerate them first and report misses with the closest matches.
- Never create an issue without an assignee.
- Use the repo's issue template when one matches the request.
- Batch every clarifying question into one round.
- Always fetch the live issue before updating it — a cache is never the source of truth
  for its current state.
- Reference related issues as `#id`; reserve `Closes #id` for intended auto-closure.
- Confirm the exact target repository and fields before creating anything.
- Prefer the `gh` CLI over GitHub MCP tools.

## Completion criteria

Done when the issue exists and the reply contains its URL plus the fields-summary table.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to `{{STATE_GLOBAL}}/skill-outcomes.md` — this skill is global-scoped.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. New GitHub counterpart to `ado-item`,
  consolidating repo/identity resolution, the approval gate and outcome logging onto the
  shared procedures instead of a second private copy of each.
- 1.1.0 (2026-10-20) — Added sub-issue sizing (B19) and the definition-of-done checks
  before closing (B18). No prior verdict reversed.
- 2.0.0 (2026-10-20) — Hand off on `tracker.system`, not the remote: a GitHub remote
  tracking work in Azure DevOps previously fell through to creating a GitHub issue
  (B31).

---
name: ado-item
description: >
  Create and refine Azure DevOps work items — Bug, User Story, Task — to a fixed field,
  HTML and date standard, caching identity and project context per repo. USE FOR: create
  an ADO bug, log a bug, create a user story or task, file a work item, add a child task,
  break down a story, link a work item to a parent, improve a ticket's quality, my ADO
  defaults. DO NOT USE FOR: GitHub issues (use gh-issue); PR work (use pr-review,
  resolve-pr, pr-description); writing code (use write-code).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Owns Azure DevOps work items and nothing else: creating a Bug, User Story or Task,
linking it into a hierarchy, and raising an existing item to a consistent standard.

This is a **low-freedom skill** ([SPEC §5](../../SPEC.md)). Field mappings, rich-text
format, date arithmetic and assignment are exact and not open to interpretation. Follow
them literally; improvisation here produces items the team has to repair by hand.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/work-item-context.md`](../../_shared/work-item-context.md) — identity,
  org, project, area path and iteration caching, and the full resolution ladder
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

## Step 1 — Resolve identity and repo context

Run the resolution ladder in
[`work-item-context.md`](../../_shared/work-item-context.md) **only for values you do not
already have**. Identity, organization, project, default area path and default iteration
all live there — do not re-derive them and do not ask for them again.

If `tracker.system` is not `ado`, stop and hand off: `github` → `gh-issue`, `none` →
decline in one line. The code host is irrelevant here — ADO work items are normal on a
GitHub-hosted repository (`AUDIT-LOG.md` B21). Never route on the git remote.

## Step 2 — Verify the type's fields before using them

Never assume a field exists. Fetch the live work-item type definition for the target type
in **this** project via `CAP:ADO` and reconcile it against the table below. Projects
customize process templates: a required field may exist that this table does not list, and
a listed field may be absent or renamed.

| Field | Reference name | Rule |
|---|---|---|
| Title | `System.Title` | One imperative line. No id prefix, no trailing period |
| Description | `System.Description` | HTML. User Story and Task |
| Repro Steps | `Microsoft.VSTS.TCM.ReproSteps` | HTML. Bug — this is the Bug's description field |
| Acceptance Criteria | `Microsoft.VSTS.Common.AcceptanceCriteria` | HTML, disabled checkbox list |
| Assigned To | `System.AssignedTo` | **Mandatory on every creation** |
| Area Path | `System.AreaPath` | Cached default unless the user names another |
| Iteration Path | `System.IterationPath` | Cached default unless the user names another |
| Priority | `Microsoft.VSTS.Common.Priority` | `tracker.default_priority`, else **2; 1 when the bug blocks production** |
| Severity | `Microsoft.VSTS.Common.Severity` | Bug only |
| Start Date | `Microsoft.VSTS.Scheduling.StartDate` | Derived from the iteration, Step 5 |
| Target Date | `Microsoft.VSTS.Scheduling.TargetDate` | Iteration finish date, Step 5 |
| Remaining Work | `Microsoft.VSTS.Scheduling.RemainingWork` | Zero it before closing a completed item |

Any required field the live definition reports and this table does not cover becomes a
question in Step 3 — never a guessed value.

### Rich text is HTML, never Markdown

ADO rich-text fields render HTML. Markdown pasted into them renders as literal asterisks
and hashes. Emit HTML:

| Need | HTML |
|---|---|
| Paragraph | `<p>text</p>` |
| Bullets | `<ul><li>item</li></ul>` |
| Ordered steps | `<ol><li>step</li></ol>` |
| Code or log output | `<pre><code>output</code></pre>` |
| Emphasis | `<strong>`, `<em>` |
| Acceptance criterion | `<div><input type="checkbox" disabled /> criterion</div>` |

Acceptance criteria are always the **disabled checkbox** form above — one `div` per
criterion, each independently verifiable.

## Step 3 — Ask once, batched

Collect everything still missing and ask it in **a single round** via `CAP:ASK`: title,
type, the body content, acceptance criteria, parent, severity, estimates, and any
project-required field discovered in Step 2.

Never interrogate across turns. A second question the user could have answered in the
first round is a defect in this step.

## Step 4 — Verify the parent

If a parent id was supplied, fetch the live item via `CAP:ADO` and confirm:

- it exists and is in the same project;
- its type can legally parent the child (Epic → Feature → User Story → Task/Bug);
- its area and iteration paths — inherit them unless the user said otherwise.

A parent that fails any check is reported back, not silently dropped.

## Step 5 — Derive dates from the cached iteration

| Value | Source |
|---|---|
| Start Date | Iteration start date, or now if the iteration is already underway |
| Target Date | Iteration finish date |
| All timestamps | **ISO 8601 UTC**, `Z` suffix |

The user works in IST (UTC+5:30). Convert by subtracting 5 hours 30 minutes: **8:00 PM
IST is `14:30Z`**. Never write a local-time string into a date field.

> **Gate — missing iteration dates.**
> If iteration lookup fails or has no dates, ask the user for explicit dates instead of
> guessing. A guessed sprint boundary silently misdates the item and every report built
> on it. See [`approval-gate.md`](../../_shared/approval-gate.md).

## Step 6 — Confirm, then create

Show the exact field set that will be written — type, title, assignee, area, iteration,
priority, dates, parent — and stop. A created work item is visible to the team and
notifies its assignee; it cannot be un-sent.

On approval, create the Bug, User Story or Task via `CAP:ADO` with every field from
Steps 2–5 populated in the same call.

## Step 7 — Link, assign, and close out

1. Create the parent-child link if a parent was supplied, and verify it came back on the
   item rather than assuming the call succeeded.
2. Confirm `System.AssignedTo` resolved to a real identity. An unassigned item is a
   failed creation, not a partial success.
3. When the request is to close or complete an item, set Remaining Work to `0` **before**
   moving the state. A closed item carrying remaining hours corrupts burndown.

For any update to an existing item: **fetch the live item first.** Caches hold context,
never the item's current state — someone else may have edited it since.

## Step 8 — Report

```
## <Type> <id> — <title>
<item url>

| Field | Value |
|---|---|
| Type          | <Bug / User Story / Task> |
| State         | <state> |
| Assigned To   | <display name> |
| Area Path     | <path> |
| Iteration     | <path> |
| Priority      | <1-4> |
| Severity      | <value, or "n/a"> |
| Start / Target| <ISO-8601 UTC> / <ISO-8601 UTC> |
| Parent        | <id and title, or "none"> |
```

Report any degraded capability in one line rather than omitting a row.

## Related skills

| Situation | Skill |
|---|---|
| The tracker is GitHub, not Azure DevOps | `gh-issue` |
| Implementing the item once it exists | `write-code` |
| Reviewing a pull request | `pr-review` |
| Acting on reviewer comments | `resolve-pr` |
| Writing the PR body | `pr-description` |
| Recording the session afterwards | `devlog` |

## Rules

- When breaking a story into tasks, size each task so it can be completed in half a day
  or less **including code review and test cases** — a task that cannot be is too big,
  split it (`AUDIT-LOG.md` B19).
- Before closing any task or story, verify every check in
  [`../../_shared/definition-of-done.md`](../../_shared/definition-of-done.md) against
  live state, including the closing comment describing what was delivered.
- If one Azure DevOps tool registration errors, retry per the mutation-safety rule in
  [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — reads retry freely;
  a create, update or link must be verified against live state first (`AUDIT-LOG.md`
  B11, B35).
- Never write Markdown into a rich-text field — ADO renders HTML, so Markdown ships as
  literal punctuation the team then has to clean up.
- Always emit acceptance criteria as disabled HTML checkboxes, one per criterion.
- Always write timestamps as ISO 8601 UTC; convert from IST by subtracting 5:30.
- Never create a work item without an assignee.
- Default Priority to `tracker.default_priority`; when the config does not set it, use 2,
  and 1 only when the bug blocks production.
- Batch every clarifying question into one round.
- Always fetch the live item before updating it — a cache is never the source of truth
  for the item's current state.
- Never invent a field, area path, iteration or label that the live project definition
  does not contain.
- Zero Remaining Work before closing a completed item.
- Never guess iteration dates; ask instead.
- Show the exact fields and wait for confirmation before creating anything.

## Completion criteria

Done when the work item is created (and linked/updated if a parent was given) and the
reply contains the item link plus the fields-summary table.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to `{{STATE_GLOBAL}}/skill-outcomes.md` — this skill is global-scoped.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates work-item creation onto
  shared identity/project caching, the approval gate and outcome logging, replacing the
  per-skill copies of the resolution ladder and cache schema.
- 1.1.0 (2026-10-20) — Added task sizing (half-day including review and tests, B19),
  the six definition-of-done checks before closing (B18), and the duplicate-MCP-
  registration retry rule (B11). No prior verdict reversed.
- 2.0.0 (2026-10-20) — Route on `tracker.system`, never the git remote: ADO items are
  normal in a GitHub-hosted repo (B31). Priority now defaults from
  `tracker.default_priority` (B36). Retry rule split read from write (B35).

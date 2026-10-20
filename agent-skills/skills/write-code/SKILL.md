---
name: write-code
description: >
  The single implementation workflow for tracked work and approved specs. Enforces design
  approval before coding, secure implementation, and verified completion. USE FOR:
  implement a feature, fix a bug, write or modify code, start work on a task/bug/story,
  build this from the approved plan or spec, implement milestone N. DO NOT USE FOR:
  writing tests alone (use write-tests); reviewing a PR (use pr-review); addressing
  reviewer comments (use resolve-pr); writing a PR body (use pr-description); creating a
  tracker item (use ado-item or gh-issue).
license: MIT
metadata:
  version: 1.1.0
---

## Purpose

Owns implementation: turning an agreed requirement into working, tested, reviewed code.
Two entry modes — **tracked** (a work item exists) and **spec-driven** (an approved
plan or milestone exists). Both converge after Step 2.

The defining constraint: **no code is written before the user approves a design.**

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/work-item-context.md`](../../_shared/work-item-context.md)
- [`../../_shared/security-review.md`](../../_shared/security-review.md)
- [`../../_shared/test-and-coverage.md`](../../_shared/test-and-coverage.md)
- [`../../_shared/definition-of-done.md`](../../_shared/definition-of-done.md) — the
  six checks before anything is called done
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

## Step 1 — Establish the work

| Signal | Mode | Then |
|---|---|---|
| A work-item id, or "the bug/story/task" | **tracked** | Fetch the live item via `CAP:ADO` or `CAP:GH` |
| "from the plan/spec/PRD", "milestone N" | **spec-driven** | Read the approved plan; confirm which milestone |
| Neither, and the change is non-trivial | **ambiguous** | Ask once which applies |
| Neither, and the change is a one-line obvious fix | **direct** | Proceed; skip tracker steps |

Resolve tracker context via
[`work-item-context.md`](../../_shared/work-item-context.md) — only for values you do not
already have.

Fetch the item **once** per task and work from that copy. Confirm the scope back to the
user in one line before continuing.

## Step 2 — Gather real context

1. **Refresh the branch** with `git fetch --prune` via `CAP:GIT`, then compare `HEAD`
   against the resolved base branch. Do **not** use `git pull` — it fails outright when
   the upstream branch was deleted after its PR merged, which is the normal state of a
   branch you just shipped (`AUDIT-LOG.md` B13).
2. Read the code that will actually change — implementation, not names or callers.
3. Identify every caller and dependent with `CAP:USAGES`.
4. Check existing conventions in neighbouring files: error handling, logging, DI, naming.
5. For library or framework questions, use `CAP:DOCS` — never model recall. See
   [`../../rules/doc-lookup.md`](../../rules/doc-lookup.md).
6. Delegate genuinely independent investigation to `CAP:SUBAGENT` at `TIER:FAST`.

## Step 3 — Design and threat-model

Produce, concisely:

- **Approach** — what changes and why, in a few sentences.
- **Files** — each file to be created or modified, with a one-line reason.
- **Contracts** — API, schema, config, or interface changes. Flag breaking ones.
- **Impact** — callers affected, migrations needed, backward-compatibility story.
- **Threat model** — what untrusted input reaches this code, what it can touch, what
  fails open. Use [`security-review.md`](../../_shared/security-review.md).
- **Risks and alternatives** — what might not work, and the option you rejected.

> **Gate — design approval.**
> Present the design and stop. Offer: proceed / proceed with changes / stop.
> **Do not write or edit any code until the user explicitly confirms.** Not a
> partial start, not a scaffold, not "just the types". An unapproved implementation
> that is 90% right still has to be re-reviewed from scratch.
> See [`approval-gate.md`](../../_shared/approval-gate.md).

## Step 4 — Implement

Work in small, coherent increments. After each one, the tree should still build.

- **Re-read before relying on anything stale** — files edited since you read them, files
  from an earlier session, files another process touched. See
  [`../../rules/evidence-first.md`](../../rules/evidence-first.md).
- **Follow the codebase's existing patterns** over your preferred ones. Consistency beats
  personal taste in someone else's repository.
- **Handle errors at the right layer.** No silent catch, no swallowed error, no bare
  `except`. Errors carry context.
- **No secrets, keys, or tokens in source, tests, fixtures, or logs.**
- **Prefer the standard library** to a new dependency. Add dependencies only when the
  task requires them.
- **Use the ecosystem's tools** — package managers, formatters, codemods, refactoring
  tools — over hand-editing.
- **Comment only what needs clarification.** Do not narrate the code.
- **Change only what the approved design covers.** Unrelated fixes belong in their own
  task; a bug caused by or tightly coupled to your change is in scope.
- Delegate independent, substantial sub-tasks to `CAP:SUBAGENT`; keep the conclusions.

## Step 5 — Verify

In order, and all of them:

1. **Lint and format** with the project's configured tooling.
2. **Check `CAP:DIAGNOSTICS`** for compile and type errors before running anything.
3. **Security review** against [`security-review.md`](../../_shared/security-review.md).
   Report by severity with `file:line`.
4. **Code-quality pass** — dead code, duplication, over-engineering, naming, leaked
   abstractions, missing edge cases.
5. **Tests** — hand off to `write-tests` for scenario design and coverage. Targets and
   procedure live in [`test-and-coverage.md`](../../_shared/test-and-coverage.md).
6. **Re-read the full diff.** Confirm it matches the approved design and contains no
   debug statements, stray comments, or unintended changes.

A missed coverage target is reported with its number and an explanation, never silently.

## Step 6 — Close out

1. Update documentation that your change made wrong. Documentation-only changes need no
   test run.
2. **Check every item in
   [`definition-of-done.md`](../../_shared/definition-of-done.md)** against live state —
   PR exists, tests included, baseline unbroken, commit prefix correct, review done,
   closing comment written. Report which passed, failed, or could not be verified.
3. Update the work item via `CAP:ADO` / `CAP:GH` — status, and a brief note of what
   shipped. Skip in spec-driven mode.
4. Record the session with `devlog` if the repository keeps one.
5. **Stop.** Do not begin the next milestone or adjacent work without a new instruction.

## Step 7 — Delivery report

```
## <what was built>

Objective      <one line>
Files          <path — what changed, per file>
Contracts      <API/schema/config changes, or "none">
Security       <findings by severity, or "no issues found">
Tests          <added/modified; passed/failed>
Coverage       <per package, against target; explain any gap>
Limitations    <what this does not handle>
Follow-ups     <deferred work, or "none">
How to test    <exact commands the user can run>
```

Every line must be true and verifiable. An unmeasured number is reported as unmeasured.

## Related skills

| Situation | Skill |
|---|---|
| Scenario design, mocks, coverage work | `write-tests` |
| Reviewing a PR rather than writing code | `pr-review` |
| Acting on reviewer comments | `resolve-pr` |
| Writing the PR body after implementing | `pr-description` |
| Creating or refining the tracker item first | `ado-item`, `gh-issue` |
| Recording the session | `devlog` |
| The underlying engineering rules | `engineering-os` |
| Current library or framework documentation | `doc-lookup` |

## Rules

- Never write or edit code before the Step 3 gate clears.
- Never claim a test passed, a target was met, or a tool ran without the output proving it.
- Never commit, push, or open a PR unless the user asked for it.
- Never modify a pre-existing passing test to make a change fit.
- Never introduce a secret into tracked files.
- Never expand scope beyond the approved design without returning to the gate.
- Re-read any file that may have changed since you last read it before depending on it.
- Report missed coverage targets with the number and the reason.
- State every degraded capability in one line rather than skipping the step silently.
- Never report a work item as done until every check in
  [`definition-of-done.md`](../../_shared/definition-of-done.md) has been verified live.
- One MCP registration failing does not mean the capability is gone — try the alternate
  registration before falling back.

## Completion criteria

Done when: lint and diagnostics are clean; the security and code-quality reviews are
complete; `write-tests` has reported at or above target, or the gap is explained; the
diff has been re-read and matches the approved design; the Step 7 delivery report has
been presented; and the work item and devlog are updated where applicable.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates the implementation
  workflow onto shared procedures for security review, coverage, approval gates, and
  work-item context, replacing per-skill copies of each.
- 1.1.0 (2026-10-20) — Step 2 now uses `git fetch --prune` and base-branch comparison
  instead of `git pull`, which fails once the upstream branch is deleted post-merge
  (B13). Step 6 and Rules now require the six definition-of-done checks the user asked
  to have persisted (B18). Added the duplicate-MCP-registration rule (B11). No prior
  verdict reversed.

---
name: resolve-pr
description: >
  Resolves reviewer comments end-to-end: gathers every thread, verifies each against the
  real code, filters false positives, applies only approved fixes, and re-runs the full
  suite. USE FOR: fix PR comments, address review feedback, resolve PR threads, act on
  reviewer suggestions, apply PR review changes. DO NOT USE FOR: writing a new PR
  description (use pr-description); reviewing a PR for the first time (use pr-review);
  implementing new feature work (use write-code).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Owns the response side of code review: taking comments that already exist on a pull
request and turning the legitimate ones into minimal, verified fixes. `pr-review`
produces comments; this skill consumes them.

The defining constraint: **no code changes until the user approves the complete triage.**
Automated reviewers have a high false-positive rate, and changing correct code to satisfy
a machine that misread it is a regression dressed as diligence.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/pr-fetch.md`](../../_shared/pr-fetch.md) — identify, fetch, diff, threads
- [`../../_shared/evidence-filter.md`](../../_shared/evidence-filter.md) — the classifier
  and the protected-file list
- [`../../_shared/test-and-coverage.md`](../../_shared/test-and-coverage.md) — run procedure
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

## Step 1 — Obtain the PR and detect the platform

Follow Steps A and B of [`pr-fetch.md`](../../_shared/pr-fetch.md): resolve the PR from
a URL, a number plus the current repo, or the current branch's open PR, and detect
GitHub versus Azure DevOps from the host or the `origin` remote.

Confirm the PR title and target branch back in one line before touching anything.

## Step 2 — Gather every comment

Delegate the read-only gathering to `CAP:SUBAGENT` at `TIER:FAST` with a closed-ended
prompt: fetch all review threads and inline comments and return, per comment, the file,
line, author, body, resolution state, and replies — **verbatim, with no judgement and no
raw log output.** Restate the one-line secrets prohibition from
[`../../rules/no-secret-files.md`](../../rules/no-secret-files.md) in the prompt;
sub-agents do not inherit this bundle's rules.

Keep only the returned list. Do not re-fetch what the sub-agent already returned.

**Require the sub-agent to report what it could not fetch** — a thread count it was
capped at, a page it did not reach, an Azure DevOps thread API it could not reach — and
either fetch the remainder yourself or name it in the report as ungathered. "Every
comment" is a claim about completeness; a capped list does not support it
(`AUDIT-LOG.md` B34).

## Step 3 — Discard what is not actionable

Remove, without reading surrounding code, every comment that is:

- already **resolved**, **closed**, or marked **won't fix**
- on a **file deleted** by this PR
- on **protected content** — a released changelog entry, an applied migration, a devlog
  or append-only log — per the protected-file table in
  [`evidence-filter.md`](../../_shared/evidence-filter.md). Protection covers shipped
  history, **not** a changelog entry or migration this PR itself added: check the diff
  before discarding, because content the PR introduced is reviewable like any other.
- a **compliment, acknowledgement, or question already answered** in its own thread

Count what was discarded and in which bucket. The counts appear in the report; the
comments do not.

## Step 4 — Verify every remaining comment against the real code

For each survivor, **read a minimum of ~20 lines around the referenced line** before
deciding anything, then trace what the code actually does — follow the call, check the
type, read the implementation of what it invokes.

Classify with [`evidence-filter.md`](../../_shared/evidence-filter.md) and record the
`file:line` evidence that produced each verdict. A `[FALSE POSITIVE]` needs a stated
reason: *"input is validated at `handler.go:41` before reaching this path"*, never
"looks fine".

## Step 5 — Present the complete triage and get approval

Present **every** classified comment in one table — valid, false positive, skipped, and
needs-input together. A partial table invites approval of a plan the user cannot see.

```
## PR <id> — comment triage

| # | file:line | Reviewer claim | Verdict | Evidence / reason | Planned fix |
|---|---|---|---|---|---|
| 1 | `svc/user.go:88` | missing nil check | [VALID] | deref at `:91` with no guard | add guard, return typed error |
| 2 | `svc/user.go:14` | unused import | [FALSE POSITIVE] | used at `:52` | none |
| 3 | `CHANGELOG.md:4` | fix wording | [SKIP] | protected historical file | none |
| 4 | `api/route.go:30` | should this be async? | [NEEDS-INPUT] | depends on intended SLA | ask |

Discarded: <N resolved/wontfix> · <N on deleted files> · <N historical files> · <N compliments>
```

> **Gate — applying fixes.**
> Ask, verbatim:
> **"Shall I proceed with fixing all VALID items? Or would you like to exclude any?"**
> Default: fix every `[VALID]` item as described. Batch any `[NEEDS-INPUT]` questions
> into this same round. See [`approval-gate.md`](../../_shared/approval-gate.md).
> **Do not edit, commit, push, reply to a thread, or resolve a thread before this
> clears.** Not the "obvious" one-liners, not a scaffold. An unapproved fix to code the
> reviewer misread is a regression the user now has to find.

## Step 6 — Apply the approved fixes

1. **Re-read each file immediately before editing it.** What you read at Step 4 may be
   stale — the branch may have moved, or an earlier fix in this run may have shifted it.
2. Make the **minimal change that resolves the comment.** Resist the adjacent cleanup;
   unrelated edits make the reviewer re-review the whole file.
3. Follow the repository's existing conventions over your preferred ones.
4. Batch edits to the same file into one operation.
5. Keep a running note of each comment addressed and the `file:line` that now answers it.

## Step 7 — Ask about documentation and code discrepancies

Where a comment exposes a mismatch between documentation and code — a stale docstring, a
README describing old behaviour, a comment contradicting the implementation — **do not
pick a side.** Collect them and ask separately which is correct, since only the author
knows whether the code drifted or the documentation did.

## Step 8 — Run the full suite

Run the complete suite with coverage per the run procedure in
[`test-and-coverage.md`](../../_shared/test-and-coverage.md), using `CAP:TEST-RUN`.

Separate the results into:

- **New failures** — caused by the fixes just applied. Root-cause each from the actual
  output and the implementation, then fix it. These block completion.
- **Pre-existing failures** — present on the branch before any change. Verify that claim
  rather than assuming it. Report them and ask the user to acknowledge; do not fix them
  silently and do not count them against this task.

## Step 9 — Report

```
## PR <id> — resolution summary

Addressed       <N> — each: `file:line` — <comment> → <what changed>
False positives <N> — each: `file:line` — <claim> — not valid: <evidence>
Skipped         <N> — each: <comment> — <why: protected file, out of scope, resolved>
Discrepancies   <doc-vs-code mismatches awaiting the user's decision — or "none">
Tests           <before: P/F/S> → <after: P/F/S>  (pre-existing failures: N)
Files changed   <path — what changed, per file>
Not done        <approved items that could not be completed, and why — or "none">
```

Before/after test counts are both measured. An unmeasured value is reported as
unmeasured.

## Related skills

| Situation | Skill |
|---|---|
| Producing the review comments in the first place | `pr-review` |
| Writing or rewriting the PR body | `pr-description` |
| Implementing new feature work rather than fixes | `write-code` |
| Designing or repairing the tests themselves | `write-tests` |
| The underlying engineering rules behind a fix | `engineering-os` |
| Library or framework behaviour in question | `doc-lookup` |

## Rules

- Never edit, commit, push, reply, or resolve a thread before the Step 5 gate clears.
- Never modify a protected or historical file to satisfy a review comment.
- Never fix a comment without first reading ~20 lines of surrounding context.
- Never accept an automated reviewer's claim as true because it sounds plausible.
- Every `[FALSE POSITIVE]` carries a stated reason with `file:line` evidence.
- Never re-raise or re-litigate a comment already classified `[FALSE POSITIVE]`.
- Re-read each file immediately before editing it.
- Make the minimal change that resolves the comment; no adjacent cleanup.
- Never modify a pre-existing passing test to make a fix fit.
- Never attribute a pre-existing failure to these fixes without verifying the base.
- Never silently fix a pre-existing failure — report it and let the user decide.
- Decide a documentation-versus-code conflict by asking, never by choosing.
- State every degraded capability in one line rather than skipping the step silently.

## Completion criteria

Done when all approved VALID comments are fixed, the full test suite passes (or
pre-existing failures are explicitly acknowledged by the user), and the final summary
has been presented.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates PR fetching, comment
  classification, the protected-file list, and the test run procedure onto their
  `_shared/` procedures, replacing the per-skill copies of each.
- 2.0.0 (2026-10-20) — Protection covers shipped history, not every file in a category:
  a changelog entry or migration added by this PR is reviewed normally (B42). Capped or
  failed gathering must be reported, never treated as the complete set (B34).

---
name: pr-review
description: >
  Reviews a pull request for correctness, performance, security, standards and test
  coverage, audits the existing comment threads for false positives, and posts only
  after approval. USE FOR: review a PR, check a PR, audit PR changes, validate a PR
  before merge, is this PR ready to merge. DO NOT USE FOR: fixing or resolving existing
  review comments (use resolve-pr); writing a new PR description (use pr-description);
  implementing the change yourself (use write-code).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Owns the first-pass review of someone's pull request: reading the real code, verifying
the comments already on it, running the tests it affects, and producing findings that a
human can act on. It **produces** review comments. `resolve-pr` **consumes** them.

The defining constraint: **nothing is posted until the user approves the exact text.** A
posted comment is attributed to them and cannot be silently retracted.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/pr-fetch.md`](../../_shared/pr-fetch.md) — identify, fetch, diff, threads
- [`../../_shared/evidence-filter.md`](../../_shared/evidence-filter.md) — the classifier
- [`../../_shared/test-and-coverage.md`](../../_shared/test-and-coverage.md) — PR coverage threshold
- [`../../_shared/repo-config.md`](../../_shared/repo-config.md) — per-repo coverage
  overrides and which definition-of-done checks apply here
- [`../../_shared/security-review.md`](../../_shared/security-review.md) — the checklist
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

## Step 1 — Fetch the PR

Follow [`pr-fetch.md`](../../_shared/pr-fetch.md) end to end: identify the PR and
platform, pull metadata, pull the diff **with the full current contents of each changed
file**, and pull every existing comment thread.

Reviewing from hunks alone manufactures findings about concerns handled four lines
outside the hunk. If the PR is too large to read in full, say which files were reviewed
from the diff alone in the final report.

## Step 2 — Audit the existing comments

Before forming any opinion of your own, work through every comment already on the PR.

1. Open the file each one refers to and read **at least ~20 lines of surrounding
   context**.
2. Classify each with [`evidence-filter.md`](../../_shared/evidence-filter.md) —
   `[VALID]`, `[FALSE POSITIVE]`, `[SKIP]`, or `[NEEDS-INPUT]`.
3. Record the `file:line` evidence that produced the verdict.

This runs first because it changes what is left to review. A concern already raised and
genuinely valid does not need re-stating in your own words; one already raised and false
must never be repeated.

## Step 3 — Run the tests this PR affects

1. Identify the tests covering the changed files — by convention, by directory, and by
   `CAP:USAGES` on the changed symbols.
2. Run them with `CAP:TEST-RUN`, falling back to the project's runner via `CAP:SHELL`.
3. Distinguish failures **caused by this PR** from failures already present on the base
   branch. Verify rather than assume: a pre-existing failure reported as a blocker
   discredits the whole review.

If the branch cannot be checked out or the suite cannot run, state that plainly and
review without it. Never report a test result that did not execute.

## Step 4 — Read the coverage

Read the coverage report for the changed files. Flag any changed file below the PR
threshold in
[`test-and-coverage.md`](../../_shared/test-and-coverage.md) as a **blocker**, with its
measured number.

New code with no new tests is a blocker regardless of the aggregate percentage — a
repository-wide average hides an entirely untested new module.

## Step 5 — Review the changed code

Read the implementation, not the names. Every finding carries `file:line` and a concrete
fix. Cover, in this order:

| Dimension | Look for |
|---|---|
| **Correctness** | logic errors, off-by-one, wrong operator, unhandled branches, nil/null paths, races, swallowed errors, incorrect error propagation |
| **Contracts** | breaking API/schema/config changes, backward compatibility, migrations, callers found via `CAP:USAGES` |
| **Performance** | queries in loops, N+1, unbounded result sets, missing pagination, repeated recomputation, missing timeouts, unnecessary allocation on hot paths |
| **Security** | the full checklist in [`security-review.md`](../../_shared/security-review.md), reported by its severity markers |
| **Standards** | the repository's existing conventions — error handling, logging, DI, naming, layering — not personal preference |
| **Simplification** | dead code, duplication, over-engineering, a dependency where the standard library would do, abstractions with one caller |

Two things are not findings: a style difference the repository does not enforce, and a
preference restated as a principle. Say nothing rather than pad the list.

## Step 6 — Present the findings and get approval

Present the complete report from Step 8 — every finding, in the exact wording that would
be posted — then stop.

> **Gate — posting to the PR.**
> **Skip this gate entirely when the user asked for a report only** — "don't post",
> "just tell me", "review it locally". Nothing is being written, so there is nothing to
> approve; deliver the report and state that nothing was posted.
> Otherwise ask, verbatim:
> **"Shall I post these comments to the PR, skip any, or make changes before posting?"**
> Default: post as shown. See
> [`approval-gate.md`](../../_shared/approval-gate.md).
> **Do not post, reply to a thread, resolve a thread, approve, request changes, or
> change the PR state before this clears.** Not "the obvious ones first", not a single
> blocker "to save a round trip". Every comment is public and attributed to the user.

## Step 7 — Post and confirm

After approval, post only the approved items via `CAP:GH` or `CAP:ADO`, as inline
comments anchored to `file:line` where the platform supports it.

Then confirm back: what was posted, where, and what was withheld. If any post failed,
say which and why — never report an unconfirmed write as done.

## Step 8 — Report template

Emit this literally, filling every field:

```
## PR Review — <repo> #<id> — <title>

Scope           <N files, +A/-D lines> · <head> → <base>
Reviewed from   <full contents | diff-only for: file list>
Comment audit   <N existing> → valid <V> · false positive <F> · skipped <S> · needs input <Q>
Tests           <selector> — passed: N  failed: N  skipped: N  (pre-existing failures: N)
Coverage        <changed files: NN%> against the PR threshold — <pass | BLOCKER>

### 🔴 Blockers — must fix before merge
- `path/file:line` — <what is wrong, and why it is wrong> → <the concrete fix>

### 🟠 Improvements — should fix
- `path/file:line` — <what> → <the fix>

### 🟡 Suggestions — optional
- `path/file:line` — <what> → <the fix>

### Existing comments — false positives
- `path/file:line` — <the claim> — not valid: <evidence at file:line>

### Needs your input
- <question that cannot be settled from the code>

Counts          blockers <N> · improvements <N> · suggestions <N>
Verdict         approve | approve with comments | request changes | blocked
```

## Related skills

| Situation | Skill |
|---|---|
| Acting on the comments once they exist | `resolve-pr` |
| Writing or rewriting the PR body | `pr-description` |
| Implementing the change rather than reviewing it | `write-code` |
| Designing or repairing the tests themselves | `write-tests` |
| The underlying review and quality rules | `engineering-os` |
| Library or framework behaviour in question | `doc-lookup` |

## Rules

- Never post, reply, resolve, approve, or request changes before the Step 6 gate clears.
- Never re-raise a comment already classified `[FALSE POSITIVE]` — repeating a rejected
  claim is noise, and it trains the author to ignore the next one.
- Every finding carries `file:line` and a concrete fix. A finding without a location is
  an opinion.
- Never report a test result, coverage number, or CI status that was not observed.
- Never attribute a pre-existing failure to this PR without verifying against the base.
- **Volume is not quality.** Ten verified findings beat forty speculative ones.
- Read ~20 lines of surrounding context before judging any line.
- Review against the repository's conventions, not personal preference.
- Never modify the PR branch, the code, or the tests from this skill — that is
  `resolve-pr` and `write-code`.
- Prefer `[NEEDS-INPUT]` to guessing when intent, not code, decides the answer.
- State every degraded capability in one line rather than skipping the step silently.

## Completion criteria

| The request | Done when |
|---|---|
| Review and post | Approval obtained at the Step 6 gate and, if approved, the review posted and confirmed to the user |
| Review only — "don't post", "just tell me", "review this locally" | The report is delivered. **No approval round**: there is nothing to approve when nothing will be written. Say in one line that nothing was posted |

A report-only request that ends in an approval prompt is a defect, not caution.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates PR fetching, comment
  classification, the security checklist, and the coverage threshold onto their
  `_shared/` procedures, replacing the per-skill copies of each.
- 1.1.0 (2026-10-20) — Coverage thresholds and applicable close checks now read from
  `.agent/config.yml` when present (B21).
- 2.0.0 (2026-10-20) — A report-only request finishes at the report: the posting gate is
  skipped when nothing will be written, and completion criteria are stated per mode
  (B43). Gathering completeness now follows the PARTIAL/UNAVAILABLE labels in
  `_shared/pr-fetch.md` (B34).

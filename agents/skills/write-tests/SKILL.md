---
name: write-tests
description: >
  Evidence-based testing: scenario suites across all five classes, an isolated instance
  or mock for every external dependency, parallel-safe tests, and per-package coverage.
  USE FOR: write unit tests, generate testcases for a folder or package, generate mocks
  for a layer, run the test suite, check or improve coverage, fix a broken or flaky
  test. DO NOT USE FOR: implementing the feature (use write-code); reviewing a PR (use
  pr-review); acting on reviewer comments (use resolve-pr); writing a PR body (use
  pr-description).
license: MIT
metadata:
  version: 1.3.0
---

## Purpose

Owns test design, mocking, execution, and coverage measurement. Runs immediately after
`write-code` on the same change, or standalone against a folder, package, or failing
test.

The defining constraint: **a coverage number is not a correctness claim.** Fully covered
code exercised only by happy-path tests is untested code with a good score. Scenario
breadth is the deliverable; the percentage is the receipt.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/repo-config.md`](../../_shared/repo-config.md) — `testing.command`,
  `testing.per_package_command` and `coverage.*` overrides for this repository
- [`../../_shared/test-and-coverage.md`](../../_shared/test-and-coverage.md) — scenario
  classes, mocking policy, coverage targets, run procedure, report format
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

## Step 1 — Confirm the scope

State back, in one line: which packages, modules, or folders are in scope, and which of
the three entry modes applies.

| Signal | Mode | Then |
|---|---|---|
| Follows an implementation this session | **change-scoped** | Test what `write-code` changed, plus its callers |
| "tests for `<path>`", "cover this package" | **target-scoped** | Test the named unit and everything it owns |
| "this test is failing/flaky", a test name | **repair** | Skip to Step 7; root-cause before touching anything |

Ambiguous scope gets one question, not a guess. Testing the wrong package is a whole
wasted run.

## Step 2 — Prepare the test environment

1. Clear the framework's test cache **once for the whole task** — not before each run.
   A stale cache turns a real failure into a phantom one and a real pass into a lie.
2. Load test configuration through the project's **existing config or secret loader**.
   Never read a credential file directly; see
   [`../../rules/no-secret-files.md`](../../rules/no-secret-files.md).
3. Identify the runner, the coverage flag, and the parallel flag the project already
   uses. Do not introduce a second framework alongside the one in place.

## Step 3 — Read what already exists

Read before writing — conventions beat preferences in someone else's repository.

1. The **implementation** under test, not its names or its callers' assumptions.
2. Neighbouring **test files**: naming, table/parameterized style, fixture and factory
   helpers, assertion library, setup and teardown idiom.
3. Existing **mocks, fakes, and test doubles** already available. Reusing one is always
   better than authoring a near-duplicate.
4. Callers and dependents via `CAP:USAGES`, to know which contracts must not break.

## Step 4 — Isolate every external dependency

Build the boundary before designing scenarios — an untestable seam found at Step 6
invalidates the scenario set.

- Mock every external dependency per the mocking policy in
  [`test-and-coverage.md`](../../_shared/test-and-coverage.md).
- **Databases get an isolated in-memory or ephemeral instance, never hand-written driver
  mocks.** A driver mock asserts what you believe the driver does; the bug is usually the
  gap between that belief and the driver. An in-memory instance tests behaviour instead.
- Name the seams that do not exist yet. If the unit cannot be isolated without a
  production change, say so and hand it back to `write-code` — do not reshape production
  code from here.

## Step 5 — Design the scenarios

For each unit, enumerate cases across **all five scenario classes** defined in
[`test-and-coverage.md`](../../_shared/test-and-coverage.md). List them before writing
any assertion; a list is cheap to review and expensive to reverse-engineer from code.

Derive cases from the implementation's actual branches, guards, and error returns — not
from the function name or the docstring. See
[`../../rules/evidence-first.md`](../../rules/evidence-first.md).

## Step 6 — Write the tests

- **Parameterized or table-driven** over copy-pasted near-identical cases.
- **Independently runnable and parallel-safe**: no shared mutable state, no ordering
  dependency, no fixed ports, unique temp paths.
- One behaviour per case. A test that can fail for three reasons diagnoses none of them.
- Assert on observable behaviour and contracts, not on internal call sequences, unless
  the sequence *is* the contract.
- Test names state the condition and the expectation, so a failure is readable without
  opening the file.
- No secrets, tokens, or real credentials in tests or fixtures.
- Delegate **substantial test authoring for modules unrelated to the current one** to
  `CAP:SUBAGENT` at `TIER:FAST`, with a closed-ended prompt naming the files, the
  conventions, and the scenario list. Keep the conclusions. Do not delegate the module
  you are actively iterating on.

## Step 7 — Run, measure, and close the gaps

Follow the run procedure in
[`test-and-coverage.md`](../../_shared/test-and-coverage.md): focused tests while
iterating, the **complete suite exactly once at the end**, in parallel, with coverage
enabled. Use `CAP:TEST-RUN`, falling back to the project's native runner via `CAP:SHELL`.

1. **Root-cause every failure from the actual output and the implementation.** Never
   from a plausible theory about what probably broke. Read the real stack trace, then
   read the code it points at.
2. A test that passed before the change and fails after it is a **regression in the
   change** until proven otherwise.
3. Read the coverage report and add scenarios for the **uncovered branches** it names.
   Write tests for the gap, never adjust the threshold to meet the number.
4. Report any missed target with its number and the reason — never silently.

> **Gate — modifying a pre-existing test.**
> Do not change a pre-existing passing test silently. Present the specific issue and
> ask for confirmation. Offer: fix the test / fix the implementation / leave it and
> report. See [`approval-gate.md`](../../_shared/approval-gate.md).
> A quietly edited assertion is how a real regression ships green.

## Step 8 — Report

```
## Test Run Summary

<package/module/folder>   passed: N   failed: N   skipped: N   coverage: NN% | unmeasured
<package/module/folder>   passed: N   failed: N   skipped: N   coverage: NN% | unmeasured

Failures        <test name — root cause, with file:line — or "none">
Gaps addressed  <uncovered branch — the scenario added to cover it>
Targets missed  <package — NN% against target, and why — or "none">
Legacy flags    <pre-existing or legacy tests needing the user's decision — or "none">
Commands        <exact commands the user can re-run>
```

Every number comes from output that actually ran. An unmeasured value is reported as
unmeasured, never estimated.

## Related skills

| Situation | Skill |
|---|---|
| Implementing or changing the feature itself | `write-code` |
| Reviewing a PR, including its test coverage | `pr-review` |
| Fixing tests broken by reviewer-requested changes | `resolve-pr` |
| Writing the PR body after the suite is green | `pr-description` |
| The underlying testing and quality rules | `engineering-os` |
| Test-framework API questions | `doc-lookup` |

## Rules

- Record a clean-tree baseline before changing anything; a failure is only "pre-existing"
  if it matches that baseline (`AUDIT-LOG.md` B15).
- Prove a new test fails against broken behaviour before reporting it as coverage — a
  test that passes either way is not coverage (`AUDIT-LOG.md` B16).
- If the project's test wrapper aborts at the first failing package, re-run through the
  native runner's machine-readable output to produce the full per-package table, and name
  the command that produced it (`AUDIT-LOG.md` B14).
- Repository testing conventions override this skill's defaults; state the override and
  its source rather than applying it silently (`AUDIT-LOG.md` B17).
- Never modify a pre-existing passing test without the Step 7 gate clearing.
- Never claim a test passed, a suite ran, or a target was met without output proving it.
- Never report a coverage percentage that was not measured this run.
- Never weaken an assertion, skip a case, or lower a threshold to turn a suite green.
- Never mock the unit under test, and never let a unit test reach a real network.
- Never hand-write driver mocks for a database — use an isolated in-memory instance.
- Never read a secret file for test configuration; go through the project's loader.
- Clear the test cache once per task, never per run.
- Run the full suite once, at the end, with coverage — not repeatedly while iterating.
- Root-cause failures from actual output and the implementation, never from a theory.
- Reshape production code only via `write-code`; flag untestable seams instead.
- State every degraded capability in one line rather than skipping the step silently.

## Completion criteria

Done when the Test Run Summary has been presented with passed/failed/skipped/coverage
per package, and any pre-existing-test flags have been raised to the user.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates scenario design, mocking
  policy, coverage targets, run procedure, and report format onto
  `_shared/test-and-coverage.md`, replacing the per-skill copies of each.
- 1.1.0 (2026-10-20) — Added the clean-tree baseline requirement (B15), mutation proof
  for new tests (B16), the native-runner fallback when the project wrapper aborts early
  (B14), and explicit precedence for repository conventions (B17). No prior verdict
  reversed.
- 1.2.0 (2026-10-20) — Test commands and coverage targets now read from
  `.agent/config.yml` when present, overriding bundle defaults (B21).
- 1.3.0 (2026-10-20) — The report may state `coverage: unmeasured`; `test-run.sh`
  reports pass/fail only and never produced the number (B44).

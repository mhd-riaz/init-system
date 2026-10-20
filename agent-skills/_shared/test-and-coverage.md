# Tests and coverage — shared thresholds and run procedure

The numeric targets and run mechanics shared by `write-code`, `write-tests`, `pr-review`,
and `resolve-pr`. Defined once here; each skill states only when it applies them.

## Coverage targets

| Scope | Target | Applies in |
|---|---|---|
| Backend / service code | **90%+** | `write-code`, `write-tests` |
| Frontend / UI code | **80%+** | `write-code`, `write-tests` |
| Critical business logic | **95%+** | `write-code`, `write-tests` |
| Changed files in a PR | **75%+** | `pr-review` (below this is a blocker) |

A target that is missed is not a silent failure — **report the number and explain the
gap.** An unexplained shortfall is an incomplete task; an explained one may be fine.

## Repository conventions outrank these defaults

If the repository has its own testing prompt, guide, or convention that conflicts with
anything here, **the repository wins**. One project's guide asked for "fewer meaningful
cases" and no forced scale scenarios, which contradicts the taxonomy above
(`AUDIT-LOG.md` B17).

State the override and its source when you apply it — *"scale scenarios omitted per the
project's go-echo testing guide"*. Never apply it silently, and never apply these
defaults over an explicit project convention.

## Scenario taxonomy

Every unit under test gets scenarios across all five classes. Coverage percentage alone
does not establish correctness — fully covered code with only happy-path tests is
untested code with a good score.

| Class | Covers |
|---|---|
| **Positive** | valid input, expected flow |
| **Negative** | invalid input, errors, rejected auth, malformed payloads |
| **Rare** | empty collections, nulls, single-element, duplicates, unicode, timezone edges |
| **Extreme** | max/min values, overflow, deep nesting, maximum field lengths |
| **Scalability** | large inputs, concurrency, repeated invocation, parallel safety |

## Mocking policy

- **Mock every external dependency**: network, filesystem outside fixtures, clocks,
  randomness, third-party APIs, message queues.
- **Databases use an isolated in-memory or ephemeral instance**, not hand-written driver
  mocks. Driver mocks encode assumptions about the driver rather than testing behaviour.
- Never mock the unit under test.
- A test that reaches a real network is not a unit test.

## Test design rules

- Tests must be **independently runnable and parallel-safe** — no shared mutable state,
  no ordering dependency, no fixed ports, unique temp paths.
- Prefer parameterized/table-driven cases over copy-pasted near-identical tests.
- Load test configuration from the project's existing config or secret loader. Never read
  a secret file directly (see [`../rules/no-secret-files.md`](../rules/no-secret-files.md)).

## Establish a baseline first

**Use `agent-tools/test-run.sh --baseline`, then `--compare`.** The baseline records the
command, scope and revision it was taken with; `--compare` matches **failure identities**
rather than summary text, so an added passing package is not reported as a new failure
and a swapped failing test is not missed (`AUDIT-LOG.md` B33). It warns when the compared
run used a different command or scope — a comparison across two commands is not evidence.

**Before changing anything, record what already fails.** Run the suite and the linter on
a clean tree and keep the result.

Without a baseline, "that failure is pre-existing" is an assertion. With one it is
evidence — two prior sessions resolved exactly this way: *"the four failing packages
match the clean-tree baseline"* and *"lint.sh 22 findings identical to a clean tree"*
(`AUDIT-LOG.md` B15).

Compare against the baseline before reporting any failure as pre-existing.

## Run procedure

1. **Clear the framework's test cache once** at the start of the task, not per run.
2. **While iterating**, run only the focused tests for the unit in question.
3. **Once at the end**, run the complete suite in parallel with coverage enabled.
4. Use `CAP:TEST-RUN`; fall back to the project's native runner via `CAP:SHELL`.
5. **Root-cause every failure from actual output and the implementation** — never from a
   plausible theory. See [`../rules/evidence-first.md`](../rules/evidence-first.md).

### When the project's test script aborts early

`agent-tools/test-run.sh` already handles this automatically.

A wrapper that exits on the first failing package cannot produce a per-package summary —
*"`bash unit-test.sh` aborts at the first failing package, so the per-package table came
from `go test ./... -json`"* (`AUDIT-LOG.md` B14).

If the wrapper stops early, **re-run through the native runner's machine-readable
output** (`go test ./... -json`, `pytest --json-report`, `jest --json`) to get the
complete picture. Report the full table, and note which command produced it.

## Prove a new test actually tests something

A test that passes against broken behaviour is not coverage. Before reporting a new test
as done, **break the behaviour it covers and confirm it fails**, then restore it —
*"proved with a before/after mutation run: panic, then 4 clean failures"*
(`AUDIT-LOG.md` B16).

Required for tests covering critical business logic; recommended everywhere else.

## Pre-existing tests

A test that passed before your change and fails after it is a **regression in your
change** until proven otherwise. Do not edit it to make it pass.

If a pre-existing test appears genuinely wrong, do not change it silently. Present the
specific issue and ask — see [`approval-gate.md`](approval-gate.md).

## Report format

Per package / module / folder:

```
<package>   passed: N   failed: N   skipped: N   coverage: NN%
```

`test-run.sh` reports pass/fail/skip only — it does not measure coverage. Either run the
runner's own coverage flag (`go test -cover`, `pytest --cov`, `jest --coverage`) and
report the real number, or write `coverage: unmeasured`. Never leave the field implying
a measurement that was not taken.

Then: failures with root causes, coverage gaps addressed, and any pre-existing tests
flagged for the user.

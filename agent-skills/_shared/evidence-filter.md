# Evidence filter — classifying claims before acting

Used when assessing someone else's claims: existing PR comments, automated review bots,
static-analysis output, or a proposed change. `pr-review`, `resolve-pr`, and
`skill-retrospective` all share this classifier.

Automated reviewers produce a high false-positive rate. Acting on an unverified comment
means changing correct code to satisfy a machine that misread it.

## Procedure

For each claim, **before** deciding anything:

1. Open the file it refers to and read a **minimum of ~20 lines of surrounding context**.
   A claim judged from the quoted snippet alone is a guess.
2. Trace what the code actually does — follow the call, check the type, read the
   implementation of what it invokes.
3. Classify:

| Verdict | Meaning | Action |
|---|---|---|
| `[VALID]` | Reproduced against the real code; the problem is genuinely there | Fix it |
| `[FALSE POSITIVE]` | The code does not do what the claim says, or the concern is already handled elsewhere | Do not fix. Record the one-line reason |
| `[SKIP]` | Real but out of scope: pre-existing, unrelated to this change, or an explicitly protected file | Do not fix. Record why |
| `[NEEDS-INPUT]` | Cannot be resolved from the code — depends on intent or a product decision | Batch into one question for the user |

4. Record the verdict **with its evidence** (`file:line` or the output that proves it).

## Rules

- **Never re-raise a claim already classified `[FALSE POSITIVE]`** in this session or
  recorded in the thread. Repeating a rejected comment is noise.
- A `[FALSE POSITIVE]` needs a stated reason. "Looks fine" is not a reason;
  "input is validated at `handler.go:41` before reaching this path" is.
- **Volume is not quality.** Ten verified findings beat forty speculative ones.
- When genuinely uncertain, prefer `[NEEDS-INPUT]` over guessing in either direction.

## Protected files

Protect **history that has already shipped**, not every file in a category. Rewriting a
released changelog entry or an applied migration to satisfy a review is always wrong;
fixing a line the current PR itself added is ordinary review.

| File | Protected | Reviewable normally |
|---|---|---|
| changelog, release notes | entries for released versions | an unreleased entry added by this PR |
| migration / schema history | a migration already applied anywhere beyond the author's machine | a migration introduced and unapplied in this PR |
| devlogs, session logs, `AUDIT-LOG.md`, append-only logs | always — being an unedited record is the point | — |
| lockfiles | always | when the PR *is* the dependency update |

The test is the diff: `git --no-pager diff <base>...HEAD -- <file>`. Lines this PR
introduced are new code and reviewable like any other; lines that predate it are history.
When both appear in one file, only the added lines are in scope.

If a comment targets protected content, classify it `[SKIP]` and explain.

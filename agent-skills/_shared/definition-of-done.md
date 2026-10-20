# Definition of done

The user's standing completion constraints, captured verbatim from the session where
they were stated and the agent was asked to persist them (`AUDIT-LOG.md` B18).

Applies to `write-code`, `ado-item`, `gh-issue` and `pr-description`.

## Before closing any task or story

Check all six. A task that fails any of them is not done.

1. **A PR exists** for the task.
2. **The PR contains unit tests** for each new piece of functionality.
3. **No previously passing test is broken** — prove it against a clean-tree baseline, see
   [`test-and-coverage.md`](test-and-coverage.md).
4. **Commits carry the work-item prefix** — see the reference formats below.
5. **The PR has been reviewed** by the configured automated reviewer on the hosting
   platform.
6. **A closing comment exists on the work item** describing what was delivered — not
   "done", but what shipped and where.

Verify each against live state. Do not assume a prior step left it in place; re-check.

## Work-item reference formats

Two different separators are in use. They are not interchangeable — observed usage:

| Where | Format | Example |
|---|---|---|
| Commit message prefix | `AB#id - ` | `AB#3204291 - add xMatters sender` |
| Azure DevOps PR title | `AB#id : ` | `AB#3204291 : xMatters notification sender` |
| GitHub PR body | `Closes #id` | `Closes #142` |

The format follows `tracker.system`, not the code host — ADO-tracked work on a GitHub
repository still uses `AB#id`. Under `tracker.system: none` there is no reference and no
work item: checks 4 and 6 do not apply, and the remaining four still do.

PR titles are capped at `tracker.pr_title_max` characters including the prefix, 59 when
the config does not set one.

## Task sizing

When breaking a story into tasks, size each one so it can be completed in **half a day
or less, including code review and test cases** (`AUDIT-LOG.md` B19). A task that cannot
be finished in ~4h with its review and tests is too big — split it.

## Reporting

State which of the six checks passed, which failed, and which could not be verified.
"Could not verify" is an acceptable report; silence is not.

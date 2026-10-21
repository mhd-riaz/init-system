# Context discipline

Applies to any task involving logs, command output, test results, or an unfamiliar
codebase — regardless of which skill is active.

## The six rules

1. **Never re-read a file you already read this session.** It is still in context.
   Re-read only after you edited it, a command changed it, or the user says it changed.
   Before any read, ask: *have I already seen this file in this conversation?*
2. **Read a line range, never a whole file**, unless the file is under ~100 lines.
3. **Batch edits.** Multiple edits to one file, or across files, go in one call.
4. **"Where is this symbol used?" → `CAP:USAGES`**, not grep-then-read-five-files.
5. **Delegate heavy investigation** to `CAP:SUBAGENT`: log triage, test-suite triage,
   surveying an unfamiliar package, any search touching more than ~5 files. Keep only
   the conclusion.
6. **Filter output at the source** — `| tail -50`, `--quiet`, `-o`. Never pipe a
   5,000-line build log into context and then read past it.

## Why these specifically

Measured over 90 days with `agent-tools/token-report.py`, against the original baseline
(`AUDIT-LOG.md` B24):

| Metric | Baseline | Now |
|---|---|---|
| Whole-file reads | 52% | **12.9%** |
| Re-reads of a file already in context | 53% | **39.4%** |
| Delegation (sub-agent vs direct calls) | 6% | **3%** |

Rule 2 worked — whole-file reads fell by 39 points. Rule 1 moved 14 points and is still
the largest single waste: **330 of 837 reads were repeats.** Rule 5 regressed.

Note that re-reading is *cached*, so it is cheap in tokens but still costs a round trip
and crowds the window. The expensive mistake is pulling in large **new** content without
filtering — see [`../_shared/tool-economics.md`](../_shared/tool-economics.md).

## Prefer a reference over a paste

- If the user pastes a log, stack trace, or coverage table, do not ask for more inline.
  Ask for the path, or re-run the command and read the result.
- Cite evidence as `path/file.go:120`, not as a quoted block, unless the exact text is
  the thing under discussion.
- After an edit tool reports success, the file is what you just wrote. Do not read it
  back to confirm.

## Delegation discipline

- A sub-agent returns findings and `file:line` evidence. It must **not** return raw log
  or test output.
- Sub-agents do not inherit these rules. Restate the secrets prohibition in every
  delegation prompt.
- Run independent read-only lookups in the same turn rather than one per turn.

## Long workflows

Any workflow expected to exceed ~30 turns should checkpoint: summarize decisions made
and files touched, then continue from the summary rather than the full history.

**Do not restart the session to clear context.** 94% of input tokens are cache reads, so
continuing is cheap and restarting pays cache writes plus a full re-read
(`AUDIT-LOG.md` B23). Checkpoint in place.

## Reuse instead of regenerating

**Check [`../agent-tools/README.md`](../agent-tools/README.md) before deriving anything
the hard way.** It indexes committed scripts for repository facts, test runs with
baseline comparison, PR context, and outcome logging — one call each, instead of
rediscovering the same facts every session.

If you are about to produce the same logic a second time — a validation pass, a count, a
mechanical edit across files — write it to a script, commit it there, and invoke it by
path. A committed script costs one line of context per run; regenerated logic costs its
full length every time (`AUDIT-LOG.md` B26).

See [`../_shared/tool-economics.md`](../_shared/tool-economics.md) for the measured
evidence and the batch-edit pattern.

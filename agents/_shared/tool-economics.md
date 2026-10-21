# Tool economics

Which tool to reach for, and why, measured over 90 days of real sessions. Complements
[`../rules/context-discipline.md`](../rules/context-discipline.md), which covers reading
and delegation; this file covers **tool selection and the cost model**.

Regenerate the numbers any time with `python3 agent-tools/token-report.py`.

## Contents

- [The cost model](#the-cost-model)
- [Script over regeneration](#script-over-regeneration)
- [Batch over sequential](#batch-over-sequential)
- [Filter at the source](#filter-at-the-source)
- [Tool selection table](#tool-selection-table)
- [MCP server hygiene](#mcp-server-hygiene)

---

## The cost model

**94% of input tokens are cache reads** (1.06B of input, 988M cached). A cache read bills
at roughly a tenth of fresh input, so raw volume is a poor proxy for cost
(`AUDIT-LOG.md` B23).

What this means in practice:

| Cheap | Expensive |
|---|---|
| Continuing a long session | Starting a fresh session |
| Appending to context | Rewriting earlier context |
| Re-reading a file already in context (wasteful, but cached) | Pulling in a large *new* file |
| A long conversation | The same work split across five conversations |

So: **do not restart a session to "clear context".** A restart pays cache writes and
re-reads everything from scratch. Checkpoint instead — summarize decisions and files
touched, and continue.

The expensive operations are the ones that put *new* bytes in front of the model: a large
unfiltered command output, a whole file read for one function, a tool result nobody
filtered.

## Script over regeneration

**A script written once and invoked many times costs one line of context per run.** The
same logic regenerated inline costs its full length every time.

The bundle's own scripts live in [`../agent-tools/`](../agent-tools/README.md) — repo
facts, test runs with baseline comparison, PR context, outcome logging, spec validation,
token measurement. **Check that index before deriving anything the hard way.**

Observed: `agent-tools/validate.py` was written once and invoked 7 times across sessions
(`AUDIT-LOG.md` B26).

Write a script when:

- The same logic is about to be produced a second time.
- The operation is mechanical and verifiable — validation, counting, reformatting, bulk edits.
- A future session will want the same answer (`agent-tools/token-report.py` exists for exactly this).

Keep it in `tools/` or `scripts/`, commit it, and invoke it by path. Per `SPEC.md` §4,
`scripts/` are executed without being read into context — that is the whole point.

## Batch over sequential

One call that performs many edits beats many calls that perform one each. Measured: 19
heredoc batches, one of which rewrote the version and changelog of five skills in a
single call.

```sh
python3 - <<'PY'
import pathlib, re
for p in pathlib.Path('skills').glob('*/SKILL.md'):
    t = p.read_text()
    # mechanical, repetitive edit across many files
    p.write_text(re.sub(r'old', 'new', t))
PY
```

Use this for mechanical multi-file edits. Use the editor's own batch facility
(`CAP:EDIT` with multiple edits in one call) for a handful of targeted changes where
precision matters more than volume.

**Do not** use a script for a change that needs judgement per site. Read those and edit
them deliberately.

## Filter at the source

Already habitual — `head`/`tail` appeared 70 times in the measured window — but the
principle generalizes beyond those two:

| Instead of | Use |
|---|---|
| reading a whole log | `tail -50`, `grep -C3 'error'` |
| dumping JSON to read one field | `jq -r '.field'` |
| listing every match | `rg -l` (files only), `rg -c` (counts) |
| full test output | the runner's `--quiet` or JSON reporter |
| `git log` paged | `git --no-pager log --oneline -20` |

`jq` was used once and `rg` twice in 90 days, despite both being well suited to work that
was instead done by reading raw output into context. They are the two most underused
tools available.

## Tool selection table

| Need | Reach for | Not |
|---|---|---|
| Where is this symbol used | `CAP:USAGES` | grep then read five files |
| Does this compile / type-check | `CAP:DIAGNOSTICS` | a full build |
| One field from JSON | `jq -r` | reading the document |
| Which files match | `rg -l` | `rg` with full output |
| Rename a symbol | the editor's rename refactor | find-and-replace |
| Survey an unfamiliar repo | `CAP:SUBAGENT`, keep the conclusion | reading it yourself |
| Repeat an analysis | a committed script | regenerating the logic |
| GitHub data | the `gh` CLI | the GitHub MCP server |

## MCP server hygiene

Every registered server's tool names are listed in every session, whether or not the
server is used. Duplicate registrations are therefore a permanent, silent tax.

Currently duplicated (`AUDIT-LOG.md` B25):

| Server | Registered as | Status |
|---|---|---|
| Azure DevOps | `Azure-DevOps-MCP-Server-*` | works (4/4) |
| Azure DevOps | `microsoft-azure-devops-mcp-*` | **fails every call (0/9)** |
| GitHub | `github-mcp-server-*` + `io-github-github-github-mcp-server-*` | overlapping |

Deregister the duplicate that does not work, and prefer the `gh` CLI over the GitHub MCP
server entirely. Check the registrations in the editor's MCP configuration; this is user
configuration, not something a skill can fix.

When a server is genuinely needed only occasionally, leaving it disabled and enabling it
for the task is cheaper than carrying its tool list in every session.

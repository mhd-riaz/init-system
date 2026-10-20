# agent-tools

Scripts the agent runs **instead of rediscovering the same facts every session**.

Read this index, not the scripts. Each one is executed, never read into context — that
is the point (`SPEC.md` §4). Every script is read-only unless stated, and none of them
read `.env` or any credential file.

## When to reach for these

| You need | Run | Instead of |
|---|---|---|
| repo root, remote, host, branch, tracker, config, stack | `repo-facts.sh` | 6-8 separate git calls |
| test results per package, with the abort-early fallback | `test-run.sh` | improvising the fallback |
| proof a failure is pre-existing | `test-run.sh --baseline` then `--compare` | asserting it |
| PR metadata, files, checks, threads | `pr-context.sh <pr>` | several API calls |
| to record a skill outcome | `outcome-log.sh ...` | writing to an unverified path |
| to check skills against the spec | `validate.py` | re-reading `SPEC.md` |
| token/cache/re-read measurements | `token-report.py` | guessing |
| to install the bundle into a provider | `install.sh` | copying by hand |
| to check the scripts still work | `selftest.sh` | finding out in a real session |

---

## repo-facts.sh

```sh
agent-tools/repo-facts.sh [path]
```

Key=value lines: `repo_root`, `repo_name`, `remote`, `code_host`, `repo_slug`, `branch`,
`default_branch`, `ab_prefix_commits`, `agent_config`, `tracker_configured` or
`tracker_detected`, `uncommitted_files`, `last_commit`, `devlog`, `stack_marker`,
`instructions`.

**Resolves the tracker correctly.** The code host is not the tracker: an `AB#` prefix in
recent commits means work items live in Azure DevOps even when the remote is GitHub
(`AUDIT-LOG.md` B21). Verified on a real repo — GitHub remote, `tracker_detected=ado`.

Run it once at the start of repository work and reuse the output.

## test-run.sh

```sh
agent-tools/test-run.sh                      # detect stack, run, per-package table
agent-tools/test-run.sh --baseline           # record a clean-tree baseline
agent-tools/test-run.sh --compare            # run, then compare failure identities
agent-tools/test-run.sh -- go test ./... -json
```

Reads `testing.command` from `.agent/config.yml` when present (`baseline_command` for
`--baseline`, `per_package_command` for the abort-early re-run), otherwise detects Go,
Node, Python or Rust. Two behaviours that past sessions had to improvise:

- **Abort-early fallback** — if a project wrapper stops at the first failing package, it
  re-runs through the native runner's machine-readable output to produce the full table
  (`AUDIT-LOG.md` B14).
- **Baseline comparison** — `--compare` matches **failure identities**
  (`package::Test`, `test::file::case`), not summary text, so an added passing package
  is not reported as a new failure and a swapped failing test is not missed
  (`AUDIT-LOG.md` B15, B33). The baseline records the command, scope and revision it was
  taken with, and `--compare` warns when they differ.

It reports failures, not coverage. **Coverage is not measured here** — collect it with
the runner's own coverage flag, or report it as unmeasured.

Runs in the **current** directory, not the repo root, so modules in a subdirectory work.
Handles Go's cached runs, which emit package-level results with no per-test events.

## pr-context.sh

```sh
agent-tools/pr-context.sh <pr-url-or-number> [--files] [--threads] [--diff] [--all]
```

Detects GitHub vs Azure DevOps from the URL, or from `origin` when given a bare number.
Prints metadata, CI checks, and the changed-file list ranked by churn. `--threads` adds
review threads with **resolution state and replies** (GraphQL), plus conversation
comments — pass every one through
[`../_shared/evidence-filter.md`](../_shared/evidence-filter.md) before acting on it.

**It never returns file contents, and it labels every capped or failed section
`PARTIAL:` / `UNAVAILABLE:` with the command that completes it** (`AUDIT-LOG.md` B34).
Treat those labels as outstanding work; an exhaustive request is not met by a shortened
list.

Prefers the `gh` CLI, which is faster than the GitHub MCP server and uses existing
credentials.

## outcome-log.sh

```sh
agent-tools/outcome-log.sh <skill> <version> <outcome> "<correction>" "<evidence>" \
    [--global] [--session ID]
```

Appends one record to `.agent/skill-outcomes.md`, or to `~/.agent/state/` with
`--global`. **Verifies the directory is writable and fails loudly when it is not** — the
previous generation wrote to a path that did not exist outside one editor, and every
record was silently lost (`AUDIT-LOG.md` B10).

`outcome` is one of `success`, `corrected`, `abandoned`, `error`.

## validate.py

```sh
python3 agent-tools/validate.py          # must print "0 non-compliant"
```

Checks frontmatter keys (strictly, with or without PyYAML), the 600-character
description cap, both `USE FOR` / `DO NOT USE FOR` boundaries, name/folder agreement,
required headings and their order, the 500-line body budget, every non-portable pattern,
that relative links resolve on disk, and that every `CAP:` identifier is defined
(`AUDIT-LOG.md` B40).

Structural only — a compliant bundle is not a working one.

## token-report.py

```sh
python3 agent-tools/token-report.py [--days N]
```

Cache hit rate, effective versus raw token cost, most expensive sessions, re-read ratio.
Re-measure after changing habits rather than re-arguing.

## install.sh

```sh
agent-tools/install.sh --dry-run
agent-tools/install.sh [--providers claude,codex] [--mode copy] [--force]
```

Symlinks or copies the bundle into each provider. Non-destructive: existing files are
skipped unless `--force`, which backs them up first.

Skills go to each provider's skills directory — Codex's is `$HOME/.agents/skills`, not
`$CODEX_HOME/skills`. `rules/` is **inlined** into the single always-on entry point each
provider actually reads (`CLAUDE.md`, `AGENTS.md`, `copilot-instructions.md`, a VS Code
user `*.instructions.md`); a directory of plain rule files is read by none of them
(`AUDIT-LOG.md` B29). Copy mode also copies `_shared/`, `templates/`, `rules/` and
`agent-tools/` beside the skills directory, without which every `../../_shared/...`
reference in a copied skill resolves to nothing (B30).

## selftest.sh

```sh
agent-tools/selftest.sh          # prints one line per assertion; non-zero on failure
```

Covers the seams that previously failed silently: the `.agent/config.yml` command reader,
baseline comparison by failure identity, the validator's link and capability checks, and
copy-mode layout. Runs in a temp directory and touches no provider directory. Run it
after editing any script here.

---

## Adding a script here

Add one when the same logic is about to be produced a second time, the operation is
mechanical and verifiable, or a future session will want the same answer.

Requirements:

1. **Run it before committing it.** An untested script is worse than none.
2. No secret-file access, ever.
3. Degrade with a message on stderr and a non-zero exit; never fail silently.
4. Keep output compact — this is read into context.
5. Add a row to the table above. An unlisted script will not be found.

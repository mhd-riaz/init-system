# Index — agents

Map of this bundle. Plain `.md`, never a `SKILL.md`, so no agent auto-discovers it and
it costs nothing until opened. Read this first when orienting. Do not bulk-read skills.

## Skills (13) — descriptions load every session

| Skill | Owns |
|---|---|
| `write-code` | the implementation workflow; design approval precedes any code |
| `write-tests` | scenario suites, mocks, coverage; runs straight after `write-code` |
| `pr-review` | reviewing a PR — correctness, coverage, security, standards |
| `resolve-pr` | acting on reviewer comments, evidence-filtered |
| `pr-description` | the PR body from the diff, to a fixed template |
| `ado-item` | Azure DevOps Bug / User Story / Task to a fixed standard |
| `gh-issue` | GitHub issues, labels, assignment, sub-issues |
| `devlog` | `docs/devlog/` entries in any repo |
| `engineering-os` | router into the on-demand engineering rule library |
| `doc-lookup` | current library docs instead of model recall |
| `study-notes` | academic coursework material (not engineering docs) |
| `skill-creator` | writes and validates new skills against `SPEC.md` |
| `skill-retrospective` | mines outcome logs to propose skill changes |

Routing boundaries live in each skill's `USE FOR` / `DO NOT USE FOR` and its
`## Related skills` table. **If two skills feel like they overlap, that is a bug** —
see `AUDIT-LOG.md` B7.

## Rules — always on, loaded every session

| File | Enforces |
|---|---|
| `rules/no-secret-files.md` | never read `.env` or any credential file, by any means |
| `rules/context-discipline.md` | read once, range reads, batch edits, delegate heavy work |
| `rules/evidence-first.md` | claims about code come from the code, with `file:line` |
| `rules/doc-lookup.md` | library questions are answered from fetched docs |
| `rules/paths.md` | how `{{STATE_REPO}}` / `{{STATE_GLOBAL}}` / `{{SKILLS_DIR}}` resolve |
| `rules/repo-config.md` | read `.agent/config.yml` first; honour `skills.disabled` |

## Shared procedures — on demand, referenced never copied

| File | Used by |
|---|---|
| `_shared/capabilities.md` | every skill — the `CAP:` vocabulary and degradation chains |
| `_shared/repo-config.md` | the `.agent/config.yml` schema — tracker, host, identity, conventions |
| `_shared/tool-economics.md` | which tool to reach for, the cache cost model, MCP hygiene |
| `_shared/outcome-log.md` | every skill — the completion-record schema |
| `_shared/approval-gate.md` | `write-code`, `write-tests`, `pr-review`, `resolve-pr`, `ado-item`, `gh-issue`, `skill-retrospective` |
| `_shared/evidence-filter.md` | `pr-review`, `resolve-pr`, `skill-retrospective` |
| `_shared/test-and-coverage.md` | `write-code`, `write-tests`, `pr-review`, `resolve-pr` |
| `_shared/security-review.md` | `write-code`, `pr-review` |
| `_shared/definition-of-done.md` | `write-code`, `ado-item`, `gh-issue`, `pr-description` |
| `_shared/pr-fetch.md` | `pr-review`, `resolve-pr`, `pr-description` |
| `_shared/work-item-context.md` | `ado-item`, `gh-issue`, `write-code`, `pr-description`, `devlog` |

## Supporting files

| Path | What it is |
|---|---|
| `SPEC.md` | the authoring contract — frontmatter, 600-char cap, required sections, versioning |
| `AUDIT-LOG.md` | findings `B1`-`B45`; changelog entries cite these IDs |
| `agent-tools/README.md` | **index of runnable scripts — read this before deriving facts by hand** |
| `agent-tools/repo-facts.sh` | repo root, remote, host, branch, tracker, config, stack in one call |
| `agent-tools/test-run.sh` | test run with per-package table, abort-early fallback, baseline compare |
| `agent-tools/pr-context.sh` | PR metadata, checks, files, threads in one call |
| `agent-tools/outcome-log.sh` | append an outcome record to a verified-writable path |
| `agent-tools/validate.py` | spec enforcement; must print `0 non-compliant` |
| `agent-tools/token-report.py` | cache hit rate, uncached cost, re-read ratio; re-run to re-measure |
| `agent-tools/install.sh` | symlink or copy into each provider; non-destructive by default |
| `install.sh` | interactive front end for the above — OS detection, provider checklist, keep-or-replace |
| `agent-tools/selftest.sh` | regression check for the installer, config reader, baseline compare and validator |
| `templates/SKILL.template.md` | starting point for a new skill |
| `templates/agent-config.template.yml` | starting point for a repo's `.agent/config.yml` |

A leading `_` prevents auto-discovery. That is how a skill is retired: move it to
`_archive/`, do not delete it.

## Before committing any change

```sh
python3 agent-tools/validate.py          # must print "0 non-compliant"
```

Then bump `metadata.version` per `SPEC.md` §7 and add a changelog entry citing the
evidence or the `AUDIT-LOG.md` finding ID that justified it. Never bump with an
unattributed rewording.

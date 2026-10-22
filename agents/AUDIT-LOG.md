# Audit log

Dated findings that justify design decisions in this bundle. Changelog entries cite
these IDs; this file is what makes a citation resolvable. Never rewrite an entry —
append a correction instead.

---

## B1 — Descriptions are the dominant recurring cost (2026-08-25, inherited)

Measured across 185 recorded sessions: skill descriptions cost **2,512 tokens per
session** before the user typed anything, because every description loads whether or not
its skill is used. Bodies cost nothing until triggered.

**Decision:** 600-character hard cap on descriptions (`SPEC.md` §2), enforced by
`agent-tools/validate.py`. OpenAI's validator permits 1024; this bundle is deliberately
stricter.

---

## B2 — The `USE FOR` grep trap (2026-07-28, inherited)

A naive search for `USE FOR:` also matches inside `DO NOT USE FOR:`. A compliance check
built on it reported every skill as passing while three had **no positive triggers at
all**.

**Decision:** the positive-only form `grep -LE '(^|[^T] )USE FOR:'` is documented in
`SPEC.md` §9 and implemented in `validate.py`. Any new checker must avoid re-introducing it.

---

## B3 — An unenforced spec drifts (2026-07-28, inherited)

A prior spec permitted "`## Purpose` or an equivalent intro paragraph". Four skills
drifted to `## What this is` or bare prose, making the spec uncheckable by any automated
means.

**Decision:** exact headings, no equivalents, verified programmatically. A convention
that cannot be checked is a suggestion.

---

## B4 — Triggers in the body can never fire (2026-10-20)

`~/.claude/skills/context7-mcp/SKILL.md` contained a `## When to Use This Skill`
section. The body loads only **after** the skill triggers, so that section could never
influence triggering — pure token cost with zero effect.

**Decision:** `SPEC.md` §2 requires all trigger information in the description and
mandates deleting such sections from bodies.

---

## B5 — Provider coupling breaks portability (2026-10-20)

A survey of 10 pre-existing skills found hardcoded, provider-specific references in
every one: `mcp_azure_devops2_*` tool names, `run_vscode_command`, `runSubagent`,
`/memories/...` absolute paths, and a pinned model string `"Claude Sonnet 5.5
(copilot)"`. None survive a move to a different agent.

**Decision:** the `CAP:` vocabulary in `_shared/capabilities.md` with per-capability
degradation chains; `TIER:` instead of model names; `{{STATE_*}}` placeholders instead of
absolute paths. `validate.py` rejects all of the above patterns.

---

## B6 — A frontmatter key that fails elsewhere (2026-10-20)

Pre-existing skills used a top-level `version:` key. OpenAI Codex's validator permits
only `{name, description, license, allowed-tools, metadata}` and rejects anything else
outright, so **every** such skill fails to install there.

**Decision:** version lives at `metadata.version`. The five-key intersection is the only
permitted frontmatter.

---

## B7 — The same procedure duplicated across ten skills (2026-10-20)

Analysis of 10 skills found outcome logging duplicated near-verbatim in **all ten**,
approval-gate policy in six, evidence-first discipline in seven, tool-availability
preambles in five, and coverage thresholds in four. Each copy was a separate place to
drift.

**Decision:** extracted to `_shared/` (`outcome-log.md`, `approval-gate.md`,
`evidence-filter.md`, `test-and-coverage.md`, `security-review.md`, `pr-fetch.md`,
`work-item-context.md`) and `rules/`. `SPEC.md` §4 forbids restating shared content;
skills link to it.

---

## B8 — Routers that ask instead of deciding (2026-10-20)

Microsoft's `deploy-model` skill names a default for every ambiguous route
("if unsure, default to Preset") and gives each routing rule a stated **Reason**, which
lets the agent generalize to phrasings absent from the table. Most routers do neither
and resolve ambiguity by interrogating the user.

**Decision:** `SPEC.md` §6 requires every router to carry a Reason column and name a
default for ambiguity.

---

## B9 — Refusals without alternatives get worked around (2026-10-20)

`~/.claude/rules/no-env-files.md` pairs each prohibition with its reason ("a grep hit
prints the line, and the line is the secret"), covers explicit and implicit violations
separately, pre-refutes the rationalizations, and supplies a priority-ordered list of
what to do instead.

**Decision:** adopted as the four-part prohibition pattern in `SPEC.md` §6 and applied in
`rules/no-secret-files.md`.

---

## B10 — `/memories/` is unreachable outside VS Code (2026-10-20, CRITICAL)

Every pre-existing skill mandated appending a record to `/memories/repo/skill-outcomes.md`
or `/memories/skill-outcomes-global.md`. That path does not exist on this machine, and a
session note states it plainly:

> "`/memories/...` is a VS Code virtual path with no tool in the Copilot CLI session, so
> the records could not be appended to the real logs."
> — `session-state/8b8f9df1.../files/skill-outcomes-px01.md`

**Consequence:** the outcome log was never written outside VS Code, so
`skill-retrospective` had nothing to mine. The entire feedback loop was silently dead.
The same path broke `devlog-cache.md`, so devlog re-ran discovery on every single
invocation instead of using its cache.

**Decision:** `{{STATE_*}}` placeholders resolve to real on-disk paths
(`rules/paths.md`), and both `_shared/outcome-log.md` and
`_shared/work-item-context.md` now require verifying the directory is writable and
degrade visibly when it is not. A silent write failure is forbidden.

---

## B11 — Duplicate MCP server registrations, one of which always fails (2026-10-20, HIGH)

Session telemetry, last 90 days:

| Tool | Result |
| --- | --- |
| `microsoft-azure-devops-mcp-wit_work_item` | **0 / 9 succeeded** |
| `Azure-DevOps-MCP-Server-wit_work_item` | **4 / 4 succeeded** |

The same logical tool is registered twice; one registration fails 100% of the time. The
agent discovered this at runtime — *"The ADO MCP server hit the known path error — trying
the alternate server instance."* — and had to rediscover it in later sessions.

**Decision:** `_shared/capabilities.md` instructs trying the alternate registration
immediately on error rather than treating the first failure as capability-unavailable.

---

## B12 — Pinning a model string fails on incompatible settings (2026-10-20, MEDIUM)

> "the pinned model `claude-haiku-4.5` was rejected (*Reasoning effort 'low' is not
> supported for model 'claude-haiku-4.5'*); retried on the default explore model."

A pinned model couples a skill to one provider's catalogue *and* to that model's
parameter support.

**Decision:** `TIER:` only, never a product string (already `SPEC.md` §8). Reinforced in
`_shared/capabilities.md`: on rejection, retry on the provider default rather than
failing the delegation.

---

## B13 — `git pull` breaks after the upstream branch is deleted (2026-10-20, MEDIUM)

> "Step 0 `git pull` fails when the branch's upstream was deleted after its PR merged;
> fell back to `git fetch --prune` and compared HEAD with the real base branch."

**Decision:** `write-code` Step 2 specifies `git fetch --prune` plus comparison against
the resolved base branch, not `git pull`.

---

## B14 — A failing test script hides the full picture (2026-10-20, MEDIUM)

> "`bash unit-test.sh` aborts at the first failing package, so the per-package table came
> from `go test ./... -json`."

A wrapper script that exits on first failure cannot produce a per-package summary.

**Decision:** `_shared/test-and-coverage.md` requires falling back to the native runner's
machine-readable output when the project wrapper aborts early.

---

## B15 — Baseline comparison is what makes "pre-existing" provable (2026-10-20)

Two successful runs used the same technique: *"the four failing packages match the
clean-tree baseline"* and *"lint.sh 22 findings identical to a clean tree"*.

**Decision:** promoted from incidental good practice to required procedure in
`_shared/test-and-coverage.md`. Without a baseline, "pre-existing failure" is an
assertion; with one, it is evidence.

---

## B16 — A test is only real if it fails when the behaviour breaks (2026-10-20)

> "Proved with a before/after mutation run: panic, then 4 clean failures."

**Decision:** `write-tests` requires proving a new test fails against broken behaviour
before reporting it as coverage.

---

## B17 — Project conventions outrank skill defaults (2026-10-20, MEDIUM)

> "The go-echo-tests prompt ('fewer meaningful cases', no forced scale scenarios)
> overrides the skill's 'cover every scenario type', so scale scenarios were omitted with
> a stated reason."

The skill and the repository disagreed, and the agent resolved it correctly but had no
rule authorising it.

**Decision:** explicit precedence in `_shared/test-and-coverage.md` — repository
conventions win; the override must be stated with its reason, never silently applied.

---

## B18 — A definition of done the user asked to be persisted (2026-10-20, HIGH)

Verbatim from session `ea2e8cbf`, turn 31, followed by *"feel free to put these
informations somewhere"*:

> "before closing any task or story, check the following constraints — pr created for
> each; pr has unit testcases for each new functionality; does not break any old
> testcases; uses the `AB#<ADO_ID> -` prefix with stories id while commiting; has pr
> reviewed by copilot in github; has a comment before closing tasks describing what was
> delivered"

The request to persist it was never actioned, so it had to be restated.

**Decision:** captured verbatim in `_shared/definition-of-done.md`, referenced by
`write-code`, `ado-item`, `gh-issue` and `pr-description`.

---

## B19 — Task sizing convention (2026-10-20)

> "each task should be sized such that it can be completed within half day with code
> review, and test cases"

Applied in practice as 19 tasks of ≤4h each, including review and tests.

**Decision:** recorded in `_shared/definition-of-done.md` and applied by `ado-item` and
`gh-issue` when breaking down a story.

---

## B20 — Skill attribution makes routing debuggable (2026-10-20)

One session reported: *"**Skills used:** `engineering-os` → loaded milestone-planning.md
(R1 …). Matched-but-not-run: `write-code`"*.

Naming both the skills that fired **and** the ones that matched without running is what
makes a mis-route visible instead of invisible.

**Decision:** `SPEC.md` §6 recommends it for routers; `engineering-os` adopts it.

---

## B21 — Code host and work tracker are different systems (2026-10-20, HIGH)

`_shared/work-item-context.md` v1 detected the tracker from the git remote:
`github.com` → `gh-issue`, `dev.azure.com` → `ado-item`. Verified against the real repo
landscape, that is **wrong for every work repository**:

```
origin   https://github.com/<company>/dummy-server.git
commits  AB#3204284 - PX-02 xMatters sender
items    dev.azure.com/<company>/Bridge/_workitems/edit/123123
```

Code is hosted on GitHub; work items live in Azure DevOps; `AB#id` is Azure Boards'
GitHub integration syntax linking the two. Remote-based detection would have filed a
GitHub issue for work tracked in ADO.

Personal repositories differ again — `watermarks-remover`, `mxdio-web` and `vscode` are
GitHub-only, and `security-champ` has no remote at all.

**Decision:** a per-repo `.agent/config.yml` is the primary source for tracker, code
host, identity and conventions; git-remote detection is demoted to a fallback used only
when no config file exists. Introduced `rules/repo-config.md` (always on) and
`_shared/repo-config.md` (the schema).

---

## B22 — A repo config cannot gate skill loading (2026-10-20)

A natural assumption is that per-repo configuration can stop irrelevant skills from
loading. It cannot: descriptions for every installed skill are loaded into every session
before any repository file is read (`SPEC.md` §4). Carrying `ado-item` in a personal
repository costs 485 characters (~121 tokens).

**Decision:** config *configures and short-circuits*, it does not *select*. A skill
listed in `skills.disabled` still loads and may still trigger, but declines in one line
and stops. The value of the config is correct routing, not token savings.

---

## B23 — Caching, not raw volume, determines cost (2026-10-20)

Measured over 90 days (`agent-tools/token-report.py`, cross-checked against the cloud session
store): **1.06B input tokens, of which 988M were cache reads — a 94% hit rate.** Billed
at roughly a tenth of fresh input, that 1.06B behaves like ~180M.

| Model | Input | Cached | Hit |
| --- | --- | --- | --- |
| claude-sonnet-5 | 472.9M | 446.4M | 94.4% |
| claude-opus-5 | 295.9M | 273.7M | 92.5% |
| claude-haiku-4.5 | 84.7M | 78.0M | 92.1% |

**Consequence:** a long session is cheap per turn; a *new* session is expensive because
it pays cache writes (opus-5 wrote 4.1M cache tokens) and re-reads everything. Optimising
for "shorter context" by restarting sessions is backwards.

**Decision:** `_shared/tool-economics.md` states the cache-aware strategy — continue a
session, append rather than rewrite, and checkpoint instead of restarting.

---

## B24 — Rules measurably changed behaviour (2026-10-20)

Comparing the baseline recorded in `rules/context-discipline.md` against the last 90 days:

| Metric | Baseline | Now | Change |
| --- | --- | --- | --- |
| Whole-file reads | 52% | **12.9%** | ▼ 39 pts |
| Re-read rate | 53% | **39.4%** | ▼ 14 pts |
| Delegation | 6% | **3%** (13 `task` vs 435 `bash`) | ▼ |

Range-reading improved dramatically; re-reading improved modestly; delegation regressed.

**Decision:** numbers refreshed in `rules/context-discipline.md` so the rule cites
current evidence rather than a stale baseline. The re-read rule gains a concrete test,
since "read once" alone moved the number only 14 points.

---

## B25 — Duplicate MCP registrations cost tokens and correctness (2026-10-20, HIGH)

The same servers are registered twice under different prefixes:

| Server | Registrations | Tools each |
| --- | --- | --- |
| Azure DevOps | `Azure-DevOps-MCP-Server-*` **and** `microsoft-azure-devops-mcp-*` | 40 |
| GitHub | `github-mcp-server-*` **and** `io-github-github-github-mcp-server-*` | 18 / 48 |

Roughly **58 duplicate tool names are listed in every session**, and one Azure DevOps
registration fails every call (`AUDIT-LOG.md` B11: 0/9 versus 4/4).

**Decision:** recorded in `_shared/tool-economics.md` as a configuration fix — deregister
the duplicate, keep the one that works. This is user configuration, not a bundle change.

---

## B26 — A committed script beats regenerated code (2026-10-20)

Observed in the bash history: `agent-tools/validate.py` was written once and invoked 7 times
across sessions, each invocation costing one line of context instead of regenerating the
logic. Separately, `python3 - <<'PY'` heredocs performed 19 batch operations — one call
rewrote the version and changelog of five skills at once.

By contrast `jq` appeared once and `rg` twice, despite both being well suited to the
filtering work that was instead done by reading output into context.

**Decision:** `_shared/tool-economics.md` codifies script-over-regeneration and
batch-over-sequential, with the measured evidence.

---

## B27 — Rediscovery is the repeatable waste (2026-10-20)

Across sessions the same facts were re-derived from scratch every time: the git remote,
the code host, the default branch, whether commits carry a tracker prefix, where the
devlog lives, which test command the project uses. Each cost several tool calls and
produced output that was read into context and then discarded.

**Decision:** `agent-tools/` holds committed, tested scripts that return those facts in
one call, indexed in `agent-tools/README.md` so the index is read rather than the
scripts. Measured replacement: `repo-facts.sh` returns 15 facts in one call, versus six
to eight separate git invocations.

Three rules now point at the index — `rules/context-discipline.md`,
`_shared/tool-economics.md`, and `_shared/work-item-context.md` — because a tool nobody
finds is a tool nobody uses.

---

## B28 — Scripts must be run against real data before being trusted (2026-10-20)

`test-run.sh` passed a synthetic check and still had two defects that only real data
exposed:

1. It forced `cd` to the git root, which broke a Go module living in a repository
   subdirectory — the package pattern resolved against the wrong directory and every
   package reported `fail`.
2. Its parser counted only per-test events, so a **cached** Go run — which emits
   package-level results with no per-test events — produced an empty table.

Both were silent: plausible-looking output, wrong content.

**Decision:** `SPEC.md` §10 already required executing a script before committing it.
`agent-tools/README.md` restates it, because the failure mode here was not a crash but a
confident empty answer.

---

## B29 — The installer wrote to paths no provider reads (2026-10-20, HIGH)

Verified against current provider documentation:

| What the installer did | What the provider actually reads |
| --- | --- |
| skills → `~/.codex/skills` | `$HOME/.agents/skills` (Codex USER scope) |
| rules → `~/.copilot/rules/*.md` | `$HOME/.copilot/copilot-instructions.md` |
| rules → `~/.claude/rules/*.md` | `$HOME/.claude/CLAUDE.md` |
| nothing for VS Code | `<profile>/User/prompts/*.instructions.md` |

Sources: [Codex skill locations](https://developers.openai.com/codex/skills) (USER =
`$HOME/.agents/skills`), [Copilot CLI custom
instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions).
Installation reported success while the always-on rules governing secrets, context
discipline, evidence and repo config were never loaded by any provider.

**Decision:** `install_rules` deleted. `generate_instructions` writes the one entry point
each provider discovers, with the rules inlined; Codex skills default to
`$HOME/.agents/skills` (`CODEX_SKILLS_DIR` overrides).

---

## B30 — Copy mode broke every shared-procedure reference (2026-10-20, HIGH)

Skills reference `../../_shared/...` — 101 references across 13 skills. Under symlink
mode the kernel resolves `..` against the real bundle, so they hold. Copy mode copied
only `skills/` and `rules/`, so every one of those paths pointed at nothing: a copied
skill advertised an approval gate, a testing procedure or a context ladder that could
not be read.

**Decision:** `install_skills` copies `_shared/`, `templates/`, `rules/` and
`agent-tools/` beside the skills directory when `--mode copy` is used. Verified by
installing to a temp directory and resolving
`skills/write-code/../../_shared/approval-gate.md`.

---

## B31 — Skills undid the tracker/code-host distinction they inherited (2026-10-20, HIGH)

`_shared/work-item-context.md` separates tracker from code host correctly (B21), but two
skills routed on the git remote anyway:

- `ado-item` Step 1: *"If the git remote is not an Azure DevOps host, stop and hand off
  to `gh-issue`."*
- `pr-description` Step 1: *"Platform detection … Azure DevOps or GitHub, from the
  `origin` remote."*

For the normal work configuration — `tracker.system: ado`, `code_host.system: github` —
"create an ADO task" would be refused and handed to `gh-issue`, and a PR body would emit
`Closes #123` against a GitHub issue number that does not exist while the real item sits
in Azure Boards.

**Decision:** work-item operations and references read `tracker.system`; only PR and API
calls read `code_host`. The remote-based shortcuts are removed from both skills.

**Correction, same day:** grepping the siblings found the mirror-image defect in
`gh-issue` — *"If the remote is an Azure DevOps host, stop and hand off to `ado-item`"*.
It is the worse direction: a GitHub remote tracking work in Azure DevOps does not trip
that condition, so `gh-issue` would file a GitHub issue for ADO-tracked work, which is
the exact failure B21 was raised to prevent. Fixed the same way. Three skills, not two.

---

## B32 — The configured test command was parsed into a malformed shell command (2026-10-20, HIGH)

`test-run.sh` read `testing.command` with:

```sh
cmd=$(grep -A4 '^testing:' .agent/config.yml 2>/dev/null \
      0 | sed 's/.*command:[[:space:]]*//' | tr -d '"'"'"'')
```

Two defects: a stray `0` that `grep` takes as a second filename, and `-A4`, which also
captures the `testing:` heading and the sibling `per_package_command` /
`baseline_command` lines. Reproduced on a config declaring `command: pytest -q`: the
extracted value contained the heading line and the command. `per_package_command` and
`baseline_command` were never read at all despite being in the schema.

**Decision:** replaced with an exact block-scoped reader (`cfg <key>`), which now also
supplies `baseline_command` for `--baseline` and `per_package_command` for the
abort-early re-run. Verified: the same config yields exactly `pytest -q`.

---

## B33 — Baseline comparison could not identify a new failure (2026-10-20, HIGH)

`--compare` ran `diff baseline summary | grep '^>'` over **summary text**, so:

- a newly added *passing* package printed as a `NEW failure` (false positive);
- a different test failing with the package counts unchanged printed nothing (false
  negative).

Both reproduced against fixture runs.

**Decision:** the baseline stores **failure identities** (`package::Test`,
`test::file::case`) plus the command, scope and revision it was recorded with.
`--compare` sets-differences the identities and warns when command or scope differ.
Re-verified on fixtures: added passing packages are silent, a swapped failing test
reports `NEW FAILURE` and `fixed`.

---

## B34 — An "all" contract that returned a truncated subset (2026-10-20, HIGH)

`pr-context.sh --all` advertised "runs Steps A-D in one call" while it listed files
without their contents (Step C.2), capped inline comments at 80 lines and conversation
comments at 20, truncated comment bodies at 220 characters, truncated the diff at 400
lines, carried no thread resolution state or replies, implemented nothing for Azure
DevOps threads, and masked failures by piping stderr to `/dev/null` behind `||`.

A caller running "address every review comment" therefore worked from a partial list
believing gathering was complete.

**Decision:** threads now come from the GraphQL `reviewThreads` query with `isResolved`,
`isOutdated` and every reply; failures surface the real error; every capped or missing
section is labelled `PARTIAL:` / `UNAVAILABLE:` with the command that completes it; file
contents are declared out of scope and left to the caller. Verified against live public
PRs (`cli/cli#11000`, `cli/cli#14750`).

---

## B35 — Blind retry duplicates work items (2026-10-20, HIGH)

The duplicate-registration rule from B11 said to retry the same operation through another
registration whenever a call errors, with no read/write distinction. A create or comment
can succeed remotely and still return a timeout, so the retry files it twice — visible to
the team and notifying its assignee a second time.

**Decision:** `_shared/capabilities.md` splits the rule — reads retry freely; before
retrying a mutation, query live state for the object by id, title or first comment line
and continue only if it is absent; prefer an idempotency key or update-if-exists call
where the API offers one.

---

## B36 — "Config is authoritative" contradicted by unconditional local rules (2026-10-20)

`.agent/config.yml` is declared the primary source (B21), yet skills restated its values
as absolutes:

| Config key | Contradicting rule |
| --- | --- |
| `tracker.pr_title_max` | `pr-description`: *"Never exceed 59 characters in the title"* |
| `tracker.default_priority` | `ado-item`: *"Default Priority to 2"* |
| `devlog.order` | `devlog`: *"reverse chronological, no exceptions"* |
| `tracker.system: none` | `definition-of-done`: a PR reference is mandatory |

A repository declaring `order: chronological` or `pr_title_max: 72` was simultaneously
correct and in violation.

**Decision:** these are **defaults for when the config is silent**, not unconditional
rules. `tracker.system: none` now has stated behaviour: no reference, and
definition-of-done checks 4 and 6 do not apply.

---

## B37 — Devlog UPDATE contradicted the preservation rule (2026-10-20)

Step 5 told UPDATE to *"extend the existing entry in place"*, while the Rules forbade
modifying any existing entry. Taken literally the two cannot both hold, and the mode
the user asks for most — "add this to today's entry" — is the one that collides.

**Decision:** extension and rewriting are different acts. Adding new material to the
current entry is permitted; changing content already written, in that entry or any
other, is not.

---

## B38 — A failed invocation could never be logged (2026-10-20)

`_shared/outcome-log.md` defines `abandoned` and `error` outcomes, then required the
record to be written *"after the completion criteria are met"*. A skill that errored or
was abandoned never meets them, so exactly the records `skill-retrospective` exists to
mine could never be written.

**Decision:** the record is written when the invocation **terminates** — completed,
failed, abandoned or declined.

---

## B39 — A version bump silently retired unresolved evidence (2026-10-20)

`skill-retrospective` counted only outcomes dated after the skill's last version bump.
A PATCH fixing a cross-reference therefore cleared the record of a routing defect it
never touched, and the defect could never reach the 3-outcome threshold.

**Decision:** a record is cleared when a changelog entry addresses its root cause, not by
date. The `v<version>` in each record is attribution — which text produced the outcome —
not a cutoff.

---

## B40 — The validator passed things that do not exist (2026-10-20)

Reproduced in-memory: `validate.py` accepted a skill linking to a nonexistent
`_shared/` file and referencing an undefined `CAP:` identifier, and its no-PyYAML
fallback parser accepted frontmatter that is not YAML. `0 non-compliant` therefore meant
less than it appeared to.

**Decision:** added relative-link resolution, `CAP:` definition checks against
`_shared/capabilities.md`, and a strict reduced parser that raises on anything outside
the permitted subset. The summary line now states that the check is structural, not
behavioural. Verified: a fixture with all three defects reports all three.

---

## B41 — The doc procedure passed an argument the resolver does not accept (2026-10-20)

`doc-lookup` required the user's full question as the **resolver's** query. The connected
Context7 resolver declares exactly one property, `libraryName`; `get-library-docs` is
where a `topic` is accepted. The mandated call was invalid.

**Decision:** library name to the resolver, full question to the fetch call's topic
field, and a standing instruction to read a tool's declared schema rather than assume
its arguments.

---

## B42 — Protection by file category blocked legitimate review (2026-10-20)

`evidence-filter.md` skipped changelogs, release notes and migration history
categorically. That also covered an unreleased changelog entry or a migration introduced
by the PR under review — new content, written in this change, discarded unexamined.

**Decision:** protect **shipped** history — released entries, applied migrations,
append-only logs. Content the PR itself introduced is reviewed like any other new code;
the diff decides which it is.

---

## B43 — Completion criteria were not mode-aware (2026-10-20)

- `skill-creator` config mode produces `.agent/config.yml` and touches no skill, yet its
  completion criteria demanded a changed skill, a cited changelog entry and a validator
  run.
- `pr-review` required an approval round before completion even when the user said not to
  post, so a read-only deliverable ended in a prompt to approve nothing.

**Decision:** completion is defined per mode in both skills. An approval gate guards a
write; with no write there is nothing to gate.

---

## B44 — Measurements claimed more than they collected (2026-10-20)

- `test-run.sh` produces pass/fail/skip only, while the shared report format carried a
  `coverage: NN%` field, inviting an unmeasured number.
- `token-report.py` filtered usage by `--days` but queried `session_files` and
  `forge_trajectory_events` with no window, mixing all-time file and tool counts into a
  dated report.

**Decision:** coverage is either measured with the runner's own flag or reported
`unmeasured`; both previously unfiltered queries now apply the same window and say so in
their headings.

---

## B45 — The seams needed a check, not more prose (2026-10-20)

Five of the defects above (B29, B30, B32, B33, B40) were silent: the installer reported
success, the parser returned a plausible string, the comparison printed a confident
"none", the validator printed `0 non-compliant`. None of them would have been caught by
reading the files, and all five are mechanically checkable.

**Decision:** `agent-tools/selftest.sh` asserts each one in a temp directory. Verified by
mutation — restoring the old `grep -A4` reader and removing the link check makes it fail
with the original symptom (`expected 'pytest -q', got 'testing:'`).

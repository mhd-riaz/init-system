---
name: devlog
description: >
  Create, update, read or summarize devlog entries under docs/devlog/ in any git repo,
  reusing each repo's cached directory, filename convention and entry style. USE FOR:
  update my devlog, log this work, log today's session, create a devlog entry, read or
  summarize my devlog, what did I do this week or month, devlog for this repo. DO NOT USE
  FOR: creating tracker items (use ado-item or gh-issue); writing or reviewing code (use
  write-code or pr-review).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Owns the personal engineering journal: the `*.devlog.md` files under `docs/devlog/` that
record what was actually done, when, and why.

The defining constraint: **everything recorded must have happened.** A devlog is evidence,
not narrative — an invented command or an assumed outcome makes the whole file unusable.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/work-item-context.md`](../../_shared/work-item-context.md) — identity
  and tracker context, including the full resolution ladder
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

## Step 1 — Route the request

| Signal | Mode | Reason |
|---|---|---|
| "update my devlog", "log this work", "log today's session", or a session that just finished | **CREATE** | New work needs a new entry; appending is safer than editing an existing one |
| "add to today's entry", "I forgot X", or today's entry already exists | **UPDATE** | An entry for the day exists, so extend it rather than create a duplicate heading |
| "read my devlog", "show last week's entries", "what's in the devlog" | **READ** | A retrieval verb with no new information to record |
| "what did I do this week/month", "summarize my devlog", "write my status" | **SUMMARIZE** | A time window plus an aggregation verb — the deliverable is a digest, not the entries |
| Anything ambiguous | **CREATE** (default) | Most devlog mentions carry new work to record; a misrouted read costs one repeat, a missed record is lost for good |

Route on the **verb and the time window**, not on the topic. "Devlog for the auth refactor"
is CREATE; "devlog for March" is SUMMARIZE.

## Step 2 — Resolve the repo cache key

One combined command via `CAP:GIT` — not four round trips:

```sh
git rev-parse --show-toplevel; git remote get-url origin; git log -1 --format='%H %cI %s'
```

Separators are `;`, not `&&`: a repo with no `origin` must not abort the whole probe.

The repo root plus the remote form the cache key. The last commit supplies the real date
and the anchor for what the session actually touched.

## Step 3 — Read the devlog cache

**If `.agent/config.yml` defines a `devlog` section, use it and skip discovery
entirely** — `dir`, `filename` and `order` are declarations, not guesses. See
[`../../_shared/repo-config.md`](../../_shared/repo-config.md).

Otherwise read `{{STATE_GLOBAL}}/devlog-cache.md` via `CAP:MEMORY`, falling back to a
direct file read. Per repo key it holds:

```markdown
## <repo-key>
- directory: docs/devlog/
- filename: <the repo's observed convention>
- style: <one line describing the entry shape>
- display_name: <name used in entries>
```

**On a cache hit, use it.** The filename convention and entry style are never
re-derived — re-deriving them is how a repo ends up with two incompatible formats.

## Step 4 — On a cache miss, delegate discovery

Delegate to `CAP:SUBAGENT` at `TIER:FAST` with a narrow, closed-ended prompt. Ask it to
return **only** these four values, with evidence:

1. the devlog directory (expected `docs/devlog/`);
2. the filename convention, inferred from existing `*.devlog.md` files;
3. the entry style — heading level, date format, section shape — from the newest entry;
4. the display name used in entries.

Restate the one-line secrets prohibition from
[`../../rules/no-secret-files.md`](../../rules/no-secret-files.md) in the prompt.
Sub-agents do not inherit this bundle's rules.

Only `*.devlog.md` files count. A `README.md` or `notes.md` in the same directory is not
a devlog and must not be treated as one.

Write the four resolved values back to the cache before continuing.

> **Gate — ambiguous discovery.**
> If the sub-agent reports ambiguity (no matching directory, or multiple plausible
> matches), ask the user before writing anything. Guessing a location creates an orphan
> file in a repo that already has a journal somewhere else.
> See [`approval-gate.md`](../../_shared/approval-gate.md).

## Step 5 — CREATE and UPDATE

Delegate the **draft** to `CAP:SUBAGENT` at `TIER:FAST`; the **main agent performs the
write**. The sub-agent returns entry text and nothing else — it does not touch the file.

The draft covers only what actually happened this session: commands run and their real
results, files changed, decisions taken and the reason, problems hit and how they were
resolved, and what remains open.

Writing rules, in order:

1. **Newest entry first unless `devlog.order` says otherwise.** Default
   reverse-chronological: insert above the previous entry. When the config declares
   `order: chronological`, append to the end instead — the config is the declaration
   ([`../../_shared/repo-config.md`](../../_shared/repo-config.md)).
2. **Preserve every existing byte of every past entry.** Never reflow, reformat, re-date
   or prune them — they are a record, and editing them destroys its value.
3. **Match the cached style exactly** — heading level, date format, section order.
4. For UPDATE, **extend the current entry**: add the new material inside it, under its
   existing heading, leaving its existing content untouched. Adding to today's open entry
   is not modifying history; rewriting a line that is already there is. Never open a
   second heading for the same day.
5. Use `CAP:EDIT` for an existing file and `CAP:CREATE` only when the file genuinely does
   not exist.

Timestamps come from `git log`, the system clock or the user — never from inference.

## Step 6 — READ and SUMMARIZE

**READ** — locate the relevant entries with `CAP:GLOB` plus `CAP:GREP`, then display them
**unchanged**. No rewriting, no tidying, no "improved" phrasing. The user asked for what
is there.

**SUMMARIZE** — delegate the digest to `CAP:SUBAGENT` at `TIER:FAST` (`TIER:LONG` when
the window spans many months). Give it the explicit date range and the file list; have it
return themes, shipped work and open threads, with the source entry dates attached.

Optionally enrich the digest with tracker references via `CAP:ADO` or `CAP:GH` when entry
text names work items or issues — resolve each id to its title so the summary reads
without the tracker open. Skip silently-failing lookups and say so in one line.

## Step 7 — Report

For CREATE and UPDATE, report **only**:

```
<path/to/file.devlog.md> — <one line on what was recorded>
```

Do not echo the entry back. It is in the file, and repeating it is pure duplication.

For READ, the entries are the output. For SUMMARIZE, the digest is the output.

## Related skills

| Situation | Skill |
|---|---|
| Creating the Azure DevOps work item being logged | `ado-item` |
| Creating the GitHub issue being logged | `gh-issue` |
| Doing the implementation work itself | `write-code` |
| Reviewing a pull request | `pr-review` |
| Writing the PR body | `pr-description` |

## Rules

- Never invent commands, files, tests, or outcomes. A devlog entry is evidence; one
  fabricated line makes every other line unverifiable.
- Only `*.devlog.md` files under `docs/devlog/` are devlogs.
- Order follows `devlog.order`; absent a config, newest entry at the top.
- Never modify, reformat or delete content already written in any entry. UPDATE may add
  new material to the current entry; it may not rewrite what is there.
- Never re-derive a repo's filename convention or entry style once cached.
- The sub-agent drafts; the main agent writes. A delegated write loses the preservation
  guarantees above.
- Ask the user when discovery is ambiguous rather than guessing a location.
- Display entries unchanged in READ mode.
- Report the path touched and one line of description — never the entry body.
- Restate the secrets prohibition in every delegation prompt.

## Completion criteria

Done when the requested operation has completed and, for create/update, the file path
touched has been reported to the user.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to `{{STATE_GLOBAL}}/skill-outcomes.md` — this skill is global-scoped.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates the four devlog modes into
  one signal-routed workflow and moves identity resolution, the approval gate and outcome
  logging onto the shared procedures.
- 1.1.0 (2026-10-20) — A `devlog` section in `.agent/config.yml` now short-circuits
  discovery entirely (B21). Cache remains the fallback.
- 2.0.0 (2026-10-20) — UPDATE may add to the current entry without that counting as
  modifying history; entry order follows `devlog.order` instead of an unconditional
  reverse-chronological rule (B36, B37).

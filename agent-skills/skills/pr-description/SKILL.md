---
name: pr-description
description: >
  Writes a pull request description from the actual diff onto a fixed template — a
  work-item or issue reference, a title of 59 characters or fewer, and What / Why /
  Changes sections. USE FOR: write a PR description, draft the PR body, summarize my
  changes for a pull request, I am opening a PR. DO NOT USE FOR: reviewing PR code
  quality or security (use pr-review); resolving reviewer comments (use resolve-pr);
  implementing the change itself (use write-code).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Owns one artefact: the text of a pull request. Produces a title and body from the real
diff against the repository's default branch, on a fixed template with a valid tracker
reference.

The defining constraint: **the description comes from the diff, not from the task
narrative.** What was intended and what was committed are different facts; only the
second belongs in a PR body.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/repo-config.md`](../../_shared/repo-config.md) — `tracker.commit_prefix`,
  `tracker.pr_title_prefix` and `pr_title_max` for this repository
- [`../../_shared/work-item-context.md`](../../_shared/work-item-context.md) — tracker identity

## Step 1 — Resolve the work-item or issue reference

Run the resolution ladder in
[`work-item-context.md`](../../_shared/work-item-context.md) **only for values you do not
already have**. The id is usually already present — in the user's message, in the branch
name, in the commit messages, or in this session's earlier steps.

The reference format follows **`tracker.system`**, never the git remote or `code_host`:
work items can live in Azure DevOps while the code is hosted on GitHub (`AUDIT-LOG.md`
B21). Use `code_host` only for the PR/API call itself. Ask only if no id can be found
anywhere; when `tracker.system` is `none`, emit no reference and say so in one line.

## Step 2 — Detect the default branch

Determine the repository's default branch via `CAP:GIT` rather than assuming `main`:

```sh
git symbolic-ref --quiet --short refs/remotes/origin/HEAD   # e.g. origin/develop
```

Fall back to the remote's reported head, then to the branch the PR actually targets.
Never hardcode a branch name.

## Step 3 — Read the diff

```sh
git --no-pager diff --stat <default>...HEAD
git --no-pager diff <default>...HEAD
```

Three dots, not two: compare against the merge base, so commits that landed on the
default branch since branching are excluded. Read the diff itself — commit messages are
a hint about intent, never evidence of what changed.

For a very large diff, read the stat plus the files carrying the substantive change, and
summarize the mechanical remainder in one line rather than enumerating it.

## Step 4 — Emit the description

Fill the template for `tracker.system`. Both use the same three sections, in the same
order.

**`tracker.system: ado`** — the title is prefixed with the work-item reference, even when
the PR itself is opened on GitHub:

```
AB#<id> : <title>

## What
<One paragraph: what this change does, in the present tense.>

## Why
<The reason: the work item's problem, the bug's symptom, or the requirement it meets.>

## Changes
- `path/to/file` — <what changed here and why>
- `path/to/other` — <what changed here and why>
```

**`tracker.system: github`** — no title prefix; the reference closes the issue from the
body:

```
<title>

## What
<One paragraph: what this change does, in the present tense.>

## Why
<The reason: the issue's problem, the bug's symptom, or the requirement it meets.>

## Changes
- `path/to/file` — <what changed here and why>

Closes #<id>
```

Rules for the fields:

- **Title: `tracker.pr_title_max` characters maximum, 59 when the config does not set
  it**, including the `AB#<id> : ` prefix.
- **Commit messages use a different separator from PR titles.** Observed usage, do not
  interchange them (`AUDIT-LOG.md` B18):

  | Where | Format |
  |---|---|
  | Commit message prefix | `AB#<id> - ` (hyphen) |
  | Azure DevOps PR title | `AB#<id> : ` (colon) |
  | GitHub PR body | `Closes #<id>` |
  Count it. Shorten the wording rather than dropping the prefix.
- **What** describes the change, not the process. No "I refactored", no "as discussed".
- **Why** gives the reason a reviewer needs, not a restatement of What.
- **Changes** lists only files that actually appear in the diff, each with a reason.
  Group mechanical churn — formatting, generated files, lockfiles — into one line.
- Never invent a work-item id, a file path, or a change the diff does not contain.

## Related skills

| Situation | Skill |
|---|---|
| Reviewing the PR's code quality or security | `pr-review` |
| Acting on reviewer comments | `resolve-pr` |
| Implementing the change itself | `write-code` |
| Writing or repairing the tests | `write-tests` |
| Creating the tracker item the PR references | `ado-item`, `gh-issue` |

## Rules

- Never write the description from the task narrative when the diff is available.
- Never exceed the title limit — `tracker.pr_title_max`, else 59 — prefix included.
- Never omit the work-item or issue reference; ask for it rather than guessing one.
  Exception: `tracker.system: none`, where no reference exists to omit.
- Never list a file in Changes that does not appear in the diff.
- Never reorder, rename, or add to the three sections.
- Never hardcode `main` as the default branch — detect it.
- Never open, update, or push the PR from this skill unless the user asked for it.
- State every degraded capability in one line rather than skipping the step silently.

## Completion criteria

Done when a description matching the template has been produced, within the configured
title limit (59 when unset) and carrying a valid work-item reference — or, under
`tracker.system: none`, a stated note that no tracker reference applies.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates tracker-id resolution and
  platform detection onto `_shared/work-item-context.md`, keeping only the fixed title
  and body conventions here.
- 1.1.0 (2026-10-20) — Recorded that commit prefixes use `AB#id - ` while ADO PR titles
  use `AB#id : `; the two are not interchangeable (B18).
- 1.2.0 (2026-10-20) — Prefixes and title length now come from `.agent/config.yml`
  when present, rather than being assumed per platform (B21).
- 2.0.0 (2026-10-20) — Reference format now follows `tracker.system`, not the remote, so
  ADO-tracked work on a GitHub host no longer emits `Closes #id` (B31); title limit and
  the no-tracker case are config-driven (B36).

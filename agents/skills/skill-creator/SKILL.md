---
name: skill-creator
description: >
  The authoring procedure for skills in this bundle; operationalizes SPEC.md rather than
  restating it. USE FOR: create a new skill, write a skill, update or fix an existing
  skill, add a skill to the bundle, validate my skills, why is my skill not triggering,
  split a skill that got too big, set up or fix this repo's agent config. DO NOT USE FOR: proposing skill changes from accumulated
  usage evidence (use skill-retrospective); writing application code (use write-code);
  current library documentation (use doc-lookup).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

**Read [`../../SPEC.md`](../../SPEC.md) before writing anything. This skill is the
procedure; the spec is the contract.**

Everything that can be checked — the five permitted frontmatter keys, the 600-character
description cap, the seven required headings and their order, the 500-line body budget, the
portability requirements — is defined there and enforced by `agent-tools/validate.py`. This skill
does not repeat any of it. It covers the part a validator cannot check: how to arrive at a
skill that triggers correctly and earns its tokens.

Resolve every `CAP:` reference via
[`../../_shared/capabilities.md`](../../_shared/capabilities.md).

## Modes

| Signal in the request | Mode | Reason |
|---|---|---|
| create / write / update / fix / split a skill | **author** — Steps 1-6 below | the skill itself is the artifact |
| validate, why is my skill not triggering | **author** — Step 5, then the relevant step | diagnosis starts from the validator |
| set up / init / fix this repo's agent config | **config** — see below | the artifact is `.agent/config.yml`, not a skill |

Default when ambiguous: **author**. A request naming a repository rather than a skill is
the reliable signal for config mode.

## Mode: initialize a repository config

Creates `.agent/config.yml` so skills stop guessing this repository's tracker, host and
conventions. Detection from the git remote is wrong whenever the code host and the work
tracker differ, which is common (`AUDIT-LOG.md` B21).

1. **Detect what can be detected**, with one `CAP:GIT` call each: the `origin` remote
   (host, owner, repo), the default branch, and whether recent commits carry a tracker
   prefix — `git --no-pager log --oneline -20`. An `AB#` prefix on a GitHub remote means
   the tracker is Azure DevOps, not GitHub Issues.
2. **Read any existing repo instructions** — `.github/copilot-instructions.md`,
   `AGENTS.md`, `CONTRIBUTING.md` — for conventions already written down in prose:
   test commands, branch naming, review requirements.
3. **Ask once, batched**, for only what remains unresolved: tracker system and
   org/project, commit and PR prefixes, and whether any skills should be disabled here.
   Never ask for anything detected in step 1.
4. **Write** `.agent/config.yml` from
   [`../../templates/agent-config.template.yml`](../../templates/agent-config.template.yml),
   including only the sections that apply. Delete the rest rather than leaving commented
   stubs.
5. **Add `.agent/` to `.gitignore`** unless the user wants the config committed for the
   team.
6. **Report** the detected values separately from the supplied ones, so a wrong detection
   is visible.

Schema: [`../../_shared/repo-config.md`](../../_shared/repo-config.md).

For a personal repository with no tracker, `tracker.system: none` is the whole point —
it silences every work-item step without disabling any skill.

## Step 1 — Understand, with concrete examples

The goal of this step is a list of **sentences a user would actually type**, not a topic.

Ask, through `CAP:ASK` when available:

1. *"What would a user SAY that should trigger this?"* Collect three to five real phrasings.
   A skill is selected from its description, so phrasings are the raw material of the
   description and therefore of whether the skill ever fires.
2. *"What should it explicitly NOT handle, and which existing skill owns that instead?"*
   This becomes `DO NOT USE FOR:`, which must name the sibling.
3. *"Walk me through the last time you did this manually."* The friction in that account is
   what the skill is actually for.
4. *"What does done look like?"* This becomes `## Completion criteria`.

**Batch every question into one round.** Interrogating across turns is a worse experience
than making a reasonable assumption and stating it.

Before writing, check for an existing owner: list `{{SKILLS_DIR}}/skills/` and read the
descriptions of the nearest two or three. If an existing skill already covers this, extend
it instead. Two skills with overlapping triggers is a defect in both.

## Step 2 — Plan the resources

Decide what belongs in `SKILL.md` and what belongs outside it, using the taxonomy in
[SPEC §4](../../SPEC.md#4-body-budget-and-progressive-disclosure). In short: `scripts/` is
executed and never enters context, `references/` is read on demand, `assets/` is emitted
into output, and `_shared/` holds anything two or more skills need.

Two planning decisions matter more than the rest:

- **Anything already in `_shared/` or `rules/` gets linked, never copied.** If this skill
  needs a procedure a sibling already has, extract it to `_shared/` and link it from both.
- **Pick the degrees of freedom per step** using
  [SPEC §5](../../SPEC.md#5-degrees-of-freedom). Field mappings, ID formats and destructive
  operations are low-freedom and get exact commands; design and analysis are high-freedom
  and get prose. State which a step is when it is not obvious from the wording.

## Step 3 — Initialize from the template

Copy [`../../templates/SKILL.template.md`](../../templates/SKILL.template.md) to
`{{SKILLS_DIR}}/skills/<kebab-case-name>/SKILL.md`.

Start from the template every time, including for an edit that grows into a rewrite. It
carries the required heading order, so the most common structural failures cannot occur.

The directory name and the frontmatter `name:` must match exactly.

## Step 4 — Write the resources first, then SKILL.md

Resources first: writing the reference or script first reveals how much of it was never
needed in the body, which is the whole point of the split.

Then write `SKILL.md`, in this order:

1. **The description.** Hardest and most valuable — it is the only part loaded in every
   session. Keep every concrete trigger phrase from Step 1; cut prose, not triggers.
2. **The workflow steps**, verb-led and imperative.
3. **`## Related skills`**, honouring the symmetry rule in
   [SPEC §3](../../SPEC.md#3-required-body-sections-in-this-order): if this skill lists a
   sibling, the sibling's boundary must list this one back.
4. **`## Rules`**, where every prohibition carries its reason, both directions, and an
   alternative, per [SPEC §6](../../SPEC.md#6-writing-rules).
5. **`## Completion criteria`**, checkable rather than aspirational.

> **Gate — applying changes to an existing skill.**
> Before editing a skill that already exists, present the exact old-and-new diff and the
> proposed version bump, and stop. Offer: proceed / proceed with changes / stop.
> **Do not write to the file before the user confirms.** A skill is an instruction another
> agent will follow unsupervised; a silent edit changes behaviour the user cannot see until
> it misfires. See [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md).

This gate does not apply to a brand-new skill that nothing depends on yet.

## Step 5 — Validate

From the bundle root:

```sh
python3 agent-tools/validate.py
```

Iterate until it prints `0 non-compliant`. Fix the reported error rather than working
around it — every check corresponds to a provider that rejects the file outright.

Then check what the validator cannot:

- Read the description cold and ask whether it would be picked over its nearest sibling.
- Confirm no section of the body is duplicated from `SPEC.md`, `_shared/` or `rules/`.
- Confirm any shipped script has been **executed at least once** before being committed.

## Step 6 — Iterate from real usage

Do not polish a skill in the abstract. Use it, notice where it was corrected, then fix it
and bump the version citing that correction — per
[SPEC §7](../../SPEC.md#7-versioning). A version bumped with an unattributed rewording is
drift wearing a changelog entry.

Accumulated evidence across many sessions is `skill-retrospective`'s job, not this one's.

## Common failures

| Failure | Why it happens | Fix |
|---|---|---|
| Triggers written in the body, often as "When to use this skill" | Feels like documentation | Move every trigger phrase into `description`. The body loads only *after* triggering, so a trigger in the body can never fire. Delete the section. |
| No `DO NOT USE FOR:`, or one that describes instead of naming | The boundary felt obvious while writing | Name the sibling skill that owns the excluded territory. Unnamed boundaries collide at selection time. |
| Top-level `version:` key | Habit from other YAML formats | Move it to `metadata.version`. Codex rejects the whole file on an unexpected key. |
| Angle brackets in the description | Placeholder syntax leaking out of the body | Write `AB#id`, not the bracketed form. Rejected by validation. |
| Body over 500 lines | Variant detail accumulated in the main file | Split variants into `references/`; keep the core workflow and the selection guidance in `SKILL.md`. |
| Content duplicated from `SPEC.md` or a sibling | Copying felt safer than linking | Extract to `_shared/` and link from both. Duplicated procedure drifts and then disagrees with itself. |
| Description over 600 characters | Explaining the workflow in the advert | Cut everything that does not change which skill gets picked. The body is free until used; the description is not. |
| Name does not match the folder | Renamed one and not the other | Make them identical, kebab-case, lowercase. |

## Related skills

| Situation | Skill |
|---|---|
| Proposing skill updates from accumulated outcome evidence | `skill-retrospective` |
| Writing application code rather than a skill | `write-code` |
| The engineering rules a skill should cite | `engineering-os` |
| Current library or framework documentation | `doc-lookup` |

## Rules

- Read `SPEC.md` before writing. Never restate its rules inside a skill; link the section.
- Collect real trigger phrasings before writing the description; invented ones do not match
  how the user actually types.
- Keep every trigger phrase when trimming a description. Cut prose instead.
- Name the sibling skill in `DO NOT USE FOR:`; a described boundary is not a boundary.
- Never edit an existing skill without showing the diff and the version bump first.
- Never duplicate content that belongs in `_shared/`, `rules/` or `SPEC.md`.
- Never bump a version without citing the correction, session or audit finding behind it.
- Never commit a script in `scripts/` that has not been executed at least once.
- Validate until `0 non-compliant`; do not hand over a skill with known errors.

## Completion criteria

Mode-dependent:

| Mode | Done when |
|---|---|
| author | `python3 agent-tools/validate.py` prints `0 non-compliant`, the new or edited skill has a cited changelog entry, and `INDEX.md` is updated if a skill was added or removed |
| config | `.agent/config.yml` exists with the sections that apply, `.agent/` is gitignored unless the user chose otherwise, and detected values were reported separately from supplied ones |

Config mode touches no skill file, so no validator run, changelog entry or `INDEX.md`
update is required of it.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates skill authoring onto
  `SPEC.md` as the single source of the contract, replacing restated rules with links, and
  adds the common-failures table and the edit-approval gate.
- 1.1.0 (2026-10-20) — Added a config mode that initializes `.agent/config.yml` from
  detected repository state, so skills stop inferring the tracker from the git remote
  (B21). No authoring rule changed.
- 2.0.0 (2026-10-20) — Completion criteria are per mode; config mode no longer has to
  produce a changed skill, a changelog entry or a validator run (B43).

---
name: skill-retrospective
description: >
  Read-only analysis that mines outcome logs and session history to propose skill updates
  backed by cited evidence, and applies nothing without approval. USE FOR: run the skill
  retrospective, audit skill usage, propose skill fixes from real usage, check if a skill
  needs updating, what corrections have piled up for a skill. DO NOT USE FOR: creating or
  editing a skill directly without evidence (use skill-creator); writing application code
  (use write-code); reviewing a pull request (use pr-review).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

Closes the loop between how skills are *written* and how they actually *behave*. Every
skill appends an outcome record when an invocation ends, successful or not; this one
reads those records in bulk, finds the skills whose corrections have accumulated, and
proposes specific edits with the evidence attached.

Analysis and proposal only. `skill-creator` owns authoring; this skill never invents a
change it cannot cite.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) — the record schema
- [`../../_shared/evidence-filter.md`](../../_shared/evidence-filter.md) — classifying a claim before acting on it
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md) — the gate in Step 5

## Step 1 — Gather the evidence

Run these together, in parallel — they are independent:

1. Read `{{STATE_REPO}}/skill-outcomes.md` with `CAP:READ`.
2. Read `{{STATE_GLOBAL}}/skill-outcomes.md` with `CAP:READ`.
3. Query session history with `CAP:SESSION-QUERY` for sessions in which a skill was
   corrected, abandoned, or produced a failing result.
4. Read each skill's `## Changelog` to find the date and version of its **last bump**.

Degrade rather than fail. A missing log file means no records for that scope, which is a
finding — state it in one line. If `CAP:SESSION-QUERY` is unavailable, say the history was
unavailable and proceed on the logs alone.

## Step 2 — Count qualifying outcomes

For each skill, count records that are still **uncleared**. A record is cleared only when
a shipped change addressed its root cause — that is, a changelog entry names it. **A
version bump clears nothing by itself:** a PATCH fixing a cross-reference leaves a routing
defect exactly where it was, and a date cutoff would silently retire the evidence for it.

Use the `v<version>` in each record for **attribution** — which text produced the outcome
— not as a cutoff.

| Outcome | Counts toward the trigger? | Why |
|---|---|---|
| `corrected` | **Yes** | The user fixed something the skill should have handled. The primary signal. |
| `abandoned` | **Yes** | Scope or routing was wrong often enough that the skill was dropped mid-task. |
| `error` | **Yes** | The skill's own instructions produced a wrong or failing result. |
| `success` | No | Nothing to learn from. A log of only successes is a log that improves nothing. |

Apply the evidence filter: a record whose `correction` field is vague ("user clarified
scope") is not actionable. Count it, but do not build a proposal on it alone — say that the
signal exists but is too thin to act on.

## Step 3 — Decide what is due

A skill is **DUE** when either threshold is met, whichever comes first:

| Threshold | Condition |
|---|---|
| Volume | 3 or more uncleared qualifying outcomes |
| Age | 30 or more days since the last bump **and** at least 1 uncleared qualifying outcome |

A skill meeting neither is **not due**. Leave it untouched and do not mention it except as a
line in the summary count. Reviewing a healthy skill because it was in scope is how a
retrospective turns into drift.

## Step 4 — Draft the diffs

For each due skill, draft the smallest edit that would have prevented the cited outcomes.

- Quote the **exact old text** and the **exact new text**. A described change cannot be
  approved, only agreed to in principle.
- Attach the specific outcome record or session reference each change answers.
- Choose the version bump by the definition in
  [SPEC §7](../../SPEC.md#7-versioning) — MAJOR removes or reverses a rule or step, MINOR
  adds one without changing a prior verdict, PATCH is wording and cross-references only.
- Write the changelog entry at the same time, citing the evidence.

If several outcomes point at the same root cause, propose one change, not three.

If the evidence shows the skill fired when it should not have, the fix usually belongs in
the `description` boundaries rather than the body. Triggering defects are description
defects.

## Step 5 — Present the proposal

Present one table covering every due skill, then stop.

| Skill | Due (why) | Cited outcomes | Proposed change | Version bump |
|---|---|---|---|---|
| `write-code` | 4 uncleared since 1.0.0 | 2026-10-04 corrected, 2026-10-09 corrected, 2026-10-11 error, 2026-10-14 corrected | Add a Rule requiring re-read of files edited by another process | 1.1.0 |

Follow the table with the exact old-and-new text for each change, grouped by skill.

> **Gate — applying skill edits.**
> Present the table and the diffs, then stop. Offer: apply all / apply a subset — name
> which / none.
> **Do not write to any skill file before the user answers.** See
> [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md).

**Never edit a skill file without first presenting the evidence and getting explicit
approval.** Not a "clearly correct" fix, not a typo noticed in passing, not a change the
same user approved for a different skill last week. A skill edited on a hunch is a skill
that drifts away from the behaviour its outcomes actually justify — and because skills run
unsupervised, that drift is invisible until it misfires in someone else's session. If a
change seems too obvious to need approval, it costs one line to include it in the table.

## Step 6 — Apply only approved edits

For each approved change, and only those:

1. Apply the exact diff that was shown, with `CAP:EDIT`. Nothing that was not in the table.
2. Bump `metadata.version`.
3. Append the changelog entry, **naming the outcome records it clears** — the dates and
   outcomes, not just "B-nn" — because that citation is what marks them cleared for the
   next retrospective. **Newest last.**
4. Re-run `python3 agent-tools/validate.py` from the bundle root. It must print `0 non-compliant`.

A rejected or deferred proposal is left exactly as it was. Do not apply a softened version
of a declined change.

## Step 7 — Report and log

Report in this shape:

```
Skills reviewed     <count>
Due                 <names>
Applied             <name vN -> vN+1, one line on what changed>
Declined            <name — the user's reason>
Not due             <count> (untouched)
Evidence gaps       <logs or history unavailable, or "none">
```

Then append this retrospective's own outcome record.

## Related skills

| Situation | Skill |
|---|---|
| Writing or editing a skill directly | `skill-creator` |
| The authoring contract these proposals must satisfy | `skill-creator`, [`SPEC.md`](../../SPEC.md) |
| Writing application code | `write-code` |
| Reviewing a pull request | `pr-review` |

## Rules

- Every proposal cites at least one concrete outcome record or session reference. No
  exceptions, including for changes that look self-evidently correct.
- Never speculate. A change with no cited evidence is not proposed, however good it seems —
  the whole value of this skill is that its edits are traceable to observed behaviour.
- Never edit a skill file before the user has seen the evidence and approved the change.
- Leave skills that do not meet the trigger untouched; do not review them opportunistically.
- Count every outcome whose root cause no changelog entry has yet addressed. A version
  bump is not a clearance: clear a record when its cause is fixed, never by date.
- The outcome log is **append-only**. Never rewrite, reorder, delete, or "tidy" a record,
  even one that is wrong — a mutable log cannot be evidence, and the next retrospective has
  no way to tell a correction from a rewrite. Add a new record instead.
- Propose one change per root cause, not one per record.
- Pick the version bump by SPEC §7, never by how large the diff looks.
- Re-run the validator after applying edits; never hand back a bundle with known errors.
- State every unavailable log or history source in one line rather than omitting it.

## Completion criteria

Done when every skill meeting the trigger has been proposed, approved-and-applied, or
explicitly skipped by the user — and skills not meeting the trigger have been left
untouched. If any edit was applied, `python3 agent-tools/validate.py` prints `0 non-compliant`.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates manual skill review into an
  evidence-gated workflow with explicit DUE thresholds, a citation requirement per
  proposal, and a hard approval gate before any skill file is written.
- 2.0.0 (2026-10-20) — A record is cleared when a changelog entry addresses its root
  cause, not when any version is bumped; `v<version>` in a record is attribution, not a
  date cutoff (B39).

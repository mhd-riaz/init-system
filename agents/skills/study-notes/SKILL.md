---
name: study-notes
description: >
  Two-stage study-material builder for academic coursework — extract a prerequisite-
  ordered, cited concept hierarchy from supplied chapters, then expand each concept with
  explanations, worked examples, formulas, code and likely exam questions. USE FOR: build
  study material, make study notes from these chapters, extract every concept, study
  checklist, explain this syllabus topic, what 10-mark questions to expect, revision
  guide. DO NOT USE FOR: software documentation (use engineering-os); library or API
  lookups (use doc-lookup); devlog entries (use devlog).
license: MIT
metadata:
  version: 1.0.0
---

## Purpose

Turns supplied course material — chapters, lecture notes, slides, PDFs — into a complete,
prerequisite-ordered study resource with exam-oriented expansion.

The defining constraint: **Stage 1 must finish and be confirmed before Stage 2 begins.**
Expansion is expensive and ordered; expanding an unconfirmed or incomplete concept list
wastes the effort and buries the gaps the user most needed to see.

Shared procedures used here:
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:`
- [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md)

---

# Stage 1 — Concept extraction

## Step 1 — Establish the level

If the grade, year, course level or exam board is not stated, ask for it — batched with
any other opening question, in one round via `CAP:ASK`.

Level governs depth, vocabulary and what counts as atomic. The same topic decomposes
very differently for school, undergraduate and postgraduate work; extracting at the wrong
level produces material that is either patronising or unusable.

## Step 2 — Process every piece of supplied material

Read **all** of it via `CAP:READ`: every file, every page, every section, every diagram,
every worked example. Figures and solved examples carry concepts that the prose does not
state — a worked example usually encodes the method the exam will test.

Delegate bulk reading of large sets to `CAP:SUBAGENT` at `TIER:LONG`, one bounded batch
per source, returning concepts with citations and nothing else. Restate the one-line
secrets prohibition from
[`../../rules/no-secret-files.md`](../../rules/no-secret-files.md) in every prompt.

Skipping material is the failure mode this step exists to prevent. If something cannot be
read — unsupported format, missing file, unreadable scan — say so explicitly in Part C
rather than quietly omitting it.

## Step 3 — Extract and decompose to atomic level

For every concept found:

1. Name it as it would appear on a syllabus.
2. **Decompose recursively** until each item is atomic — a single idea that can be
   explained, tested and marked on its own. A concept that needs the word "and" to
   describe it is usually two concepts.
3. Record a **source citation: file and page** (or slide/section where there are no
   pages). Every concept carries one.
4. Note its direct prerequisites by name.

## Step 4 — Merge duplicates and order by prerequisite

- Merge concepts that appear in several sources into one entry carrying **all** its
  citations. Near-duplicates under different names merge too; keep the syllabus term.
- Order the result so **every prerequisite appears before anything that depends on it**.
  This ordering is the deliverable's main value — a list in chapter order is just a table
  of contents.
- A circular dependency means the decomposition is wrong. Split the smaller concept out
  and re-order rather than shipping the cycle.

## Step 5 — Deliver Stage 1

Three parts, in this order:

**Part A — Concept map.** The hierarchy: top-level topics, their sub-concepts, and the
prerequisite edges between them.

**Part B — Ordered checklist.** Flat, prerequisite-first, study-ready:

```
- [ ] <concept>  —  <source file>, p.<n>
```

**Part C — Gaps and missing prerequisites.** Concepts the material depends on but never
covers; sections that could not be read; anything the syllabus implies and the sources
omit. This part is what sends the user back for the chapter they forgot to supply.

> **Gate — Stage 1 confirmation.**
> Present Parts A, B and C and stop. Offer: expand all / expand a chosen subset / adjust
> the list first. **Do not begin any Stage 2 expansion until the user confirms** — not
> one concept, not "just the first topic to show the format".
> See [`approval-gate.md`](../../_shared/approval-gate.md).

---

# Stage 2 — Expansion

## Step 6 — Expand each confirmed concept

Work in the confirmed prerequisite order. Every concept gets **all six** elements:

| # | Element | Requirement |
|---|---|---|
| 1 | Plain explanation | The idea in ordinary language, at the Step 1 level, before any notation |
| 2 | Worked example | Fully solved, every step shown — not a stated answer |
| 3 | Formulas | Each one with **every symbol defined**, including units where they apply |
| 4 | Code | Where the concept is implementable; omit with a one-line reason where it is not |
| 5 | Common mistakes | The specific errors students actually make here, and the correction |
| 6 | Likely exam questions | With **mark weightings** — 2-mark recall through 10-mark derivation |

An element that genuinely does not apply is marked "not applicable" with a reason. It is
never silently dropped — a missing element reads as an oversight.

## Step 7 — Batch and confirm

Deliver in **absorbable batches**, grouped by topic rather than by a fixed count, and
confirm before continuing to the next one. Study material arrives faster than it can be
read; dumping forty expanded concepts at once guarantees most go unread.

Between batches, state what is done and what remains, so the user can stop, reorder, or
redirect depth at any point.

## Related skills

| Situation | Skill |
|---|---|
| Software engineering standards and documentation | `engineering-os` |
| Current library, framework or API documentation | `doc-lookup` |
| Recording a work session rather than studying | `devlog` |

## Rules

- Never begin Stage 2 before Stage 1 is confirmed.
- Never skip supplied material — including diagrams, worked examples and appendices.
- Never invent a citation. Every concept carries a real source file and page; an
  unverifiable citation makes the whole checklist untrustworthy for revision.
- State unreadable or missing sources in Part C rather than omitting them.
- Prerequisite order is mandatory; chapter order is not an acceptable substitute.
- Decompose until atomic — one idea per checklist item.
- Merge duplicate concepts, keeping all citations and the syllabus term.
- Give every expanded concept all six elements, or mark one "not applicable" with a reason.
- Define every symbol in every formula.
- Attach mark weightings to exam questions.
- Deliver expansion in batches and confirm between them.
- Restate the secrets prohibition in every delegation prompt.

## Completion criteria

Done when Stage 1 has been confirmed and every confirmed concept has been expanded with
all six elements, or the user has stopped the batching.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to `{{STATE_GLOBAL}}/skill-outcomes.md` — this skill is global-scoped.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates concept extraction and
  concept expansion into one gated two-stage workflow and moves the approval gate and
  outcome logging onto the shared procedures.

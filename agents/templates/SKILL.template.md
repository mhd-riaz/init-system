---
name: skill-name-here
description: >
  One or two sentences on what this does. USE FOR: concrete trigger phrase, another
  trigger phrase, a third. DO NOT USE FOR: excluded territory (use sibling-skill);
  other excluded case (use other-skill).
license: MIT
metadata:
  version: 0.1.0
---

## Purpose

What this owns, in two or three sentences. State the boundary that separates it from
its nearest sibling.

Shared procedures this skill uses:
- [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md)
- [`../../_shared/capabilities.md`](../../_shared/capabilities.md) — resolve every `CAP:` reference

## Step 1 — <verb phrase>

What to do. Imperative. Name capabilities, never provider tool names.

## Step 2 — <verb phrase>

Keep steps verb-led and numbered. Put variant detail in `references/`, not here.

> **Gate — <what is about to happen>**
> Present the change, offer numbered options with a marked default, and stop.
> See [`../../_shared/approval-gate.md`](../../_shared/approval-gate.md).
> Do not <the thing that must not happen> before this clears.

## Step N — Report

The output contract: exactly what the user receives at the end.

## Related skills

| Situation | Skill |
|---|---|
| <situation that belongs elsewhere> | `sibling-skill` |

## Rules

- Imperative, checkable statements only.
- One rule per line. No prose paragraphs.
- Prohibitions carry their reason: the reason is what closes the workaround.

## Completion criteria

Done when <exact, checkable conditions>.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md)
to `{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 0.1.0 (YYYY-MM-DD) — initial version.

---
name: doc-lookup
description: >
  Grounds library and framework answers in fetched documentation, never model recall. USE
  FOR: how do I configure a named library, write code using a library, what are a library's
  API methods, setup or config questions, version differences, or any mention of a named
  framework such as React, Vue, Next.js, Prisma, Supabase, Tailwind, Express, Django or
  FastAPI. DO NOT USE FOR: refactoring, writing a script from scratch, or debugging
  business logic (use write-code); code review (use pr-review); general programming
  concepts with no upstream docs (use engineering-os).
license: MIT
metadata:
  version: 2.0.0
---

## Purpose

The procedure for grounding an answer in real documentation.

The *mandate* — that library questions are answered from fetched docs rather than training
data, including when the model is confident — is always-on and lives in
[`../../rules/doc-lookup.md`](../../rules/doc-lookup.md). This skill is how that mandate is
carried out, and what to do when it cannot be.

Resolve every `CAP:` reference via
[`../../_shared/capabilities.md`](../../_shared/capabilities.md).

## Step 1 — Extract the library and the full question

Pull out two things:

- **The library name**, as the user wrote it. Keep the version if they named one
  (`Next.js 15`, `Prisma 6`, `react-router v7`).
- **The user's complete question**, not a keyword reduction of it.

Hold on to the full question. It is the query in Step 2, and compressing it to a bare
package name is the single most common cause of a shallow or wrong answer.

## Step 2 — Resolve the library id

**Read the resolver's actual schema before calling it.** Resolvers are narrow: the
Context7 one accepts a single `libraryName` and nothing else, so "pass the full question
as the query" is not an option there and inventing a `query` argument fails the call.

| What you have | Where it goes |
|---|---|
| library name, with the version if the user gave one | the resolver's name/library field |
| the user's full question | **not here** — it goes to the fetch call in Step 4 |

If the resolver does accept a free-text search field, use the full question: it ranks
candidates better than a bare package name. Check, do not assume, in either direction.

If the capability is not loaded this session, search for it by function — "query library
documentation" — before concluding it is unavailable.

## Step 3 — Select the best match

Low freedom. Pick in this order:

1. An **exact name match**, or the nearest spelling variant.
2. The **official or primary package** over a community fork, mirror, re-publish or wrapper.
3. A **version-specific id** when the user named a version; otherwise the current one.
4. Widest documentation coverage among whatever still ties.

If two candidates are equally plausible and would yield materially different answers, name
the one chosen in a single clause of the final answer rather than stopping to ask.

## Step 4 — Fetch with the user's question

Fetch the docs for the chosen id and put the user's **specific question** in the fetch
call's topic/query field — this is where the full question belongs, not on the resolver.
A topic-scoped fetch returns the relevant section; an unscoped one returns a table of
contents.

If what comes back does not actually address the question, fetch once more with a narrower
topic before concluding the docs do not cover it.

## Step 5 — Answer from what came back

- Answer from the fetched material only.
- **Cite the library and the version** the documentation describes.
- Use the examples from the docs rather than reconstructing them from memory.
- If the docs contradict what you expected, the docs win — and say that they did.
- If the docs genuinely do not answer the question, state that rather than filling the gap
  silently.

## Step 6 — When documentation is unavailable

This step decides whether the answer is useful or confidently wrong.

If `CAP:DOCS` has no entry for the library, or the call fails, **say so in one line before
answering from anything else**:

> "No documentation entry for `foo-lib`; answering from the official docs site instead."

Then work down this chain, labelling the answer with the source it actually came from:

| Order | Source | Label it as |
|---|---|---|
| 1 | `CAP:DOCS` | fetched documentation, with the version |
| 2 | `CAP:WEB` on the **official documentation domain** | the docs site, with the URL |
| 3 | Model knowledge | "from model knowledge, may be out of date" |

**Never present model recall as though it came from the documentation.** Not as a
paraphrase, not as an unattributed code sample, not by dropping the label because the
answer is probably right. An unlabelled wrong answer gets shipped; a labelled one gets
checked. Confidence is not evidence, and "this part of the API is stable" is not an
exception.

Do not substitute a general web search for the official domain while the official domain is
reachable. Blog posts and answer sites carry version drift that the docs do not.

## Related skills

| Situation | Skill |
|---|---|
| Implementing against the library once the docs are read | `write-code` |
| Testing code that calls the library | `write-tests` |
| General engineering rules, with no upstream docs to fetch | `engineering-os` |
| Reviewing someone else's use of a library | `pr-review` |

## Rules

- Pass the user's full question to the **fetch** call's topic field; pass the resolver
  only the fields its schema declares. Never invent an argument a tool does not accept.
- Cite the library and version in the answer; an uncited answer is indistinguishable from recall.
- Prefer official or primary packages over forks and mirrors when selecting a match.
- Scope the fetch to the user's question, not to the library name.
- State the unavailability of documentation in one line *before* the answer, never after it.
- Label every answer that did not come from fetched documentation with its real source.
- Never present model knowledge as documentation, regardless of confidence.
- Never answer a version-specific question from an unversioned source without saying so.

## Completion criteria

Done when the answer is grounded in fetched documentation with the library and version
cited, or the unavailability of documentation has been stated explicitly before answering
from another source.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_GLOBAL}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates the lookup procedure onto the
  always-on mandate in `rules/doc-lookup.md`, and adds the previously missing
  documentation-unavailable fallback chain and source-labelling requirement.
- 2.0.0 (2026-10-20) — The full question goes to the fetch call's topic field, not to the
  resolver: the connected resolver accepts only `libraryName`, so the previous rule
  produced an invalid call (B41).

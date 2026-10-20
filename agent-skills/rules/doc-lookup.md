# Library documentation comes from the docs

Questions about a library, framework, SDK, API, CLI, or cloud service — **including
well-known ones, and including when you are confident you know the answer** — are
answered from fetched documentation via `CAP:DOCS`, not from model knowledge.

Training data for a fast-moving library is a snapshot of a version nobody is running.

## Applies to

- Setup and configuration questions
- Code that calls a named library
- API/method references, parameters, return shapes
- Version-specific behaviour and migration questions

## Does not apply to

General programming concepts, the project's own code, algorithm design, debugging
business logic, or refactoring — none of those have upstream docs to fetch.

## Procedure

Use the [`doc-lookup`](../skills/doc-lookup/SKILL.md) skill. Short form: resolve the
library ID with the library name, fetch with the user's actual question as the topic,
answer from what comes back, and name the version.

## The honesty clause

If `CAP:DOCS` has no entry for the library, or the call fails, **say so in one line
before answering from anything else.** Never present model recall as though it came from
the documentation.

> "Context7 has no entry for `foo-lib`; the following is from model knowledge and may be
> out of date."

That single line is the difference between a useful answer and a confident wrong one.

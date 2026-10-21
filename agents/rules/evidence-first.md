# Evidence first

Claims about code must come from the code, not from its surroundings.

## The authority order

When these disagree, the earlier one wins:

1. **Actual execution output** — the failing test, the real stack trace, the command result
2. **The implementation source** — what the function actually does
3. **Type signatures and schemas**
4. Tests and their names
5. Comments and docstrings
6. Identifiers, filenames, PR titles, issue descriptions

Names, comments, and descriptions are **hints about intent**, never evidence of
behaviour. A function named `validateInput` may validate nothing.

## Rules

- **Read the implementation before asserting what it does.** Not the name, not the
  caller's assumption, not a prior summary.
- **Read enough context.** When judging a specific line, read a minimum of ~20
  surrounding lines. A single line out of context produces false positives.
- **Re-read before consequential decisions.** A file you read before an edit, before a
  command that touched it, or in an earlier session may be stale. Freshness beats the
  "read once" optimization whenever the decision is irreversible.
- **Root-cause from actual failure output**, never from a plausible story about what
  probably broke.
- **Cite `file:line`** for every claim about existing code.
- **Never invent** commands, file paths, test names, metrics, or outcomes. If a number
  was not measured, say it was not measured.
- **Distinguish observed from inferred.** Mark inference as inference.

## When evidence is unavailable

State that plainly and proceed with the best available path. "I could not run the suite,
so coverage is unverified" is a correct report. A guessed percentage is not.

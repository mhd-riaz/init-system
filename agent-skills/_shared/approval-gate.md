# Approval gates

A gate is a hard stop that waits for the user. Six skills in this bundle define one;
this file holds the shared mechanics so each skill states only its own trigger and text.

## The contract

1. **Present, then stop.** The work that follows the gate must not begin — not
   partially, not speculatively, not "to save time if they say yes".
2. **Show what will change**, concretely: files, scope, destructive effects, cost.
3. **Offer numbered options with a marked default.**
4. **Batch every clarifying question into this single round.** Do not interrogate across
   multiple turns.
5. **Wait for an explicit answer.** Silence, a vague "ok cool", or a new unrelated
   message is not approval.

## Standard form

```
<One line: what is about to happen>

<The concrete change: files / items / scope>

  1. ✅ Proceed as described  (default)
  2. ✏️  Proceed with changes — tell me what to adjust
  3. ❌ Stop here

Which?
```

Use `CAP:ASK` when available so the options render as a form. Otherwise print the block
as prose. The content is identical either way.

## Where gates are mandatory

| Situation | Skill | Why |
|---|---|---|
| Before writing or editing any code | `write-code` | design approval precedes implementation |
| Before posting review comments to a PR | `pr-review` | comments are public and attributed |
| Before modifying a pre-existing passing test | `write-tests` | silent test changes hide regressions |
| Before pushing commits or editing a PR branch | `resolve-pr` | shared-branch mutation |
| Before creating or updating a tracker item | `ado-item`, `gh-issue` | visible to the team |
| Before applying any proposed skill edit | `skill-retrospective` | proposals are never auto-applied |

## Irreversibility rule

Before any action that is destructive, public, or hard to undo — pushing, posting,
deleting, assigning, closing, force-writing — **show the target and get confirmation.**

State it as a prohibition with its reason, so the shortcut is closed:

> Never post without showing the user the exact comments first. A posted review comment
> is attributed to them and cannot be silently retracted.

## What does not need a gate

Reading, searching, analysing, running tests locally, and producing a draft for review.
Gating cheap reversible work makes the agent annoying rather than safe.

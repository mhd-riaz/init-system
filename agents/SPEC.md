# Skill Spec — the authoring contract for this bundle

Read before adding or editing any skill. Not auto-loaded; open on demand.

This spec merges five lineages: the governance model from `~/.copilot/skills/SKILL_SPEC.md`,
context economics and the resource taxonomy from OpenAI's `skill-creator`, signal-based
routing from Microsoft's `deploy-model`, prohibition-writing from `~/.claude/rules/`, and
the `USE FOR` / `DO NOT USE FOR` boundary convention from `microsoft-foundry`.

---

## 1. Layout

```
agents/
├── SPEC.md            this file — the contract
├── INDEX.md           map of the bundle (plain .md, never auto-discovered)
├── AUDIT-LOG.md       dated findings; changelog entries cite these IDs
├── README.md          human-facing install guide (never loaded by an agent)
├── install.sh         interactive installer front end
├── rules/             always-on policies, tiny, provider-neutral
├── _shared/           procedures referenced by 2+ skills, no frontmatter
├── templates/         output templates skills emit verbatim
├── agent-tools/       validate.py, install.sh, selftest.sh
└── skills/<name>/SKILL.md
```

- One skill = one directory under `skills/<kebab-case-name>/` containing exactly one
  auto-discovered file: `SKILL.md`. Lowercase, no exceptions.
- `<kebab-case-name>` must equal the frontmatter `name:` field exactly.
- A leading `_` prevents auto-discovery. That is the retirement mechanism: move a skill
  to `_archive/` rather than deleting it.
- Files under `_shared/` and `rules/` carry **no frontmatter** — they are never skills.

### Skill naming

Lowercase letters, digits, hyphens. Max 64 chars. No leading/trailing hyphen, no `--`.
Prefer short verb-led phrases. Namespace by tool when it improves triggering
(`ado-item`, `gh-issue`), not when it doesn't (`write-code`, not `vscode-write-code`).

---

## 2. Frontmatter — portable subset only

```yaml
---
name: <kebab-case-name>
description: >
  <1-2 sentences: what this does.> USE FOR: <concrete trigger phrases, comma
  separated>. DO NOT USE FOR: <phrases that belong to a named sibling> (use <sibling>).
license: MIT
metadata:
  version: <MAJOR.MINOR.PATCH>
---
```

**Only these five keys are permitted:** `name`, `description`, `license`,
`allowed-tools`, `metadata`.

This is the intersection of every target provider. OpenAI Codex's validator rejects
anything else outright — a top-level `version:` key fails with *"Unexpected key(s) in
SKILL.md frontmatter"*. Version therefore lives at `metadata.version`.

`description` must not contain angle brackets `<` or `>` — Codex's validator rejects them.
Write `AB#id`, not `AB#<id>`, inside a description.

### Both boundaries are mandatory

A skill without a stated negative boundary is incomplete, not merely terse. `DO NOT USE
FOR` must **name the sibling skill** that owns the excluded territory, rather than
describing it. If two skills feel like they overlap, that is a bug.

### Description budget: 600 characters, hard cap

The description is the only part of a skill loaded into *every* session whether or not
the skill is used. It is an advert, not documentation: its single job is to let the model
pick this skill over a sibling. Anything that does not change that choice — how the
workflow operates, what it enforces, its caveats — belongs in the body, which is read on
demand and costs nothing until needed.

- Hard cap 600 chars (~150 tokens). Prefer ~480.
- Keep every concrete trigger phrase. Cut prose, not triggers.
- Upstream measurement: skill adverts cost 2,512 tokens per session across 185 recorded
  sessions before the user typed anything. Descriptions are the dominant recurring cost
  of a bundle; bodies are not.

> Codex permits 1024 chars. This bundle caps at 600 deliberately. Stay at 600.

### Triggers go in the description, never the body

The body is only loaded *after* the skill triggers. A `## When to use this skill` section
in the body can never influence triggering and is pure waste. Delete it on sight.

---

## 3. Required body sections, in this order

1. `## Purpose` — the literal heading. Prose alone does not satisfy this.
2. The workflow itself — numbered steps, verb-led, imperative.
3. `## Related skills` — table of situation → sibling skill, for every skill this one
   hands off to or receives from.
4. `## Rules` — imperative, checkable statements only. A qualifier may follow
   (`## Rules (token discipline)`), but the heading must start with `## Rules`.
5. `## Completion criteria` — the exact checkable condition(s) that mark the task done.
6. `## Outcome logging` — one line referencing `_shared/outcome-log.md`. Never inline
   the schema; it is duplicated across every skill otherwise.
7. `## Changelog` — dated entries, **oldest first, newest appended last**, each citing
   the evidence or `AUDIT-LOG.md` finding ID that justified it.

### Symmetry rule

If skill A's `## Related skills` lists B, and B's `DO NOT USE FOR` excludes A's use case,
then A must appear in B's table too. Boundaries are mutual or they are wrong.

---

## 4. Body budget and progressive disclosure

Three loading levels:

| Level | Loaded | Budget |
|---|---|---|
| `name` + `description` | always, every session | **600 chars** |
| `SKILL.md` body | on trigger | **< 500 lines** |
| `references/`, `scripts/`, `assets/`, `_shared/` | on demand | unlimited |

When a skill approaches 500 lines, split variant-specific detail into `references/` and
leave the core workflow plus selection guidance in `SKILL.md`.

### Resource taxonomy — classified by how it enters context

| Dir | Enters context? | Use for |
|---|---|---|
| `scripts/` | **No** — executed, not read | deterministic repeated operations |
| `references/` | **Yes** — read on demand | schemas, API docs, domain knowledge |
| `assets/` | **Never** — used in output | templates, boilerplate, fonts |
| `_shared/` | **Yes** — read on demand | procedures used by 2+ skills |

### Anti-duplication rule

Information lives in **either** `SKILL.md` **or** a reference file, never both. Prefer
the reference file unless the content is truly core. If the same procedure appears in two
skills, extract it to `_shared/` and link it from both — do not copy it.

### Scale rules

- Reference file > 100 lines → table of contents at the top.
- Reference file > 10k words → put grep patterns in `SKILL.md`.
- References stay **one level deep** from `SKILL.md`. Never nest.

### Do not ship

No `README.md`, `INSTALLATION_GUIDE.md`, `QUICK_REFERENCE.md`, or `CHANGELOG.md` *inside*
a skill directory. A skill contains only what an agent needs to do the job — not the
story of how it was built.

---

## 5. Degrees of freedom

Match specificity to the task's fragility. A narrow bridge with cliffs needs guardrails;
an open field allows many routes.

| Freedom | Form | Use when |
|---|---|---|
| **High** | prose guidance | multiple valid approaches, context decides |
| **Medium** | pseudocode, parameterized steps | a preferred pattern exists, variance OK |
| **Low** | exact commands, fixed sequence | fragile, error-prone, consistency critical |

Field mappings, ID formats, and destructive operations are low-freedom. Design and
analysis are high-freedom. State which one a step is when it is not obvious.

---

## 6. Writing rules

**Assume the reader is a competent agent with no memory of this project.** Include what
is non-obvious and project-specific. Omit what any capable model already knows.

> The context window is a public good. Challenge every paragraph: does this justify its
> token cost? Would a competent agent already do this without being told?

- Imperative mood throughout. "Read the file", not "You should read the file".
- Prefer a concise example over a verbose explanation.
- Tables over prose for any mapping.
- Never name a provider-specific tool. Use a capability from
  [`_shared/capabilities.md`](_shared/capabilities.md). This is what makes the bundle
  portable; violating it silently breaks the skill on three of five providers.
- Never hardcode an absolute path. Use the placeholders in §8.
- Never name a specific model (`"Claude Sonnet 5.5"`). Describe the tier needed instead.

### Writing a prohibition

A rule that is merely stated gets rationalized away. A prohibition must carry four parts:

1. **The prohibition**, unambiguous and scoped.
2. **The reason**, which closes the clever workaround — *"a grep hit prints the line,
   and the line is the secret."*
3. **Both directions**: explicit (someone asks) and implicit (the agent decides it would
   help). Pre-refute the rationalizations: *"it would be faster" and "I only need one
   line" are not exceptions.*
4. **The alternative** — a priority-ordered list of what to do instead. A refusal with no
   path forward gets worked around.

### Writing a gate

A gate is a hard stop awaiting user input. Ship the **literal text to present**, not a
description of it. Mark the default option. State explicitly what must not happen before
the gate clears.

### Writing a router

A routing table needs a **Reason** column — it teaches the rule so the agent generalizes
to phrasings not in the table. Route on *signals* (modifier words, flags, detected
state), not on topic. Every router must name a **default for ambiguity**; ambiguity that
resolves into a question to the user is a router that failed.

---

## 7. Versioning

Defined by whether a change would flip a prior pass/fail verdict:

- **MAJOR** — a Rule or step is removed or reversed.
- **MINOR** — a Rule, step, example, or section is added; no existing verdict changes.
- **PATCH** — wording, typo, or cross-reference fixes only.

Never bump a version with an unattributed rewording. Cite the correction, session, or
`AUDIT-LOG.md` finding ID that justified it. If you cite an ID that is not in
`AUDIT-LOG.md`, add it there first.

---

## 8. Portability requirements

Every skill must satisfy all five:

1. **Capabilities, not tool names.** Reference `CAP:` identifiers from
   [`_shared/capabilities.md`](_shared/capabilities.md). If a capability is unavailable,
   follow the degradation chain defined there.
2. **Placeholders, not paths.** Use `{{STATE_GLOBAL}}`, `{{STATE_REPO}}`,
   `{{SKILLS_DIR}}`. The installer resolves them per provider.
3. **No model names.** Say "a fast/cheap tier model" or "the main model", never a
   product string.
4. **Portable frontmatter only** — the five keys in §2.
5. **Degrade, never fail.** If a capability is missing, state the limitation in one line
   and continue with the best available path. Never silently skip a step.

| Placeholder | Resolves to |
|---|---|
| `{{STATE_GLOBAL}}` | cross-repo agent state (`~/.agent/state/`) |
| `{{STATE_REPO}}` | per-repo agent state (`<repo>/.agent/`, gitignored) |
| `{{SKILLS_DIR}}` | the installed root of this bundle |

---

## 9. Enforceable check

A spec is worth only as much as the check that enforces it.

```sh
python3 agent-tools/validate.py            # must print "0 non-compliant"
```

It verifies: the five frontmatter keys, both boundaries present, the 600-char cap,
angle brackets, name/folder agreement, all required headings in order, the 500-line body
budget, hardcoded paths, banned provider tool names, that every relative Markdown link
resolves on disk, and that every `CAP:` identifier is defined in
[`_shared/capabilities.md`](_shared/capabilities.md).

**It checks structure, not behaviour.** `0 non-compliant` means the bundle is shaped
correctly and its references resolve; it says nothing about whether a workflow works.

**The documented trap:** a naive search for `USE FOR:` also matches inside
`DO NOT USE FOR:`, so it reports every skill as compliant while some have no positive
triggers at all. The positive-only form is:

```sh
grep -LE '(^|[^T] )USE FOR:' skills/*/SKILL.md
```

`validate.py` already avoids this trap. If you write your own check, do not re-introduce it.

---

## 10. Build process

1. **Understand** — collect concrete examples. "What would a user say that triggers
   this?" Batch clarifying questions into a single round; do not interrogate.
2. **Plan resources** — decide what belongs in `scripts/`, `references/`, `_shared/`.
3. **Initialize** — copy `templates/SKILL.template.md`.
4. **Write** — resources first, then `SKILL.md`.
5. **Validate** — `python3 agent-tools/validate.py` must print `0 non-compliant`.
6. **Iterate from real usage** — not from imagination. Use it, notice the struggle,
   fix the skill, bump the version citing the evidence.

Any script shipped in `scripts/` must be executed at least once before being committed.

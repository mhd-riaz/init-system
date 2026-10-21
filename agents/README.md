# agent-skills

A portable skill bundle for AI coding agents. One source of truth, installed into
Claude Code, OpenAI Codex, Copilot CLI, VS Code, and any `AGENTS.md` consumer
(Cursor, Windsurf, Amp).

Skills encode *how I want an agent to work* — approval before implementation, evidence
before claims, documentation before recall — in a form that survives changing providers.

## Install

```sh
git clone <this-repo> ~/repos/agent-skills
cd ~/repos/agent-skills
./agent-tools/install.sh --dry-run        # see what would happen
./agent-tools/install.sh                  # symlink into every provider
```

Symlinks mean editing a skill here updates every provider immediately. Use
`--mode copy` for isolated copies instead.

**The installer never deletes anything.** An existing file is skipped with a warning;
`--force` moves it to `<name>.bak-<timestamp>` first.

| Flag | Effect |
|---|---|
| `--providers claude,codex` | install a subset |
| `--mode copy` | copy instead of symlink |
| `--dry-run` | print actions without performing them |
| `--force` | back up and replace existing entries |

Provider directories move between releases. Override without editing the script:

```sh
CLAUDE_HOME=~/.config/claude VSCODE_SKILLS_DIR=~/somewhere ./agent-tools/install.sh
```

Skills install into each provider's skills directory; `rules/` is inlined into the one
always-on entry point each provider actually discovers — `CLAUDE.md`, `AGENTS.md`,
`copilot-instructions.md`, or a VS Code user `*.instructions.md`. Copy mode also copies
`_shared/`, `templates/` and `rules/` beside the skills directory, because a skill's
`../../_shared/...` reference resolves through a symlink but not through a copy.

Restart your agent after installing so it picks up new skills.

## What's inside

| | |
|---|---|
| `skills/` | 13 workflow skills, auto-discovered by the agent |
| `rules/` | always-on policies — secrets, context, evidence, docs, paths, repo config |
| `_shared/` | procedures referenced by multiple skills, linked never duplicated |
| `SPEC.md` | the authoring contract |
| `INDEX.md` | map of the bundle — **start here** |
| `AUDIT-LOG.md` | the findings that justify each design decision |

## Design

Three constraints shaped it:

**Portable.** No skill names a provider's tool. They name capabilities — `CAP:DOCS`,
`CAP:SUBAGENT`, `CAP:TEST-RUN` — resolved at runtime through
[`_shared/capabilities.md`](_shared/capabilities.md), each with a degradation chain so a
missing tool downgrades rather than fails. Frontmatter uses only the five keys every
provider accepts.

**Not duplicated.** Outcome logging was previously repeated near-verbatim across ten
skills; approval gates across six; coverage thresholds across four. Each lives once in
`_shared/` and is linked. Information lives in one place or it drifts.

**Not dumbed down.** Every specific convention is preserved exactly — coverage targets,
the PR title format and its 59-character limit, HTML-not-Markdown for Azure DevOps rich
text, the five scenario classes, ISO-8601 UTC timestamps. Compression removed repetition,
not knowledge.

## Adding a skill

Use the `skill-creator` skill, or by hand:

```sh
cp templates/SKILL.template.md skills/my-skill/SKILL.md
# edit it against SPEC.md
python3 agent-tools/validate.py           # must print "0 non-compliant"
```

`validate.py` checks frontmatter keys, the 600-character description cap, both
`USE FOR` / `DO NOT USE FOR` boundaries, name/folder agreement, all required headings in
order, the 500-line body budget, every non-portable pattern, that relative links resolve,
and that every `CAP:` identifier is defined. It validates structure, not behaviour.

## License

MIT.

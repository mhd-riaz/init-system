# agents — the skill bundle

A portable skill bundle for AI coding agents. One source of truth, installed into
Claude Code, OpenAI Codex, Copilot CLI, VS Code, and any `AGENTS.md` consumer
(Cursor, Windsurf, Amp).

Skills encode *how I want an agent to work* — approval before implementation, evidence
before claims, documentation before recall — in a form that survives changing providers.

This is one half of [`init-system`](../README.md); the other half, `settings/`, configures
the machine the agent runs on.

## Install

```sh
git clone git@github.com:mhd-riaz/init-system.git ~/repos/init-system
cd ~/repos/init-system/agents
./install.sh                              # interactive: pick providers and keep-or-replace
```

`install.sh` reports the detected OS (macOS, Linux, WSL, Windows under Git Bash), shows a
space-bar checklist of providers, asks whether to keep or replace existing files, installs,
then prints a verified summary of what landed where. Prefer flags? They pass straight through
to the non-interactive `agent-tools/install.sh`:

```sh
./install.sh --dry-run                    # see what would happen
./install.sh --providers claude,codex     # skip the questions entirely
```

Symlinks mean editing a skill here updates every provider immediately. Use
`--mode copy` for isolated copies instead.

**The installer never deletes anything.** An existing file is skipped with a warning;
`--force` (or choosing *replace*) moves it to `<name>.bak-<timestamp>` first.

| Flag | Effect |
|---|---|
| `--providers claude,codex` | install a subset |
| `--mode copy` | copy instead of symlink |
| `--dry-run` | print actions without performing them |
| `--force` | back up and replace existing entries |

| Provider | Skills | Always-on entry point |
|---|---|---|
| `claude` | `~/.claude/skills` | `~/.claude/CLAUDE.md` |
| `codex` | `~/.codex/skills` and `~/.agents/skills` | `~/.codex/AGENTS.md` |
| `copilot-cli` | `~/.copilot/skills` | `~/.copilot/copilot-instructions.md` |
| `vscode` | `~/.config/github-copilot/skills` | user `prompts/agent-rules.instructions.md` |
| `gemini` | `~/.gemini/skills` | `~/.gemini/GEMINI.md` |
| `agents-md` | — | `~/AGENTS.md` |

The hosted chat UIs (claude.ai, chatgpt.com, gemini.google.com) have no local skills
directory — upload skills there by hand.

Provider directories move between releases. Override without editing the script:

```sh
CLAUDE_HOME=~/.config/claude VSCODE_SKILLS_DIR=~/somewhere ./install.sh
```

Skills install into each provider's skills directory; `rules/` is inlined into the one
always-on entry point each provider actually discovers — `CLAUDE.md`, `AGENTS.md`,
`copilot-instructions.md`, or a VS Code user `*.instructions.md`. Copy mode also copies
`_shared/`, `templates/`, `rules/` and `agent-tools/` beside the skills directory, because a
skill's `../../_shared/...` reference resolves through a symlink but not through a copy.

Restart your agent after installing so it picks up new skills.

## What's inside

| | |
|---|---|
| `skills/` | 13 workflow skills, auto-discovered by the agent |
| `rules/` | always-on policies — secrets, context, evidence, docs, paths, repo config |
| `_shared/` | procedures referenced by multiple skills, linked never duplicated |
| `agent-tools/` | runnable scripts the agent executes instead of re-deriving facts — [index](agent-tools/README.md) |
| `templates/` | starting points for a new skill and a repo's `.agent/config.yml` |
| `install.sh` | interactive front end for `agent-tools/install.sh` |
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

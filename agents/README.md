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
git clone https://github.com/mhd-riaz/init-system.git
cd init-system/agents
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

## Example: GitHub Copilot, start to finish

Copilot is two separate targets — the CLI and VS Code. Install both:

```sh
cd init-system/agents
./install.sh
```

**Step 1 — providers.** Arrow keys move, space toggles, enter confirms. Everything is
checked by default, so space-off the ones you do not use and leave these two on:

```
  > [x] copilot-cli   GitHub Copilot CLI    ~/.copilot/skills + copilot-instructions.md
    [x] vscode        VS Code Copilot       Copilot skills dir + user .instructions.md
```

**Step 2 — existing files.** Answer `1` the first time (nothing is there to clash with).
Answer `2` on a re-install **only** when you want the generated instructions file
refreshed — it backs the old one up to `<name>.bak-<timestamp>` before overwriting.

```
  1) keep them  - add only what is missing, touch nothing else (default)
  2) replace    - back up each one to <name>.bak-<timestamp>, then overwrite
choice [1]: 1
```

**Step 3 — read the summary.** Every target must say `ok`; a `MISSING` exits non-zero.

```
  skills    ok         /Users/you/.copilot/skills  (13/13 skills)
  generate  ok         /Users/you/.copilot/copilot-instructions.md
  skills    ok         /Users/you/.config/github-copilot/skills  (13/13 skills)
  generate  ok         /Users/you/Library/Application Support/Code/User/prompts/agent-rules.instructions.md
```

Prefer no prompts? The same thing in one line, and a dry run first:

```sh
./install.sh --providers copilot-cli,vscode --dry-run
./install.sh --providers copilot-cli,vscode
```

**Step 4 — restart Copilot** (quit the CLI, reload the VS Code window). Skills are read
at startup.

**Step 5 — check it took.** Ask Copilot *"which skills do you have?"*, or look directly:

```sh
ls ~/.copilot/skills                      # 13 symlinks back into this repo
head -20 ~/.copilot/copilot-instructions.md
```

The generated instructions file is `rules/` inlined plus the skill list — regenerated,
never hand-edited. Change a rule here and re-run with `--force`.

## Per-repository config

Skill defaults are deliberately generic. A repository overrides them with
`.agent/config.yml`, which every skill reads before doing anything
([`rules/repo-config.md`](rules/repo-config.md)). Without it, a skill guesses from the
git remote — and the remote is wrong whenever code and work items live in different
systems, like a GitHub repo whose tickets are in Azure DevOps.

```sh
mkdir -p .agent
cp ~/path/to/init-system/agents/templates/agent-config.template.yml .agent/config.yml
```

Every section is optional; delete what does not apply. A minimal GitHub-issues repo:

```yaml
version: 1

tracker:
  system: github                  # ado | github | none
  commit_prefix: "#{id} "
  pr_body_reference: "Closes #{id}"

code_host:
  system: github
  owner: your-org
  repo: your-repo
  default_branch: main

testing:
  command: ./unit-test.sh
  coverage:
    backend: 90
    frontend: 80
```

The keys worth knowing:

| Key | Why you would set it |
|---|---|
| `tracker.system` | where work items live. `none` silently skips every work-item step |
| `code_host` | where branches, PRs and CI live, when it differs from the tracker |
| `testing.command` | the test entry point, so no skill has to guess the runner |
| `testing.coverage` | project thresholds, which outrank the skill defaults |
| `skills.disabled` | a listed skill declines in one line instead of running |
| `devlog` | skips devlog path discovery entirely |
| `identity` | who new work is assigned to |

`.agent/` is gitignored here; commit it in your own repos so the whole team gets the
same behaviour. Full schema with every key:
[`_shared/repo-config.md`](_shared/repo-config.md).

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

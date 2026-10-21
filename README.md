# init-system

Setting up a new machine, in one repo: the skill bundle my AI coding agents run on,
and the shell, git and editor configuration I expect underneath them.

Every piece follows the same contract — a checked-in source file, an installer that
renders it, a `--dry-run` that shows the result first, a backup of anything it
replaces, and a verification pass before it goes live. No installer deletes anything.
Nothing secret is stored here.

## Start here

```sh
git clone https://github.com/mhd-riaz/init-system.git
cd init-system

cd settings/terminal   && ./install.sh    # ~/.zshrc
cd ../git-config       && ./install.sh    # ~/.gitconfig + SSH identities
cd ../../agents        && ./install.sh    # skills into every AI agent you use
```

Add `--dry-run` to any of them to see what would happen. Edit the placeholders in
`settings/git-config/gitconfig.yaml` before running that one — it refuses to generate
while an account still says `example.com`.

## Layout

| Path | What it is |
|---|---|
| [`agents/`](agents/README.md) | portable skill bundle — 13 workflow skills, always-on rules, shared procedures, and the scripts agents run instead of re-deriving facts. Installs into Claude Code, Codex, Copilot CLI, VS Code, Gemini, or any `AGENTS.md` reader |
| [`settings/`](settings/README.md) | machine configuration — `~/.zshrc`, multi-account git with per-directory identity switching, VS Code settings |

Each directory's README is the detailed guide. [`agents/INDEX.md`](agents/INDEX.md) maps
the bundle; read it before opening individual skills.

## Conventions

- **Sources are checked in, outputs are generated.** Edit `zshrc.yaml`, not `~/.zshrc`;
  edit `gitconfig.yaml`, not `~/.gitconfig`; edit a `SKILL.md` here, not the copy in
  `~/.claude/skills`. Re-run the installer.
- **Non-destructive by default.** An existing file is left alone with a warning;
  `--force` (agents) or a replace prompt (settings) moves it to
  `<name>.bak-<timestamp>` first.
- **Symlinks for the agent bundle.** Editing a skill here updates every provider
  immediately — but the links point at this checkout, so clone it somewhere permanent or
  re-run the installer after moving it. `--mode copy` gives isolated copies instead.
- **Every claim in these docs is checkable.** `cd agents && python3
  agent-tools/validate.py` must print `0 non-compliant`, and
  `agent-tools/selftest.sh` must pass, before anything is committed.

# settings

Machine configuration: shell, git identities, editor. Each directory holds a
checked-in source file and an installer that renders it — edit the source, re-run
the installer, never hand-edit the generated file.

| Directory | Source | Generates |
|---|---|---|
| `git-config/` | `gitconfig.yaml` | `~/.gitconfig`, `~/.gitconfig-<account>`, `~/.ssh/config` block, `~/.ssh/allowed_signers` |
| `terminal/` | `zshrc.yaml` | `~/.zshrc` |
| `vscode/` | `settings.json` | nothing — copy it in by hand |

Both installers share the same contract: detect the OS (macOS, Linux, WSL, Windows
under Git Bash), check the tools each enabled feature needs and print the install
command for your OS when one is missing, verify the generated file before it goes
live, and keep the previous one as `<name>.bak-<timestamp>`. Nothing secret is ever
written into this repository.

```sh
./install.sh --dry-run      # print the result, write nothing, ask nothing
./install.sh                # write it
./install.sh --yes          # never prompt; warn instead of waiting
./install.sh --config FILE  # read a different source file
```

## git-config

Multi-account git. One entry per GitHub account in `gitconfig.yaml`; the installer
renders an `includeIf` rule per account so identity, SSH key and commit signing switch
by directory or remote URL. `git config --show-origin user.email` in any repo tells you
which file won.

**Edit the placeholders before the first run** — a real run refuses to generate while an
address still says `example.com` (a dry run only warns). Set `default_account`, then per
account: `name`, `email`, `ssh.alias`, `ssh.key`, and the `match.dirs` that account owns.

`auth.method: ssh` is the recommended path (one key per account, any number of accounts
on one host). `netrc` matches on machine name alone, so it cannot tell two accounts on
the same host apart.

The installer prints the one-off steps only you can do — adding a public key to GitHub,
pasting a token. It also generates the `ignoreRootList` for the `git-autoconfig` VS Code
extension so the extension and the `includeIf` rules stay out of each other's way.

`--help` lists all flags. `GITCONFIG_OUT` and `SSH_DIR` override the output paths.

## terminal

`~/.zshrc` from `zshrc.yaml`: PATH, Oh My Zsh (theme, plugins, update cadence, history
stamps), Homebrew shellenv, per-tool blocks (nvm, Rancher Desktop, kubernetes, Go,
conda, VS Code shell integration), editor choice, a WSL block, env vars, aliases and
functions. `enabled: false` leaves a block out entirely; `raw:` appends anything the
schema does not model.

The result is checked with `zsh -n` before it replaces `~/.zshrc`.

Windows has no real zsh under Git Bash or MSYS2, so the Oh My Zsh theme cannot render
there — install WSL, run the installer inside it, and set `wsl.enabled: true`. The
installer says the same if you run it on Windows anyway.

`--output FILE` writes somewhere other than `~/.zshrc`.

## vscode

`settings.json` — formatter, format-on-save, fix-on-save for ESLint/TSLint/Stylelint,
icon theme, Emmet and file associations. No installer: open the VS Code command palette,
run **Preferences: Open User Settings (JSON)**, and merge what you want. It is a
reference, not a managed file, because user settings are usually already populated.

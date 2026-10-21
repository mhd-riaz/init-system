#!/usr/bin/env bash
# Generate ~/.zshrc from zshrc.yaml.
#
#   ./install.sh                 # detect the OS, check tools, write ~/.zshrc
#   ./install.sh --dry-run       # print the result, write nothing, ask nothing
#   ./install.sh --config FILE   # read another config  (default ./zshrc.yaml)
#   ./install.sh --output FILE   # write somewhere else (default ~/.zshrc)
#   ./install.sh --yes           # never prompt: stop on a missing required tool,
#                                # warn on a missing optional one
#
# Features are turned on and off in zshrc.yaml, never in here. For every feature
# that is on, this script checks the tool behind it and, when it is missing,
# prints the install command for the detected OS and waits for you to install it.
#
# Windows is a special case: Git Bash and MSYS2 have no real zsh, so the Oh My
# Zsh theme cannot render there. Running this on Windows explains how to move to
# WSL instead.
#
# The generated file is checked with `zsh -n` before anything is replaced, and
# the previous ~/.zshrc is kept as ~/.zshrc.bak-<timestamp>.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

CONFIG="zshrc.yaml"
OUT="$HOME/.zshrc"
DRY=0
YES=0
STAMP="$(date +%Y%m%d-%H%M%S)"

while [ $# -gt 0 ]; do
  case "$1" in
    --config)  CONFIG="$2"; shift 2 ;;
    --output)  OUT="$2"; shift 2 ;;
    --dry-run) DRY=1; YES=1; shift ;;
    -y|--yes)  YES=1; shift ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -t 0 ] || YES=1

info() { printf '  %s\n' "$1" >&2; }
warn() { printf '  !  %s\n' "$1" >&2; }
die()  { printf '\nerror: %s\n' "$1" >&2; exit 1; }

case "$(uname -s)" in
  Darwin)               OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  Linux)                OS=linux; grep -qi microsoft /proc/version 2>/dev/null && OS=wsl ;;
  *)                    OS="$(uname -s)" ;;
esac

# for_os <macos> <linux and wsl> <windows>
for_os() {
  case "$OS" in
    macos)   printf '%s' "$1" ;;
    windows) printf '%s' "$3" ;;
    *)       printf '%s' "$2" ;;
  esac
}

# ensure <label> <probe> required|optional <macos> <linux> <windows>
# Loops until the probe passes, the user skips an optional tool, or quits.
ensure() {
  local label="$1" probe="$2" req="$3" cmd ans
  cmd="$(for_os "$4" "$5" "$6")"
  while ! eval "$probe" >/dev/null 2>&1; do
    warn "$label is not installed"
    if [ -n "$cmd" ]; then printf '     install it on %s with:  %s\n' "$OS" "$cmd" >&2; fi
    if [ "$YES" -eq 1 ]; then
      if [ "$req" = required ]; then die "$label is required; install it and run this again"; fi
      warn "continuing without it (the generated file skips what is absent)"
      return 0
    fi
    if [ "$req" = required ]; then
      printf '     [enter] re-check    q) quit : ' >&2
    else
      printf '     [enter] re-check    s) skip    q) quit : ' >&2
    fi
    # Read the answer from the terminal: ensure() is called from inside `while
    # read` loops, whose stdin is the list being iterated, not the user.
    read -r ans </dev/tty || ans=q
    case "$ans" in
      q|Q) die "aborted, nothing was written" ;;
      s|S) if [ "$req" = optional ]; then warn "skipped $label"; return 0; fi ;;
    esac
  done
  return 0
}

# Windows ships no iTerm and no real zsh: Git Bash, MSYS2 and Cygwin all run a
# cut-down shell that cannot render an Oh My Zsh theme. WSL runs the generated
# file unchanged, so point people there before they install anything else.
windows_guidance() {
  [ "$OS" = windows ] || return 0
  local ans
  warn "this is a Windows shell (Git Bash / MSYS2 / Cygwin)"
  cat >&2 <<EOF
     Oh My Zsh themes need a real zsh, which Windows does not have. Use WSL:

       1. PowerShell (as admin):  wsl --install -d Ubuntu
       2. reboot, then open Ubuntu from Windows Terminal
       3. sudo apt update && sudo apt install -y zsh git curl
       4. chsh -s "\$(which zsh)"
       5. clone this repo inside WSL, set wsl.enabled: true in $CONFIG,
          then run ./install.sh from there

     Use Windows Terminal rather than the old console host: it renders the
     theme's colours and UTF-8 glyphs, conhost does not.
EOF
  if [ "$YES" -eq 1 ]; then
    warn "continuing anyway; the theme will not render in this shell"
    return 0
  fi
  printf '     [enter] stop and switch to WSL (recommended)    c) continue anyway : ' >&2
  read -r ans </dev/tty || ans=""
  case "$ans" in
    c|C) warn "continuing on Windows" ;;
    *)   echo "stopped. run this again from inside WSL." >&2; exit 0 ;;
  esac
}

# Progress goes to stderr so that `--dry-run > file` yields only the zshrc.
echo "detected: $OS ($(uname -m))" >&2
echo >&2
windows_guidance

# --- config ------------------------------------------------------------------
yq_ok() { command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qi mikefarah; }
ensure "yq (mikefarah/yq v4, used to read $CONFIG)" yq_ok required \
  "brew install yq" \
  "sudo snap install yq      # or: sudo apt-get install -y yq" \
  "winget install --id MikeFarah.yq"

[ -f "$CONFIG" ] || die "no config at $CONFIG"
yq '.' "$CONFIG" >/dev/null 2>&1 || die "$CONFIG is not valid YAML"
CONFIG_ABS="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
SELF="$(pwd)/$(basename "${BASH_SOURCE[0]}")"

on()    { [ "$(yq "$1 // false" "$CONFIG")" = "true" ]; }
str()   { local v; v="$(yq "$1 // \"\"" "$CONFIG")"; if [ "$v" = "null" ]; then v=""; fi; printf '%s' "$v"; }
items() { yq "$1 // [] | .[]" "$CONFIG"; }
keys()  { yq "$1 // {} | keys | .[]" "$CONFIG"; }
pairs() { yq "$1 // {} | to_entries | .[] | .key + \"=\" + .value" "$CONFIG"; }

# Config values keep "$HOME" lazy for zsh; tests in this script need it resolved.
expand() { local v="$1"; v="${v/#\~/$HOME}"; printf '%s' "${v//\$HOME/$HOME}"; }
# Alias bodies are emitted inside single quotes.
esc() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }
# emit <printf format> <value> - prints nothing when the value is empty
emit() { [ -n "${2:-}" ] || return 0; printf "$1\n" "$2"; }

# --- tools behind the enabled features ---------------------------------------
OMZ_INSTALL='sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
BREW_INSTALL='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

check_tools() {
  local omz plugin conda_prefix nvm_dir

  if [ "$OS" = wsl ] && ! on '.wsl.enabled'; then
    warn "this is WSL but wsl.enabled is false in $CONFIG"
    warn "turn it on for Windows interop (explorer.exe, clip.exe, \$BROWSER)"
  fi

  if [ "$OS" = wsl ] && on '.wsl.enabled' && [ "$(str '.wsl.browser')" = wslview ]; then
    ensure "wslu (provides wslview, used for \$BROWSER)" "command -v wslview" optional \
      "" "sudo apt-get install -y wslu" ""
  fi

  ensure "zsh" "command -v zsh" optional \
    "brew install zsh" "sudo apt-get install -y zsh" "pacman -S zsh    # MSYS2/Git Bash"

  if on '.oh_my_zsh.enabled'; then
    omz="$(expand "$(str '.oh_my_zsh.dir')")"
    ensure "Oh My Zsh ($omz)" "[ -d \"$omz\" ]" optional "$OMZ_INSTALL" "$OMZ_INSTALL" "$OMZ_INSTALL"
    if [ -d "$omz" ]; then
      while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        if [ -d "$omz/plugins/$plugin" ]; then continue; fi
        ensure "Oh My Zsh plugin '$plugin'" "[ -d \"$omz/custom/plugins/$plugin\" ]" optional \
          "git clone https://github.com/zsh-users/$plugin $omz/custom/plugins/$plugin" \
          "git clone https://github.com/zsh-users/$plugin $omz/custom/plugins/$plugin" \
          "git clone https://github.com/zsh-users/$plugin $omz/custom/plugins/$plugin"
      done < <(items '.oh_my_zsh.plugins')
    fi
  fi

  if on '.homebrew.enabled'; then
    ensure "Homebrew" "command -v brew" optional \
      "$BREW_INSTALL" "$BREW_INSTALL" "not available on Windows - set homebrew.enabled: false in $CONFIG"
  fi

  if on '.tools.nvm.enabled'; then
    nvm_dir="$(expand "$(str '.tools.nvm.dir')")"
    ensure "nvm" "[ -s \"$nvm_dir/nvm.sh\" ] || [ -s /opt/homebrew/opt/nvm/nvm.sh ] || [ -s /usr/local/opt/nvm/nvm.sh ]" optional \
      "brew install nvm" \
      "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash" \
      "nvm does not run under Windows zsh - set tools.nvm.enabled: false in $CONFIG"
  fi

  if on '.tools.rancher_desktop.enabled'; then
    ensure "Rancher Desktop (~/.rd/bin)" "[ -d \"$HOME/.rd/bin\" ]" optional \
      "brew install --cask rancher" \
      "see https://rancherdesktop.io/  (AppImage or .deb)" \
      "winget install --id SUSE.RancherDesktop"
  fi

  if on '.tools.kubernetes.enabled'; then
    ensure "kubectl" "command -v kubectl" optional \
      "brew install kubectl" "sudo snap install kubectl --classic" "winget install --id Kubernetes.kubectl"
  fi

  if on '.tools.go.enabled'; then
    ensure "Go" "command -v go" optional \
      "brew install go" "sudo snap install go --classic" "winget install --id GoLang.Go"
  fi

  if on '.tools.conda.enabled'; then
    conda_prefix="$(expand "$(str '.tools.conda.prefix')")"
    ensure "conda ($conda_prefix)" "[ -x \"$conda_prefix/bin/conda\" ]" optional \
      "brew install --cask miniconda" \
      "see https://docs.conda.io/projects/miniconda/en/latest/" \
      "winget install --id Anaconda.Miniconda3"
  fi

  if on '.tools.vscode_shell_integration.enabled'; then
    ensure "VS Code 'code' command" "command -v code" optional \
      "in VS Code: Cmd+Shift+P -> Shell Command: Install 'code' command in PATH" \
      "in VS Code: Ctrl+Shift+P -> Shell Command: Install 'code' command in PATH" \
      "winget install --id Microsoft.VisualStudioCode    # tick 'Add to PATH'"
  fi
}

# --- renderer ----------------------------------------------------------------
render() {
  local base append theme v f prefix group k p body

  printf '# ~/.zshrc - generated file, do not edit.\n'
  printf '# Source:    %s\n' "$CONFIG_ABS"
  printf '# Regenerate: %s\n' "$SELF"
  printf '# Written on %s on %s.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$OS"

  base="$(items '.path.base' | paste -sd: -)"
  if [ -n "$base" ]; then
    printf '\n# --- Base PATH (first, so every block below finds its binaries) ---\n'
    printf 'export PATH="%s"\n' "$base"
  fi

  if on '.oh_my_zsh.enabled'; then
    printf '\n# --- Oh My Zsh ---\n'
    emit 'export ZSH="%s"' "$(str '.oh_my_zsh.dir')"
    emit 'ZSH_THEME="%s"' "$(str '.oh_my_zsh.theme')"
    emit "zstyle ':omz:update' mode %s" "$(str '.oh_my_zsh.update.mode')"
    emit "zstyle ':omz:update' frequency %s" "$(str '.oh_my_zsh.update.frequency')"
    emit 'HIST_STAMPS="%s"' "$(str '.oh_my_zsh.hist_stamps')"
    if [ -n "$(items '.oh_my_zsh.plugins')" ]; then
      printf 'plugins=(\n'
      items '.oh_my_zsh.plugins' | sed 's/^/  /'
      printf ')\n'
    fi
    printf '# Absent on a fresh machine, so stay quiet when it is not there.\n'
    printf '%s\n' '[ -s "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"'
  fi

  if on '.homebrew.enabled'; then
    printf '\n# --- Homebrew (Apple Silicon prefix first, then Intel/Linux) ---\n'
    cat <<'EOF'
for brewbin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$brewbin" ] && eval "$("$brewbin" shellenv)" && break
done
unset brewbin
EOF
  fi

  if on '.tools.nvm.enabled'; then
    printf '\n# --- Node Version Manager ---\n'
    emit 'export NVM_DIR="%s"' "$(str '.tools.nvm.dir')"
    cat <<'EOF'
for nvmsh in "$NVM_DIR/nvm.sh" /opt/homebrew/opt/nvm/nvm.sh /usr/local/opt/nvm/nvm.sh; do
  [ -s "$nvmsh" ] && \. "$nvmsh" && break
done
unset nvmsh
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
EOF
  fi

  if on '.tools.rancher_desktop.enabled'; then
    printf '\n# --- Rancher Desktop (its shims go to the front of PATH) ---\n'
    printf '%s\n' '[ -d "$HOME/.rd/bin" ] && export PATH="$HOME/.rd/bin:$PATH"'
  fi

  if on '.tools.kubernetes.enabled'; then
    printf '\n# --- Kubernetes ---\n'
    emit 'export KUBECONFIG="%s"' "$(str '.tools.kubernetes.kubeconfig')"
  fi

  if on '.tools.go.enabled'; then
    printf '\n# --- Go ---\n'
    emit 'export GOPRIVATE="%s"' "$(str '.tools.go.goprivate')"
  fi

  if on '.editor.enabled'; then
    printf '\n# --- Preferred editor ---\n'
    printf 'if [[ -n $SSH_CONNECTION ]]; then\n'
    printf "  export EDITOR='%s'\n" "$(esc "$(str '.editor.ssh')")"
    printf 'else\n'
    printf "  export EDITOR='%s'\n" "$(esc "$(str '.editor.local')")"
    printf 'fi\n'
  fi

  if [ -n "$(yq '.env // [] | .[] | .name' "$CONFIG")" ]; then
    printf '\n# --- Environment ---\n'
    while IFS='=' read -r k v; do
      [ -n "$k" ] || continue
      printf 'export %s="%s"\n' "$k" "$v"
    done < <(yq '.env // [] | .[] | .name + "=" + .value' "$CONFIG")
  fi

  while IFS= read -r group; do
    [ -n "$group" ] || continue
    printf '\n# --- aliases: %s ---\n' "$group"
    while IFS='=' read -r k v; do
      [ -n "$k" ] || continue
      printf "alias %s='%s'\n" "$k" "$(esc "$v")"
    done < <(pairs ".aliases.\"$group\"")
  done < <(keys '.aliases')

  if on '.tools.kubernetes.enabled' && on '.tools.kubernetes.aliases'; then
    v="$(str '.tools.kubernetes.namespace')"
    if [ -n "$v" ]; then
      printf '\n# --- aliases: kubernetes (namespace from %s) ---\n' "$(basename "$CONFIG")"
      printf "alias pods='kubectl get pods -n %s'\n" "$v"
      printf "alias deployments='kubectl get deployments -n %s'\n" "$v"
      printf "alias jobs='kubectl get jobs -n %s'\n" "$v"
      printf "alias log='kubectl logs -n %s -f'\n" "$v"
    fi
  fi

  while IFS= read -r k; do
    [ -n "$k" ] || continue
    body="$(yq ".functions.\"$k\"" "$CONFIG")"
    printf '\n%s() {\n' "$k"
    printf '%s\n' "$body" | sed 's/^\(..*\)$/  \1/'
    printf '}\n'
  done < <(keys '.functions')

  if on '.tools.local_bin_env.enabled'; then
    f="$(str '.tools.local_bin_env.file')"
    if [ -n "$f" ]; then
      printf '\n# --- ~/.local/bin environment (uv and friends) ---\n'
      printf '[ -s "%s" ] && . "%s"\n' "$f" "$f"
    fi
  fi

  if on '.tools.conda.enabled'; then
    prefix="$(str '.tools.conda.prefix')"
    printf '\n# --- conda (block generated by `conda init`, kept config driven) ---\n'
    printf 'conda_prefix="%s"\n' "$prefix"
    cat <<'EOF'
__conda_setup="$("$conda_prefix/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
elif [ -f "$conda_prefix/etc/profile.d/conda.sh" ]; then
    . "$conda_prefix/etc/profile.d/conda.sh"
else
    export PATH="$conda_prefix/bin:$PATH"
fi
unset __conda_setup conda_prefix
EOF
    on '.tools.conda.auto_activate_base' || printf 'conda deactivate 2>/dev/null\n'
  fi

  if on '.wsl.enabled'; then
    printf '\n# --- WSL ---\n'
    printf '# WSL sets WSL_DISTRO_NAME, so the same config stays inert elsewhere.\n'
    printf '%s\n' 'if [[ -n "$WSL_DISTRO_NAME" ]]; then'
    v="$(items '.wsl.windows_path' | paste -sd: -)"
    if [ -n "$v" ]; then
      printf '  # The base PATH above replaces PATH outright, dropping everything WSL\n'
      printf '  # injected. Put back only what the interop commands below need.\n'
      printf '  export PATH="$PATH:%s"\n' "$v"
    fi
    v="$(str '.wsl.browser')"
    if [ -n "$v" ]; then
      printf '  # Guarded: wslu may not be installed yet (sudo apt install -y wslu).\n'
      printf '  command -v %s >/dev/null && export BROWSER="%s"\n' "$v" "$v"
    fi
    emit '  export WINHOME="%s"' "$(str '.wsl.win_home')"
    if on '.wsl.interop_aliases'; then
      cat <<'EOF'
  alias open='explorer.exe'
  alias pbcopy='clip.exe'
  # Get-Clipboard returns CRLF; drop the CR so pipes and $( ) behave.
  alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | tr -d "\r"'
EOF
    fi
    if on '.wsl.x11_display'; then
      cat <<'EOF'
  # External X server on Windows 10 only. WSLg sets DISPLAY itself.
  export DISPLAY="$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf):0"
  export LIBGL_ALWAYS_INDIRECT=1
EOF
    fi
    printf 'fi\n'
  fi

  v="$(str '.raw')"
  if [ -n "$v" ]; then
    printf '\n# --- raw block from %s ---\n' "$(basename "$CONFIG")"
    printf '%s\n' "$v"
  fi
  append="$(items '.path.append' | paste -sd: -)"
  if [ -n "$append" ]; then
    printf '\n# --- PATH additions (last word on lookup order) ---\n'
    printf 'export PATH="$PATH:%s"\n' "$append"
  fi

  if on '.tools.vscode_shell_integration.enabled'; then
    printf '\n# --- VS Code terminal shell integration ---\n'
    printf '# Keep this last: a theme or conda block after it clobbers its output markers.\n'
    cat <<'EOF'
[[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null && \
  . "$(code --locate-shell-integration-path zsh)"
EOF
  fi
}

# --- run ---------------------------------------------------------------------
[ "$DRY" -eq 1 ] || check_tools

TMP="$(mktemp "${TMPDIR:-/tmp}/zshrc.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
render > "$TMP"

if [ "$DRY" -eq 1 ]; then
  cat "$TMP"
  exit 0
fi

checked="not checked (zsh is not installed)"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$TMP" || die "the generated file failed 'zsh -n', so $OUT was left alone"
  checked="checked with zsh -n"
fi

backup=""
if [ -e "$OUT" ]; then
  backup="$OUT.bak-$STAMP"
  mv "$OUT" "$backup"
fi
mkdir -p "$(dirname "$OUT")"
cp "$TMP" "$OUT"
chmod 644 "$OUT"

echo
echo "=== summary ==="
printf '  %-9s %s\n' "config" "$CONFIG_ABS"
printf '  %-9s %s  (%s)\n' "wrote" "$OUT" "$checked"
if [ -n "$backup" ]; then printf '  %-9s %s\n' "backup" "$backup"; fi
echo
echo "reload it with: exec zsh"

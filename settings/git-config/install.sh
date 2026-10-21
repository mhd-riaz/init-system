#!/usr/bin/env bash
# Generate ~/.gitconfig and friends from gitconfig.yaml.
#
#   ./install.sh                 # detect the OS, check keys, write the configs
#   ./install.sh --dry-run       # print what would be written, change nothing
#   ./install.sh --config FILE   # read another config (default ./gitconfig.yaml)
#   ./install.sh --yes           # never prompt; warn instead of waiting
#
# Accounts are declared in gitconfig.yaml, never in here. This script renders
# them, sets up whichever authentication method the file asks for, and prints
# the one-off steps that only you can do (adding a key to GitHub, pasting a
# token). Nothing secret is ever written into this repository.
#
# Every file it replaces is backed up to <name>.bak-<timestamp> first, and the
# result is checked with `git config --file` before it goes live.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

CONFIG="gitconfig.yaml"
DRY=0
YES=0
STAMP="$(date +%Y%m%d-%H%M%S)"
GITCONFIG="${GITCONFIG_OUT:-$HOME/.gitconfig}"
SSH_DIR="${SSH_DIR:-$HOME/.ssh}"

while [ $# -gt 0 ]; do
  case "$1" in
    --config)  CONFIG="$2"; shift 2 ;;
    --dry-run) DRY=1; YES=1; shift ;;
    -y|--yes)  YES=1; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -t 0 ] || YES=1

info() { printf '  %s\n' "$1" >&2; }
warn() { printf '  !  %s\n' "$1" >&2; }
step() { printf '     %s\n' "$1" >&2; }
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
# Loops until the probe passes, the user skips an optional item, or quits.
ensure() {
  local label="$1" probe="$2" req="$3" cmd ans
  cmd="$(for_os "$4" "$5" "$6")"
  while ! eval "$probe" >/dev/null 2>&1; do
    warn "$label is missing"
    if [ -n "$cmd" ]; then printf '     run:  %s\n' "$cmd" >&2; fi
    if [ "$YES" -eq 1 ]; then
      if [ "$req" = required ]; then die "$label is required; sort it out and run this again"; fi
      warn "continuing without it"
      return 1
    fi
    if [ "$req" = required ]; then
      printf '     [enter] re-check    q) quit : ' >&2
    else
      printf '     [enter] re-check    s) skip    q) quit : ' >&2
    fi
    # Read from the terminal: ensure() is called inside `while read` loops,
    # whose stdin is the list being iterated, not the user.
    read -r ans </dev/tty || ans=q
    case "$ans" in
      q|Q) die "aborted, nothing was written" ;;
      s|S) if [ "$req" = optional ]; then warn "skipped $label"; return 1; fi ;;
    esac
  done
  return 0
}

echo "detected: $OS ($(uname -m))" >&2
echo >&2

# --- config ------------------------------------------------------------------
yq_ok() { command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qi mikefarah; }
ensure "yq (mikefarah/yq v4, used to read $CONFIG)" yq_ok required \
  "brew install yq" \
  "sudo snap install yq      # or: sudo apt-get install -y yq" \
  "winget install --id MikeFarah.yq"

ensure "git" "command -v git" required \
  "brew install git" "sudo apt-get install -y git" "winget install --id Git.Git"

[ -f "$CONFIG" ] || die "no config at $CONFIG"
yq '.' "$CONFIG" >/dev/null 2>&1 || die "$CONFIG is not valid YAML"
CONFIG_ABS="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
SELF="$(pwd)/$(basename "${BASH_SOURCE[0]}")"

on()    { [ "$(yq "$1 // false" "$CONFIG")" = "true" ]; }
str()   { local v; v="$(yq "$1 // \"\"" "$CONFIG")"; if [ "$v" = "null" ]; then v=""; fi; printf '%s' "$v"; }
items() { yq "$1 // [] | .[]" "$CONFIG"; }
# For expressions that already yield one value per line, e.g. .accounts[].id
flat()  { yq "$1" "$CONFIG"; }
# Config keeps "~/..." so the generated files stay portable; local tests need it real.
expand() { local v="$1"; printf '%s' "${v/#\~/$HOME}"; }

IDS=()
while IFS= read -r id; do [ -n "$id" ] && IDS+=("$id"); done < <(flat '.accounts[].id')
[ "${#IDS[@]}" -gt 0 ] || die "no accounts in $CONFIG"

# acc <index> <field>
acc() { str ".accounts[$1].$2"; }
# index_of <id>
index_of() {
  local i
  for i in "${!IDS[@]}"; do [ "${IDS[i]}" = "$1" ] && { printf '%s' "$i"; return 0; }; done
  return 1
}

DEFAULT_ID="$(str '.default_account')"
DEFAULT_IDX="$(index_of "$DEFAULT_ID")" || die "default_account '$DEFAULT_ID' is not one of: ${IDS[*]}"

for i in "${!IDS[@]}"; do
  case "$(acc "$i" email)" in
    *@example.com|"")
      msg="account '${IDS[i]}' still has a placeholder email; edit $CONFIG_ABS"
      [ "$DRY" -eq 1 ] && warn "$msg" || die "$msg" ;;
  esac
done

METHOD="$(str '.auth.method')"
case "$METHOD" in ssh|netrc) ;; *) die "auth.method must be ssh or netrc, got '$METHOD'" ;; esac

# `hasconfig:remote.*.url:` landed in git 2.36; without it those rules are
# silently ignored, which looks exactly like the wrong identity being picked.
git_version="$(git --version | awk '{print $3}')"
if ! printf '2.36\n%s\n' "$git_version" | sort -V -C; then
  warn "git $git_version is older than 2.36: remote-URL rules will be ignored"
  warn "directory rules (match.dirs) still work"
fi

# A remote substring is matched against one path component of the URL, so one
# containing a slash can never match anything.
while IFS= read -r rule; do
  case "$rule" in
    */*) die "match.remotes entry '$rule' contains a slash; it can never match. Use just the host, org or alias." ;;
  esac
done < <(flat '[.accounts[].match.remotes // []] | flatten | .[]')

# --- renderers ---------------------------------------------------------------
header() {
  printf '# %s - generated file, do not edit.\n' "$1"
  printf '# Source:     %s\n' "$CONFIG_ABS"
  printf '# Regenerate: %s\n' "$SELF"
}

render_main() {
  local i rule alias_
  header "$(basename "$GITCONFIG")"
  printf '\n# Fallback identity: account "%s". Overridden by any rule that matches.\n' "$DEFAULT_ID"
  printf '[user]\n'
  printf '\tname = %s\n' "$(acc "$DEFAULT_IDX" name)"
  printf '\temail = %s\n' "$(acc "$DEFAULT_IDX" email)"
  if on ".accounts[$DEFAULT_IDX].sign"; then
    printf '\tsigningkey = %s.pub\n' "$(acc "$DEFAULT_IDX" ssh.key)"
    printf '[commit]\n\tgpgsign = true\n'
  fi

  if [ -n "$(str '.common.gpg_format')" ]; then
    printf '[gpg]\n\tformat = %s\n' "$(str '.common.gpg_format')"
  fi
  if [ -n "$(str '.common.allowed_signers')" ]; then
    printf '[gpg "ssh"]\n\tallowedSignersFile = %s\n' "$(str '.common.allowed_signers')"
  fi
  if on '.common.push_auto_setup_remote'; then
    printf '[push]\n\tautoSetupRemote = true\n'
  fi

  printf '\n# Switching rules. Later matches win, so order is intentional.\n'
  for i in "${!IDS[@]}"; do
    printf '\n# --- %s ---\n' "${IDS[i]}"
    while IFS= read -r rule; do
      [ -n "$rule" ] || continue
      printf '[includeIf "gitdir:%s"]\n\tpath = ~/.gitconfig-%s\n' "$rule" "${IDS[i]}"
    done < <(items ".accounts[$i].match.dirs")
    # A remote-URL condition is globbed path-style: `*` stops at `/`, so a bare
    # `*text*` can never match a URL that has a slash after `text` -- it just
    # silently never fires. Wrapping every substring in **/*...*/** is what
    # makes it match a whole component of any URL shape.
    alias_="$(acc "$i" ssh.alias)"
    if [ -n "$alias_" ]; then
      printf '[includeIf "hasconfig:remote.*.url:**/*%s*/**"]\n\tpath = ~/.gitconfig-%s\n' \
        "$alias_" "${IDS[i]}"
    fi
    while IFS= read -r rule; do
      [ -n "$rule" ] || continue
      [ "$rule" = "$alias_" ] && continue
      printf '[includeIf "hasconfig:remote.*.url:**/*%s*/**"]\n\tpath = ~/.gitconfig-%s\n' \
        "$rule" "${IDS[i]}"
    done < <(items ".accounts[$i].match.remotes")
  done

  if [ -n "$(str '.common.extra')" ]; then
    printf '\n# --- extra block from %s ---\n%s\n' "$(basename "$CONFIG")" "$(str '.common.extra')"
  fi
}

# render_account <index>
render_account() {
  local i="$1"
  header ".gitconfig-${IDS[i]}"
  printf '\n[user]\n'
  printf '\tname = %s\n' "$(acc "$i" name)"
  printf '\temail = %s\n' "$(acc "$i" email)"
  if on ".accounts[$i].sign"; then
    printf '\tsigningkey = %s.pub\n' "$(acc "$i" ssh.key)"
    printf '[commit]\n\tgpgsign = true\n'
  else
    printf '[commit]\n\tgpgsign = false\n'
  fi
  if [ "$METHOD" = netrc ]; then
    printf '\n# Tells the credential helper which account to ask for. Plain ~/.netrc\n'
    printf '# ignores it and matches on the host alone - see auth.method in %s.\n' "$(basename "$CONFIG")"
    printf '[credential "https://%s"]\n\tusername = %s\n' "$(acc "$i" host)" "$(acc "$i" name)"
  fi
}

SSH_BEGIN="# >>> code-setup git accounts >>>"
SSH_END="# <<< code-setup git accounts <<<"

render_ssh_block() {
  local i
  printf '%s\n' "$SSH_BEGIN"
  printf '# Generated from %s. Edit that file, not this block.\n' "$CONFIG_ABS"
  for i in "${!IDS[@]}"; do
    [ -n "$(acc "$i" ssh.alias)" ] || continue
    printf 'Host %s\n' "$(acc "$i" ssh.alias)"
    printf '  HostName %s\n' "$(acc "$i" host)"
    printf '  User git\n'
    printf '  IdentityFile %s\n' "$(acc "$i" ssh.key)"
    # Without this ssh offers every key it has and the server accepts whichever
    # authenticates first, which is how you end up pushing as the wrong account.
    printf '  IdentitiesOnly yes\n'
  done
  printf '%s\n' "$SSH_END"
}

render_allowed_signers() {
  local i key pub
  for i in "${!IDS[@]}"; do
    on ".accounts[$i].sign" || continue
    key="$(expand "$(acc "$i" ssh.key)")"
    pub="$key.pub"
    [ -f "$pub" ] || continue
    printf '%s %s\n' "$(acc "$i" email)" "$(awk '{print $1, $2}' "$pub")"
  done
}

render_vscode() {
  local i first=1
  printf '  "git-autoconfig.configList": [\n'
  for i in "${!IDS[@]}"; do
    [ "$first" -eq 1 ] || printf ',\n'
    first=0
    printf '    { "user.email": "%s", "user.name": "%s" }' "$(acc "$i" email)" "$(acc "$i" name)"
  done
  printf '\n  ],\n'
  printf '  "git-autoconfig.ignoreRootList": [\n'
  first=1
  for i in "${!IDS[@]}"; do
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      [ "$first" -eq 1 ] || printf ',\n'
      first=0
      printf '    "%s"' "$(expand "${d%/}")"
    done < <(items ".accounts[$i].match.dirs")
  done
  printf '\n  ]\n'
}

# --- writing -----------------------------------------------------------------
WROTE=()

# write_file <path> <mode> <renderer...>
write_file() {
  local dest="$1" mode="$2"; shift 2
  local tmp; tmp="$(mktemp "${TMPDIR:-/tmp}/gitcfg.XXXXXX")"
  "$@" > "$tmp"
  if [ "$DRY" -eq 1 ]; then
    printf '\n### %s\n' "$dest"
    cat "$tmp"
    rm -f "$tmp"
    return 0
  fi
  case "$dest" in
    *gitconfig*) git config --file "$tmp" --list >/dev/null \
                   || { rm -f "$tmp"; die "generated $dest is not valid git config"; } ;;
  esac
  if [ -e "$dest" ] && ! cmp -s "$tmp" "$dest"; then
    cp "$dest" "$dest.bak-$STAMP"
    WROTE+=("backup   $dest.bak-$STAMP")
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$tmp" "$dest"
  chmod "$mode" "$dest"
  rm -f "$tmp"
  WROTE+=("wrote    $dest")
}

write_ssh_config() {
  local dest="$SSH_DIR/config" tmp body
  tmp="$(mktemp "${TMPDIR:-/tmp}/sshcfg.XXXXXX")"
  # $( ) drops trailing newlines, so repeated runs converge on the same file
  # instead of growing a blank line before the block every time.
  body=""
  if [ -f "$dest" ]; then body="$(sed "/^$SSH_BEGIN\$/,/^$SSH_END\$/d" "$dest")"; fi
  {
    if [ -n "$body" ]; then printf '%s\n\n' "$body"; fi
    render_ssh_block
  } > "$tmp"
  if [ "$DRY" -eq 1 ]; then
    printf '\n### %s  (managed block only)\n' "$dest"
    render_ssh_block
    rm -f "$tmp"
    return 0
  fi
  if [ -e "$dest" ] && ! cmp -s "$tmp" "$dest"; then
    cp "$dest" "$dest.bak-$STAMP"
    WROTE+=("backup   $dest.bak-$STAMP")
  fi
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  cp "$tmp" "$dest"
  chmod 600 "$dest"
  rm -f "$tmp"
  WROTE+=("wrote    $dest  (managed block)")
}

# --- authentication guidance --------------------------------------------------
setup_ssh() {
  local i key alias_ email have_key
  echo >&2
  echo "[ssh keys]" >&2
  for i in "${!IDS[@]}"; do
    key="$(expand "$(acc "$i" ssh.key)")"
    alias_="$(acc "$i" ssh.alias)"
    email="$(acc "$i" email)"
    have_key=0
    if ensure "key for '${IDS[i]}' at $key" "[ -f '$key' ]" optional \
        "ssh-keygen -t ed25519 -C \"$email\" -f \"$key\"" \
        "ssh-keygen -t ed25519 -C \"$email\" -f \"$key\"" \
        "ssh-keygen -t ed25519 -C \"$email\" -f \"$key\""; then
      have_key=1
    fi
    if [ "$have_key" -eq 1 ]; then
      info "ok  ${IDS[i]}  $key"
    elif on ".accounts[$i].sign"; then
      warn "'${IDS[i]}' has sign: true but no key: every commit there will fail"
      warn "generate the key, or set sign: false in $(basename "$CONFIG")"
    fi
  done

  echo >&2
  echo "[add each key to its GitHub account]" >&2
  step "Authentication lets you push; signing is a separate key type on GitHub."
  step "A key can be registered as both, and must be, if sign is true."
  for i in "${!IDS[@]}"; do
    key="$(acc "$i" ssh.key)"
    step ""
    step "${IDS[i]}:"
    step "  gh auth login --hostname $(acc "$i" host)      # as ${IDS[i]}, once"
    step "  gh ssh-key add $key.pub --title '${IDS[i]}' --type authentication"
    on ".accounts[$i].sign" && \
    step "  gh ssh-key add $key.pub --title '${IDS[i]} signing' --type signing"
    step "  (or paste $key.pub at https://$(acc "$i" host)/settings/keys)"
  done

  echo >&2
  echo "[using them]" >&2
  step "Clone through the alias and the right key and identity both follow:"
  for i in "${!IDS[@]}"; do
    [ -n "$(acc "$i" ssh.alias)" ] || continue
    step "  git clone git@$(acc "$i" ssh.alias):<owner>/<repo>.git"
  done
  step ""
  step "Already cloned with the plain host? Repoint it:"
  step "  git remote set-url origin git@<alias>:<owner>/<repo>.git"
  step ""
  step "Check a key reaches the right account:"
  for i in "${!IDS[@]}"; do
    [ -n "$(acc "$i" ssh.alias)" ] || continue
    step "  ssh -T git@$(acc "$i" ssh.alias)"
  done
}

setup_netrc() {
  local netrc="$HOME/.netrc" i hosts dupe ans token
  echo >&2
  echo "[netrc]" >&2

  hosts="$(for i in "${!IDS[@]}"; do acc "$i" host; echo; done | sort)"
  dupe="$(printf '%s\n' "$hosts" | uniq -d)"
  if [ -n "$dupe" ]; then
    warn "more than one account uses $(printf '%s' "$dupe" | tr '\n' ' ')"
    step "netrc matches on the machine name alone, so git cannot tell those"
    step "accounts apart: the first matching line always wins."
    step "Use auth.method: ssh for accounts that share a host."
  fi

  step "Format (one stanza per machine, token as the password):"
  step ""
  for i in "${!IDS[@]}"; do
    step "  machine $(acc "$i" host)"
    step "    login $(acc "$i" name)"
    step "    password <personal-access-token>"
  done
  step ""
  step "Create a token at https://github.com/settings/tokens with 'repo' scope."
  step "It is stored in plain text, so: chmod 600 $netrc, and never commit it."

  if [ -f "$netrc" ]; then
    if [ "$(stat -f '%Lp' "$netrc" 2>/dev/null || stat -c '%a' "$netrc" 2>/dev/null)" != "600" ]; then
      warn "$netrc is not chmod 600"
      [ "$DRY" -eq 1 ] || { chmod 600 "$netrc"; info "fixed: chmod 600 $netrc"; }
    else
      info "ok  $netrc exists and is chmod 600"
    fi
  else
    warn "$netrc does not exist"
  fi

  [ "$YES" -eq 1 ] && return 0
  printf '     add a stanza now? the token is read without echo [y/N]: ' >&2
  read -r ans </dev/tty || ans=n
  case "$ans" in y|Y) ;; *) return 0 ;; esac

  for i in "${!IDS[@]}"; do
    printf '     token for %s on %s (empty to skip): ' "$(acc "$i" name)" "$(acc "$i" host)" >&2
    read -rs token </dev/tty || token=""
    echo >&2
    [ -n "$token" ] || continue
    if grep -q "machine $(acc "$i" host)" "$netrc" 2>/dev/null; then
      warn "$netrc already has a stanza for $(acc "$i" host); left alone"
      continue
    fi
    umask 077
    printf 'machine %s\n  login %s\n  password %s\n' \
      "$(acc "$i" host)" "$(acc "$i" name)" "$token" >> "$netrc"
    chmod 600 "$netrc"
    info "appended $(acc "$i" host) to $netrc"
  done
  unset token
}

setup_vscode() {
  echo >&2
  echo "[vs code: git-autoconfig]" >&2
  step "Install it:  code --install-extension shyykoserhiy.git-autoconfig"
  step ""
  step "Add this to your VS Code user settings.json. ignoreRootList is the"
  step "important half: the extension reads LOCAL git config only, so without"
  step "it the extension would ask for an identity in repos the rules already"
  step "handle."
  echo >&2
  render_vscode >&2
  echo >&2
  step "Picking an identity in the extension writes a local user.email, which"
  step "beats every rule - that is the per-repo override for odd repos."
}

# --- run ----------------------------------------------------------------------
echo "[config files]" >&2
write_file "$GITCONFIG" 644 render_main
for i in "${!IDS[@]}"; do
  write_file "$HOME/.gitconfig-${IDS[i]}" 644 render_account "$i"
done

if [ "$METHOD" = ssh ]; then
  write_ssh_config
fi

signers="$(str '.common.allowed_signers')"
if [ -n "$signers" ]; then
  if [ -n "$(render_allowed_signers)" ]; then
    write_file "$(expand "$signers")" 644 render_allowed_signers
  else
    warn "no public keys found yet, so $signers was not written"
    warn "re-run this after generating the keys to enable local verification"
  fi
fi

if [ "$DRY" -eq 1 ]; then
  on '.vscode.enabled' && { printf '\n### VS Code settings.json fragment\n'; render_vscode; }
  exit 0
fi

case "$METHOD" in
  ssh)   setup_ssh ;;
  netrc) setup_netrc ;;
esac
on '.vscode.enabled' && setup_vscode

echo >&2
echo "=== summary ===" >&2
printf '  %s\n' "${WROTE[@]}" >&2
echo >&2
echo "  check any repo with:  git config --show-origin user.email" >&2
echo "  list the rules with:  git config --global --list --show-origin" >&2

#!/usr/bin/env bash
# Interactive installer for this skill bundle.
#
#   ./install.sh              # ask what to install where, then do it
#   ./install.sh --dry-run    # any flag is passed straight to agent-tools/install.sh
#
# Detects the OS, asks which providers to install into and whether to preserve or
# replace what is already there, then hands off to agent-tools/install.sh, which
# owns the provider paths, the backups and the verification.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

[ $# -gt 0 ] && exec ./agent-tools/install.sh "$@"

case "$(uname -s)" in
  Darwin)               OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) OS=windows ;;
  Linux)                OS=linux; grep -qi microsoft /proc/version 2>/dev/null && OS="linux (wsl)" ;;
  *)                    OS="$(uname -s)" ;;
esac
echo "detected: $OS"
echo

# Providers that install to a path on this machine. The hosted chat UIs
# (claude.ai, chatgpt.com, gemini.google.com) have no local skills directory --
# upload skills there by hand.
KEYS=(claude     codex          copilot-cli   vscode              gemini        agents-md)
DESC=("Claude Code / Desktop        ~/.claude/skills + CLAUDE.md"
      "OpenAI Codex CLI             ~/.codex/skills + ~/.agents/skills + AGENTS.md"
      "GitHub Copilot CLI           ~/.copilot/skills + copilot-instructions.md"
      "VS Code Copilot              Copilot skills dir + user .instructions.md"
      "Gemini CLI                   ~/.gemini/skills + GEMINI.md"
      "Any AGENTS.md reader         ~/AGENTS.md (Cursor, Windsurf, Amp)")

if [ ! -t 0 ]; then
  echo "not a terminal; installing everything without overwriting. --help for flags."
  exec ./agent-tools/install.sh
fi

# --- checklist ---------------------------------------------------------------
checked=(1 1 1 1 1 1)
cur=0
n=${#KEYS[@]}

draw() {
  local i mark point
  for i in $(seq 0 $((n - 1))); do
    [ "${checked[i]}" -eq 1 ] && mark="x" || mark=" "
    [ "$i" -eq "$cur" ] && point=">" || point=" "
    printf '  %s [%s] %-12s %s\033[K\n' "$point" "$mark" "${KEYS[i]}" "${DESC[i]}"
  done
}

echo "Which providers? (up/down move, space toggles, enter confirms, a = all, q = quit)"
# -s on read only silences its own read; bytes arriving between reads are still
# echoed by the tty. Mute the terminal for the whole loop instead.
stty_saved="$(stty -g)"
restore_tty() { stty "$stty_saved" 2>/dev/null || true; printf '\033[?25h'; }
trap 'restore_tty' EXIT INT TERM
stty -echo
printf '\033[?25l'
draw
while :; do
  IFS= read -rsn1 key || key=""
  case "$key" in
    "")  break ;;
    " ") [ "${checked[cur]}" -eq 1 ] && checked[cur]=0 || checked[cur]=1 ;;
    k)   [ "$cur" -gt 0 ] && cur=$((cur - 1)) ;;
    j)   [ "$cur" -lt $((n - 1)) ] && cur=$((cur + 1)) ;;
    a|A) for i in $(seq 0 $((n - 1))); do checked[i]=1; done ;;
    q|Q) restore_tty; echo "aborted."; exit 1 ;;
    $'\033')
      # bash 3.2 (macOS default) rejects a fractional -t, so this must be a whole
      # second. The rest of an arrow sequence is already buffered and returns at once;
      # only a bare Esc waits it out.
      rest=""
      read -rsn2 -t 1 rest || true
      case "$rest" in
        "[A") [ "$cur" -gt 0 ] && cur=$((cur - 1)) ;;
        "[B") [ "$cur" -lt $((n - 1)) ] && cur=$((cur + 1)) ;;
      esac ;;
  esac
  printf '\033[%dA' "$n"
  draw
done

selected=""
for i in $(seq 0 $((n - 1))); do
  [ "${checked[i]}" -eq 1 ] && selected="$selected,${KEYS[i]}"
done
selected="${selected#,}"
restore_tty
trap - EXIT INT TERM
[ -n "$selected" ] || { echo "nothing selected."; exit 1; }

# --- existing files -----------------------------------------------------------
echo
echo "Existing skills and instruction files:"
echo "  1) keep them  - add only what is missing, touch nothing else (default)"
echo "  2) replace    - back up each one to <name>.bak-<timestamp>, then overwrite"
printf 'choice [1]: '
read -r answer
case "${answer:-1}" in
  2) force="--force" ;;
  *) force="" ;;
esac

echo
exec ./agent-tools/install.sh --providers "$selected" ${force:+$force}

#!/usr/bin/env bash
# Install this bundle into one or more AI agent providers.
#
#   ./agent-tools/install.sh                          # symlink into every provider
#   ./agent-tools/install.sh --mode copy              # copy instead of symlink
#   ./agent-tools/install.sh --providers claude,codex # subset
#   ./agent-tools/install.sh --dry-run                # show what would happen
#   ./agent-tools/install.sh --force                  # back up and replace existing entries
#
# Non-destructive by default: an existing file or directory is SKIPPED with a warning,
# never deleted. --force moves it aside to <name>.bak-<timestamp> first.
#
# Provider paths move between releases. Override any of them with an environment
# variable rather than editing this script:
#   CLAUDE_HOME  CODEX_HOME  CODEX_SKILLS_DIR  COPILOT_HOME  VSCODE_SKILLS_DIR
#   VSCODE_INSTRUCTIONS_DIR  AGENTS_MD_DIR

set -euo pipefail

BUNDLE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="symlink"
PROVIDERS="claude,codex,copilot-cli,vscode,agents-md"
FORCE=0
DRY=0
STAMP="$(date +%Y%m%d-%H%M%S)"

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)      MODE="$2"; shift 2 ;;
    --providers) PROVIDERS="$2"; shift 2 ;;
    --force)     FORCE=1; shift ;;
    --dry-run)   DRY=1; shift ;;
    -h|--help)   sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$MODE" in symlink|copy) ;; *) echo "mode must be symlink or copy" >&2; exit 2 ;; esac

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
# Codex reads USER-level skills from $HOME/.agents/skills, not $CODEX_HOME/skills.
CODEX_SKILLS_DIR="${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
VSCODE_SKILLS_DIR="${VSCODE_SKILLS_DIR:-$HOME/.config/github-copilot/skills}"
if [ "$(uname -s)" = "Darwin" ]; then
  VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
else
  VSCODE_USER_DIR="$HOME/.config/Code/User"
fi
VSCODE_INSTRUCTIONS_DIR="${VSCODE_INSTRUCTIONS_DIR:-$VSCODE_USER_DIR/prompts}"
AGENTS_MD_DIR="${AGENTS_MD_DIR:-$HOME}"

info() { printf '  %s\n' "$1"; }
warn() { printf '  !  %s\n' "$1" >&2; }

# link_one <source> <destination>
link_one() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      info "ok (already linked)  $dest"; return 0
    fi
    if [ "$FORCE" -eq 1 ]; then
      [ "$DRY" -eq 1 ] || mv "$dest" "$dest.bak-$STAMP"
      warn "backed up existing -> $dest.bak-$STAMP"
    else
      warn "SKIP (exists, use --force)  $dest"; return 0
    fi
  fi
  if [ "$DRY" -eq 1 ]; then info "would $MODE  $dest"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  if [ "$MODE" = "symlink" ]; then ln -s "$src" "$dest"; else cp -R "$src" "$dest"; fi
  info "$MODE  $dest"
}

install_skills() {
  local target="$1"
  for dir in "$BUNDLE"/skills/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    link_one "${dir%/}" "$target/$(basename "$dir")"
  done
  # A skill's ../../_shared/... refs resolve through a symlink but not through a copy,
  # so copy mode must place the rest of the bundle beside the skills directory.
  if [ "$MODE" = "copy" ]; then
    for dir in _shared templates rules agent-tools; do
      link_one "$BUNDLE/$dir" "$(dirname "$target")/$dir"
    done
  fi
}

# No provider discovers a directory of plain .md rule files; each has one entry point.
# Inline the rules into it so always-on policy actually loads.
generate_instructions() {
  local dest="$1" frontmatter="${2:-}"
  if [ -e "$dest" ] && [ "$FORCE" -eq 0 ]; then
    warn "SKIP (exists, use --force)  $dest"; return 0
  fi
  if [ "$DRY" -eq 1 ]; then info "would generate  $dest"; return 0; fi
  [ -e "$dest" ] && mv "$dest" "$dest.bak-$STAMP"
  mkdir -p "$(dirname "$dest")"

  {
    [ -n "$frontmatter" ] && printf '%s\n\n' "$frontmatter"
    echo "# Agent rules"
    echo
    echo "Generated from $BUNDLE on $(date -u +%Y-%m-%dT%H:%M:%SZ). Do not edit directly."
    echo "Edit the bundle and re-run agent-tools/install.sh."
    echo
    for file in "$BUNDLE"/rules/*.md; do
      [ -f "$file" ] || continue
      sed 's/^#/##/' "$file"
      echo
    done
    echo "## Available skills"
    echo
    echo "Skills live in \`$BUNDLE/skills/\`. Read a skill's SKILL.md before running its"
    echo "workflow. Routing boundaries are in each description's USE FOR / DO NOT USE FOR."
    echo
    for dir in "$BUNDLE"/skills/*/; do
      [ -f "$dir/SKILL.md" ] || continue
      printf -- '- `%s`\n' "$(basename "$dir")"
    done
  } > "$dest"
  info "generated  $dest"
}

echo "bundle: $BUNDLE"
echo "mode:   $MODE$([ "$DRY" -eq 1 ] && echo ' (dry run)')"

IFS=','
for provider in $PROVIDERS; do
  unset IFS
  echo
  echo "[$provider]"
  case "$provider" in
    claude)
      install_skills "$CLAUDE_HOME/skills"
      generate_instructions "$CLAUDE_HOME/CLAUDE.md" ;;
    codex)
      install_skills "$CODEX_SKILLS_DIR"
      generate_instructions "$CODEX_HOME/AGENTS.md" ;;
    copilot-cli)
      install_skills "$COPILOT_HOME/skills"
      generate_instructions "$COPILOT_HOME/copilot-instructions.md" ;;
    vscode)
      install_skills "$VSCODE_SKILLS_DIR"
      generate_instructions "$VSCODE_INSTRUCTIONS_DIR/agent-rules.instructions.md" \
        "---
applyTo: '**'
---" ;;
    agents-md)
      generate_instructions "$AGENTS_MD_DIR/AGENTS.md" ;;
    *)
      warn "unknown provider: $provider" ;;
  esac
  IFS=','
done
unset IFS

echo
echo "done. verify with: python3 $BUNDLE/agent-tools/validate.py"
echo "restart your agent to pick up new skills."

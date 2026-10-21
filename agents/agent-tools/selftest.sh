#!/usr/bin/env bash
# Regression check for the seams that broke silently before (AUDIT-LOG B29-B33, B40),
# plus the installer's provider targets, keep-vs-replace behaviour and backups.
# Prints one line per assertion and exits non-zero on the first failure.
#
#   agent-tools/selftest.sh
#
# Works entirely in a temp directory. Touches no provider directory and no real repo.

set -uo pipefail

BUNDLE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fails=0

ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n     %s\n' "$1" "$2"; fails=$((fails + 1)); }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$3', got '$2'"; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "missing '$3' in: $(printf '%s' "$2" | tr '\n' '|' | cut -c1-200)" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "unexpected '$3'" ;; *) ok "$1" ;; esac; }

echo "B32 — config command extraction"
mkdir -p "$TMP/repo/.agent" && cd "$TMP/repo" && git init -q . && git commit -q --allow-empty -m init
cat > .agent/config.yml <<'YML'
testing:
  command: pytest -q          # trailing comment
  per_package_command: go test ./... -json
  baseline_command: "go test ./... -json"
  coverage:
    backend: 90
YML
is "reads testing.command exactly" \
   "$("$BUNDLE/agent-tools/test-run.sh" 2>/dev/null | sed -n '1s/^# command: //p')" \
   "pytest -q"

echo "B33 — baseline compares failure identity, not summary text"
printf '%s\n' '{"Action":"pass","Package":"a","Test":"T1"}' '{"Action":"fail","Package":"b","Test":"T2"}' > base.json
printf '%s\n' '{"Action":"pass","Package":"a","Test":"T1"}' '{"Action":"pass","Package":"a","Test":"T3"}' \
              '{"Action":"fail","Package":"b","Test":"T2"}' '{"Action":"pass","Package":"c","Test":"T4"}' > more.json
printf '%s\n' '{"Action":"pass","Package":"a","Test":"T1"}' '{"Action":"fail","Package":"b","Test":"TX"}' > swap.json
"$BUNDLE/agent-tools/test-run.sh" --baseline -- cat base.json >/dev/null 2>&1
has   "added passing tests are not new failures" "$("$BUNDLE/agent-tools/test-run.sh" --compare -- cat more.json 2>&1)" "no new failures"
has   "a swapped failing test is detected"       "$("$BUNDLE/agent-tools/test-run.sh" --compare -- cat swap.json 2>&1)" "NEW FAILURE  b::TX"

echo "B40 — validator catches unresolvable references"
mkdir -p "$TMP/v/skills/bad" "$TMP/v/_shared" && cp "$BUNDLE/_shared/capabilities.md" "$TMP/v/_shared/"
cat > "$TMP/v/skills/bad/SKILL.md" <<'MD'
---
name: bad
description: >
  Thing. USE FOR: a thing. DO NOT USE FOR: another (use other).
license: MIT
metadata:
  version: 1.0.0
---

## Purpose
Links [nowhere](../../_shared/nope.md) and uses CAP:TELEPATHY.

## Related skills
none

## Rules
- none

## Completion criteria
done

## Outcome logging
see shared

## Changelog
- 1.0.0 (2026-10-20) — initial.
MD
out=$(python3 "$BUNDLE/agent-tools/validate.py" "$TMP/v" 2>&1)
has "broken link reported"        "$out" "broken relative link"
has "undefined capability reported" "$out" "undefined capability 'CAP:TELEPATHY'"

echo "B30 — copy mode keeps ../../_shared resolvable"
VSCODE_SKILLS_DIR="$TMP/inst/skills" VSCODE_INSTRUCTIONS_DIR="$TMP/inst/prompts" \
  "$BUNDLE/agent-tools/install.sh" --mode copy --providers vscode >/dev/null 2>&1
[ -f "$TMP/inst/skills/write-code/../../_shared/approval-gate.md" ] \
  && ok "shared procedure resolves from a copied skill" \
  || bad "shared procedure resolves from a copied skill" "not found"

echo "B29 — rules land in an entry point the provider reads"
has "generated instructions carry the rules" "$(cat "$TMP/inst/prompts/agent-rules.instructions.md" 2>&1)" "applyTo"

echo "bundle validates"
is "0 non-compliant" "$(cd "$BUNDLE" && python3 agent-tools/validate.py | sed -n 's/^\([0-9]*\) non-compliant.*/\1/p')" "0"

echo "installer — keep vs replace, and the per-provider targets"
H="$TMP/home"; mkdir -p "$H"
run() { env -u COPILOT_HOME -u CLAUDE_HOME -u CODEX_HOME -u GEMINI_HOME \
            -u CODEX_SKILLS_DIR -u AGENTS_SKILLS_DIR -u AGENTS_MD_DIR \
            -u VSCODE_SKILLS_DIR -u VSCODE_INSTRUCTIONS_DIR \
            HOME="$H" "$BUNDLE/agent-tools/install.sh" "$@" 2>&1; }

out=$(run --providers claude,codex,gemini)
has "every target verifies"   "$out" "skills    ok"
hasnt "nothing reported missing" "$out" "MISSING"
[ -f "$H/.gemini/skills/write-code/SKILL.md" ] && ok "gemini skills dir" || bad "gemini skills dir" "not found"
[ -f "$H/.gemini/GEMINI.md" ]                  && ok "gemini entry point" || bad "gemini entry point" "not found"
[ -f "$H/.codex/skills/write-code/SKILL.md" ]  && ok "codex skills dir"  || bad "codex skills dir" "not found"
[ -f "$H/.agents/skills/write-code/SKILL.md" ] && ok "codex cross-agent dir" || bad "codex cross-agent dir" "not found"

printf 'MY OWN NOTES\n' > "$H/.claude/CLAUDE.md"
has "existing file is skipped, not clobbered" "$(run --providers claude)" "skip      left alone"
is   "...and its content survives" "$(cat "$H/.claude/CLAUDE.md")" "MY OWN NOTES"

has "--force reports the backup" "$(run --providers claude --force)" "backup    saved"
is   "...old content is in the .bak file" "$(cat "$H"/.claude/CLAUDE.md.bak-* 2>/dev/null)" "MY OWN NOTES"
hasnt "...and the new file replaced it" "$(cat "$H/.claude/CLAUDE.md")" "MY OWN NOTES"

echo "interactive wrapper — non-tty and flag passthrough"
wrapper() { env -u COPILOT_HOME HOME="$H" "$BUNDLE/install.sh" "$@" 2>&1; }
has "flags go straight to the real installer" "$(wrapper --dry-run --providers claude)" "dry run"
has "no tty falls back instead of hanging"    "$(wrapper </dev/null)" "not a terminal"
echo
[ "$fails" -eq 0 ] && { echo "all checks passed"; exit 0; }
echo "$fails check(s) failed"; exit 1

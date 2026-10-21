#!/usr/bin/env bash
# Append one skill outcome record to the right log, verifying the path first.
#
#   agent-tools/outcome-log.sh <skill> <version> <success|corrected|abandoned|error> \
#       "<correction or none>" "<evidence>" [--global] [--session ID]
#
# The previous generation of skills logged to /memories/..., a VS Code virtual path.
# Every record written outside VS Code was silently lost (AUDIT-LOG B10). This script
# resolves a real path, proves it is writable, and says so when it is not.

set -uo pipefail

[ $# -lt 5 ] && { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

skill=$1 version=$2 outcome=$3 correction=$4 evidence=$5
shift 5

scope=repo
session=${COPILOT_SESSION_ID:-unavailable}
while [ $# -gt 0 ]; do
  case "$1" in
    --global)  scope=global; shift ;;
    --session) session=${2:-unavailable}; shift 2 ;;
    *) shift ;;
  esac
done

case "$outcome" in
  success|corrected|abandoned|error) ;;
  *) echo "error: outcome must be success|corrected|abandoned|error" >&2; exit 2 ;;
esac

state_global=${AGENT_STATE_HOME:-$HOME/.agent/state}
if [ "$scope" = "global" ]; then
  dir=$state_global
else
  root=$(git rev-parse --show-toplevel 2>/dev/null) && dir="$root/.agent" || dir=$state_global
fi
log="$dir/skill-outcomes.md"

if ! mkdir -p "$dir" 2>/dev/null || [ ! -w "$dir" ]; then
  echo "NOT LOGGED: $dir is not writable. Report this rather than assuming the record was written." >&2
  exit 1
fi

{
  printf '\n## %s — %s v%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$skill" "$version"
  printf -- '- session: %s\n' "$session"
  printf -- '- outcome: %s\n' "$outcome"
  printf -- '- correction: %s\n' "$correction"
  printf -- '- evidence: %s\n' "$evidence"
} >> "$log" || { echo "NOT LOGGED: append failed for $log" >&2; exit 1; }

echo "logged: $log"

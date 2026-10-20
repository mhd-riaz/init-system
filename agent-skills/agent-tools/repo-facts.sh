#!/usr/bin/env bash
# Every fact a skill needs about the current repository, in one call.
#
#   agent-tools/repo-facts.sh [path]
#
# Replaces the scatter of separate git calls that work-item-context, devlog and
# pr-fetch each used to make. Output is key=value lines, cheap to read and parse.
#
# Read-only. Never reads .env or any credential file.

set -uo pipefail

cd "${1:-.}" 2>/dev/null || { echo "error=bad_path"; exit 1; }

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "in_repo=false"; exit 0; }
cd "$root" || exit 1

echo "in_repo=true"
echo "repo_root=$root"
echo "repo_name=$(basename "$root")"

remote=$(git remote get-url origin 2>/dev/null || true)
echo "remote=${remote:-none}"

case "$remote" in
  *dev.azure.com*|*visualstudio.com*) code_host=ado ;;
  *github.com*|*ghe.com*)             code_host=github ;;
  "")                                 code_host=none ;;
  *)                                  code_host=other ;;
esac
echo "code_host=$code_host"

# owner/repo from either host's URL shape
slug=$(printf '%s' "$remote" \
  | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##; s#/_git/#/#')
echo "repo_slug=${slug:-none}"

branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
echo "branch=$branch"

default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
if [ -z "$default" ]; then
  for c in main master develop; do
    git show-ref --verify --quiet "refs/remotes/origin/$c" && { default=$c; break; }
  done
fi
echo "default_branch=${default:-unknown}"

# Tracker detection. The code host is NOT necessarily the tracker: an AB# prefix on a
# GitHub remote means work items live in Azure DevOps (AUDIT-LOG B21).
ab=$(git --no-pager log --oneline -30 2>/dev/null | grep -cE '\bAB#[0-9]+' || true)
echo "ab_prefix_commits=${ab:-0}"

if [ -f .agent/config.yml ]; then
  echo "agent_config=.agent/config.yml"
  sys=$(grep -A6 '^tracker:' .agent/config.yml 2>/dev/null \
        | grep -m1 '^[[:space:]]*system:' | sed 's/.*system:[[:space:]]*//' | tr -d '"'"'"' ')
  echo "tracker_configured=${sys:-unset}"
else
  echo "agent_config=none"
  if [ "${ab:-0}" -gt 0 ]; then
    echo "tracker_detected=ado"
  elif [ "$code_host" = "github" ]; then
    echo "tracker_detected=github"
  else
    echo "tracker_detected=$code_host"
  fi
fi

dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "uncommitted_files=$dirty"
echo "last_commit=$(git --no-pager log -1 --format=%h 2>/dev/null || echo none)"
echo "last_commit_date=$(git --no-pager log -1 --format=%cI 2>/dev/null || echo none)"

dl=$(find docs/devlog -maxdepth 2 -name '*.devlog.md' 2>/dev/null | head -1)
echo "devlog=${dl:-none}"

for f in go.mod package.json pyproject.toml requirements.txt Cargo.toml pom.xml; do
  [ -f "$f" ] && { echo "stack_marker=$f"; break; }
done

for f in .github/copilot-instructions.md AGENTS.md CLAUDE.md CONTRIBUTING.md; do
  [ -f "$f" ] && echo "instructions=$f"
done

exit 0

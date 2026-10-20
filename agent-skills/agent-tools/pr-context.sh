#!/usr/bin/env bash
# Gather everything a PR review needs, in one call.
#
#   agent-tools/pr-context.sh <pr-url-or-number> [--files] [--threads] [--diff] [--all]
#
# With no flags, prints metadata plus the changed-file list. Implements the fetch
# procedure in _shared/pr-fetch.md so three skills do not each re-derive it.
#
# It does NOT return file contents, and it marks every truncated or missing section
# "PARTIAL:" / "UNAVAILABLE:". Treat those as work left for the caller — an exhaustive
# request is not satisfied by a silently shortened list.
#
# Read-only. Never reads .env or any credential file.

set -uo pipefail

[ $# -lt 1 ] && { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

ref=$1; shift
want_files=0 want_threads=0 want_diff=0
for a in "$@"; do
  case "$a" in
    --files)   want_files=1 ;;
    --threads) want_threads=1 ;;
    --diff)    want_diff=1 ;;
    --all)     want_files=1; want_threads=1; want_diff=1 ;;
  esac
done
[ $want_files -eq 0 ] && [ $want_threads -eq 0 ] && [ $want_diff -eq 0 ] && want_files=1

case "$ref" in
  *dev.azure.com*|*visualstudio.com*) host=ado ;;
  *github.com*|*ghe.com*)             host=github ;;
  *)
    remote=$(git remote get-url origin 2>/dev/null || true)
    case "$remote" in
      *dev.azure.com*|*visualstudio.com*) host=ado ;;
      *github.com*|*ghe.com*)             host=github ;;
      *) echo "cannot determine platform; pass a full PR URL" >&2; exit 2 ;;
    esac
    ;;
esac
echo "platform=$host"

num=$(printf '%s' "$ref" | grep -oE '[0-9]+$' || true)
[ -z "$num" ] && { echo "cannot extract a PR number from: $ref" >&2; exit 2; }
echo "pr=$num"

if [ "$host" = "github" ]; then
  command -v gh >/dev/null 2>&1 || { echo "gh CLI not installed" >&2; exit 3; }

  echo; echo "## metadata"
  if meta=$(gh pr view "$num" --json number,title,state,author,baseRefName,headRefName,isDraft,additions,deletions,changedFiles,url \
    --template '{{.number}} {{.title}}
state:  {{.state}}{{if .isDraft}} (draft){{end}}
author: {{.author.login}}
base:   {{.baseRefName}} <- {{.headRefName}}
size:   +{{.additions}} -{{.deletions}} across {{.changedFiles}} files
url:    {{.url}}
' 2>&1); then printf '%s\n' "$meta"; else echo "UNAVAILABLE: metadata — $meta"; fi

  echo; echo "## checks"
  if checks=$(gh pr checks "$num" 2>&1); then printf '%s\n' "$checks" | head -20; else echo "UNAVAILABLE: checks — $checks"; fi

  if [ $want_files -eq 1 ]; then
    echo; echo "## changed files"
    if files=$(gh pr view "$num" --json files --jq '.files[] | "\(.additions + .deletions)\t\(.path)"' 2>&1); then
      total=$(printf '%s\n' "$files" | grep -c .)
      printf '%s\n' "$files" | sort -rn | head -60
      [ "$total" -gt 60 ] && echo "PARTIAL: 60 of $total files shown, ranked by churn — list the rest with: gh pr view $num --json files"
      echo "NOT INCLUDED: file contents. pr-fetch.md Step C requires the full current"
      echo "contents of every file you comment on — read them yourself before judging."
    else echo "UNAVAILABLE: changed files — $files"; fi
  fi

  if [ $want_threads -eq 1 ]; then
    echo; echo "## review threads (pass each through _shared/evidence-filter.md)"
    owner=$(gh repo view --json owner --jq .owner.login 2>/dev/null)
    name=$(gh repo view --json name --jq .name 2>/dev/null)
    q='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){
         reviewThreads(first:100){totalCount nodes{isResolved isOutdated path line
           comments(first:50){totalCount nodes{author{login} body}}}}}}}'
    if th=$(gh api graphql -f query="$q" -F o="$owner" -F r="$name" -F n="$num" --jq '
        .data.repository.pullRequest.reviewThreads as $t
        | "threads: \($t.totalCount) total, \($t.nodes | map(select(.isResolved | not)) | length) unresolved in this page",
          ($t.nodes[] | "[\(if .isResolved then "RESOLVED" else "UNRESOLVED" end)\(if .isOutdated then ",outdated" else "" end)] \(.path):\(.line // "?") — \(.comments.totalCount) comment(s)",
            (.comments.nodes[] | "  [\(.author.login)] \(if (.body|length) > 600 then (.body[0:600] + " …[TRUNCATED]") else .body end | gsub("\n"; " "))"))' 2>&1); then
      printf '%s\n' "$th"
      printf '%s\n' "$th" | grep -q '^threads: 0 ' && echo "(no inline review threads)"
    else
      echo "UNAVAILABLE: review threads via GraphQL — $th"
      echo "Falling back to inline comments without resolution state:"
      gh api "repos/{owner}/{repo}/pulls/$num/comments" --paginate \
        --jq '.[] | "[\(.user.login)] \(.path):\(.line // .original_line // "?")\n  \(.body | gsub("\n"; " "))"' 2>&1 \
        || echo "UNAVAILABLE: inline comments"
      echo "PARTIAL: resolution state and threading are missing from this fallback."
    fi

    echo; echo "## conversation comments"
    if conv=$(gh pr view "$num" --json comments --jq '.comments[] | "[\(.author.login)] \(.body | gsub("\n"; " "))"' 2>&1); then
      printf '%s\n' "$conv" | grep -q . && printf '%s\n' "$conv" || echo "(none)"
    else echo "UNAVAILABLE: conversation comments — $conv"; fi
  fi

  if [ $want_diff -eq 1 ]; then
    echo; echo "## diff"
    if d=$(gh pr diff "$num" 2>&1); then
      dl=$(printf '%s\n' "$d" | wc -l | tr -d ' ')
      printf '%s\n' "$d" | head -400
      [ "$dl" -gt 400 ] && echo "PARTIAL: 400 of $dl diff lines — full diff: gh pr diff $num"
    else echo "UNAVAILABLE: diff — $d"; fi
  fi

else
  if command -v az >/dev/null 2>&1; then
    echo; echo "## metadata"
    az repos pr show --id "$num" \
      --query '{title:title,status:status,author:createdBy.displayName,source:sourceRefName,target:targetRefName}' \
      -o yaml 2>/dev/null || echo "UNAVAILABLE: metadata (az repos needs the devops extension and a login)"
    [ $want_files -eq 1 ] && { echo; echo "## changed files"; echo "UNAVAILABLE: not implemented for Azure DevOps — use CAP:ADO, or git diff against the target branch"; }
    [ $want_diff -eq 1 ] && { echo; echo "## diff"; echo "UNAVAILABLE: not implemented for Azure DevOps — use git diff <target>...<source>"; }
    [ $want_threads -eq 1 ] && { echo; echo "## review threads"; echo "UNAVAILABLE: az does not expose PR threads — fetch them via CAP:ADO before claiming the comments were gathered"; }
  else
    echo "az CLI not installed — use the CAP:ADO capability, see _shared/capabilities.md" >&2
    exit 3
  fi
fi

exit 0

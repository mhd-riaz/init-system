#!/usr/bin/env bash
# Run the test suite, with the two fallbacks that past sessions had to improvise.
#
#   agent-tools/test-run.sh                 # run the suite
#   agent-tools/test-run.sh --baseline      # record a clean-tree baseline
#   agent-tools/test-run.sh --compare       # run, then diff against the baseline
#   agent-tools/test-run.sh -- <cmd...>     # force a specific command
#
# Two problems this exists for:
#   B14 — a project wrapper that aborts at the first failing package cannot produce a
#         per-package table; fall back to the native runner's machine-readable output.
#   B15 — "that failure is pre-existing" is an assertion without a baseline to compare.
#
# Never reads .env; test configuration comes from the project's own loader.

set -uo pipefail

# Stay in the caller's directory — the module may live in a subdirectory of the repo
# (monorepos, or a Go module under <repo>/service/). Only resolve the root for state.
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
baseline="${root}/.agent/test-baseline.txt"
mode=run

case "${1:-}" in
  --baseline) mode=baseline; shift ;;
  --compare)  mode=compare; shift ;;
  --) shift ;;
esac
[ "${1:-}" = "--" ] && shift

detect() {
  if [ -f go.mod ]; then           echo "go test ./... -json"
  elif [ -f package.json ]; then
    grep -q '"test"' package.json && echo "npm test --silent" || echo ""
  elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.cfg ]; then
    echo "python3 -m pytest -q"
  elif [ -f Cargo.toml ]; then     echo "cargo test"
  else echo ""; fi
}

# cfg <key> — read testing.<key> from .agent/config.yml. Exact: a line-scraping grep
# leaks the section heading and the sibling *_command keys into the command string.
cfg() {
  python3 - "$root/.agent/config.yml" "$1" <<'PY' 2>/dev/null
import re, sys
try:
    lines = open(sys.argv[1], errors="ignore").read().splitlines()
except OSError:
    sys.exit(0)
want, inblock, indent = sys.argv[2], False, None
for ln in lines:
    if not inblock:
        inblock = re.match(r"^testing:\s*(#.*)?$", ln) is not None
        continue
    if not ln.strip() or ln.lstrip().startswith("#"):
        continue
    cur = len(ln) - len(ln.lstrip())
    if cur == 0:
        break                                  # next top-level section
    if indent is None:
        indent = cur
    if cur != indent:
        continue                               # nested block, e.g. coverage:
    m = re.match(r"\s*([\w-]+):\s*(.*)$", ln)
    if m and m.group(1) == want:
        v = re.sub(r"\s+#.*$", "", m.group(2)).strip()
        if len(v) > 1 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        print(v)
        break
PY
}

if [ $# -gt 0 ]; then
  cmd="$*"
else
  [ "$mode" = baseline ] && cmd=$(cfg baseline_command)
  [ -z "${cmd:-}" ] && cmd=$(cfg command)
  [ -z "$cmd" ] && cmd=$(detect)
fi

[ -z "$cmd" ] && { echo "no test command detected; pass one after --" >&2; exit 2; }

echo "# command: $cmd"
out=$(mktemp)
# shellcheck disable=SC2086
eval $cmd >"$out" 2>&1
status=$?

# B14: a wrapper that stops at the first failure hides the rest. Re-run natively.
# Only when the output is NOT already machine-readable — JSON has no ok/FAIL lines,
# so counting them on JSON would misfire and trigger a pointless full re-run.
if [ $status -ne 0 ] && [ -f go.mod ] && ! grep -q '"Action"' "$out" 2>/dev/null; then
  pkgs=$(grep -cE '^(ok|FAIL|---)' "$out" 2>/dev/null || echo 0)
  if [ "${pkgs:-0}" -lt 3 ]; then
    echo "# wrapper aborted early (${pkgs} package lines); re-running natively for the full table"
    cmd=$(cfg per_package_command); [ -z "$cmd" ] && cmd="go test ./... -json"
    eval $cmd >"$out" 2>&1
    status=$?
  fi
fi

summary=$(mktemp)
ids=$(mktemp)
if grep -q '"Action"' "$out" 2>/dev/null; then
  python3 - "$out" "$ids" > "$summary" <<'PY'
import json, sys
from collections import defaultdict
pkg = defaultdict(lambda: {"pass":0,"fail":0,"skip":0})
pkg_result = {}
failures = set()
for line in open(sys.argv[1], errors="ignore"):
    line = line.strip()
    if not line.startswith("{"): continue
    try: e = json.loads(line)
    except Exception: continue
    a, p = e.get("Action"), e.get("Package")
    if not p or a not in ("pass", "fail", "skip"): continue
    if e.get("Test"):
        pkg[p][a] += 1
        if a == "fail": failures.add(f"{p}::{e['Test']}")
    else:
        # Package-level result. A cached run emits only these, with no per-test events.
        pkg_result[p] = a
        if a == "fail": failures.add(p)
for p in sorted(set(pkg) | set(pkg_result)):
    c = pkg[p]
    if c["pass"] or c["fail"] or c["skip"]:
        print(f"{p:60} pass:{c['pass']:<5} fail:{c['fail']:<4} skip:{c['skip']}")
    else:
        print(f"{p:60} {pkg_result.get(p,'?'):<6} (no per-test events; cached)")
# A package whose own result is fail only because a subtest failed is not a second
# identity; drop it when any test under it is already recorded.
failures -= {f.split("::")[0] for f in failures if "::" in f}
open(sys.argv[2], "w").write("".join(sorted(f + "\n" for f in failures)))
PY
else
  grep -iE '^(ok|FAIL|PASS|---|[0-9]+ (passed|failed))|passed|failed' "$out" | tail -40 > "$summary"
  # Failure identities, not summary lines: a changed pass count must not read as new.
  grep -oE '^(--- FAIL: [[:alnum:]_/]+|FAILED [^[:space:]]+|FAIL[[:space:]]+[^[:space:]]+|not ok [0-9]+ - .*)' "$out" \
    | sed 's/^--- FAIL: /test::/; s/^FAILED /test::/; s/^FAIL[[:space:]]*/pkg::/; s/^not ok [0-9]* - /test::/' \
    | sort -u > "$ids"
fi

scope=$(python3 -c 'import os,sys; print(os.path.relpath(os.getcwd(), sys.argv[1]))' "$root" 2>/dev/null || echo .)
rev=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)

case $mode in
  baseline)
    mkdir -p "$(dirname "$baseline")"
    {
      echo "# command: $cmd"
      echo "# scope: $scope"
      echo "# revision: $rev"
      echo "# recorded: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      cat "$ids"
    } > "$baseline"
    echo "# baseline recorded: $baseline ($(grep -cv '^#' "$baseline" || true) failing identities)"
    cat "$summary"
    ;;
  compare)
    cat "$summary"
    echo
    if [ -f "$baseline" ]; then
      base_cmd=$(sed -n 's/^# command: //p' "$baseline" | head -1)
      base_scope=$(sed -n 's/^# scope: //p' "$baseline" | head -1)
      [ -n "$base_cmd" ] && [ "$base_cmd" != "$cmd" ] && \
        echo "# WARNING: baseline command was '$base_cmd', this run used '$cmd' — not comparable"
      [ -n "$base_scope" ] && [ "$base_scope" != "$scope" ] && \
        echo "# WARNING: baseline scope was '$base_scope', this run was '$scope'"
      echo "# vs baseline @ $(sed -n 's/^# revision: //p' "$baseline" | head -1) — compared by failure identity, not summary text:"
      base_ids=$(mktemp); grep -v '^#' "$baseline" | sort -u > "$base_ids"
      new=$(comm -13 "$base_ids" "$ids"); fixed=$(comm -23 "$base_ids" "$ids")
      if [ -n "$new" ]; then echo "$new" | sed 's/^/  NEW FAILURE  /'; else echo "  no new failures"; fi
      [ -n "$fixed" ] && echo "$fixed" | sed 's/^/  fixed        /'
      rm -f "$base_ids"
    else
      echo "# no baseline recorded; run --baseline on a clean tree first (AUDIT-LOG B15)"
    fi
    ;;
  *) cat "$summary" ;;
esac

echo "# exit=$status"
rm -f "$out" "$summary" "$ids"
exit $status

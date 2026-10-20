# `.agent/config.yml` — schema

The per-repository configuration read by [`../rules/repo-config.md`](../rules/repo-config.md).
Every section is optional; omit what does not apply. A missing key falls back to
detection, then to asking the user.

## Contents

- [Full example](#full-example)
- [tracker](#tracker)
- [code_host](#code_host)
- [identity](#identity)
- [skills](#skills)
- [devlog](#devlog)
- [testing](#testing)
- [review](#review)
- [Precedence](#precedence)

---

## Full example

```yaml
version: 1

tracker:
  system: ado                      # ado | github | none
  org: <company>
  project: Bridge
  area_path: Bridge\Observability
  iteration_path: Bridge\Sprint 42
  commit_prefix: "AB#{id} - "
  pr_title_prefix: "AB#{id} : "
  pr_title_max: 59
  default_priority: 2

code_host:
  system: github                   # github | ado
  owner: <company>-cto
  repo: bdg-eng-tops-obs-sms-server
  default_branch: main

identity:
  display_name: Mohamed Riaz
  email: mohamed.riaz@<company>.com

skills:
  disabled: []                     # e.g. [study-notes, ado-item]

devlog:
  dir: docs/devlog/{email}
  filename: "{yyyy}-{mon}-{name}.devlog.md"
  order: reverse-chronological

testing:
  command: ./unit-test.sh
  per_package_command: go test ./... -json
  baseline_command: go test ./... -json
  coverage:
    backend: 90
    frontend: 80
    critical: 95
    pr_changed_files: 75

review:
  automated_reviewer: copilot
  require_before_close:
    - pr_exists
    - unit_tests
    - baseline_unbroken
    - commit_prefix
    - review_done
    - closing_comment
```

---

## tracker

Where work items live. **This is not necessarily where the code lives.**

| Key | Meaning |
| --- | --- |
| `system` | `ado`, `github`, or `none`. `none` disables every work-item step silently |
| `org` / `project` | Azure DevOps organization and project; ignored for GitHub |
| `area_path` / `iteration_path` | defaults for new items |
| `commit_prefix` | prepended to commit messages; `{id}` is substituted |
| `pr_title_prefix` | prepended to PR titles; `{id}` is substituted |
| `pr_title_max` | maximum title length including the prefix |
| `default_priority` | priority assigned when the user does not specify one |

The separators differ by design — `AB#{id} -` for commits, `AB#{id} :` for PR titles.
Do not normalise them (`AUDIT-LOG.md` B18).

## code_host

Where branches, PRs and CI live. Set it whenever it differs from `tracker.system`.

| Key | Meaning |
| --- | --- |
| `system` | `github` or `ado` |
| `owner` / `repo` | used to construct PR and API calls |
| `default_branch` | base for diffs; detected from the remote when absent |

## identity

Who to assign work to. Falls back to `{{STATE_GLOBAL}}/tracker-identity.md`, then to the
git config user.

## skills

`disabled` is a list of skill names. A listed skill declines in one line when triggered.
It cannot prevent the skill from loading — see `AUDIT-LOG.md` B22.

## devlog

| Key | Meaning |
| --- | --- |
| `dir` | directory holding entries; `{email}` and `{name}` are substituted |
| `filename` | convention; `{yyyy}`, `{mon}`, `{name}` are substituted |
| `order` | `reverse-chronological` (newest first) or `chronological` |

When set, `devlog` uses these directly and skips discovery entirely.

## testing

| Key | Meaning |
| --- | --- |
| `command` | the normal suite command |
| `per_package_command` | machine-readable fallback when `command` aborts early (`AUDIT-LOG.md` B14) |
| `baseline_command` | used to record the clean-tree baseline (`AUDIT-LOG.md` B15) |
| `coverage.*` | per-scope targets overriding the defaults in [`test-and-coverage.md`](test-and-coverage.md) |

## review

| Key | Meaning |
| --- | --- |
| `automated_reviewer` | the bot expected to have reviewed before close |
| `require_before_close` | which [`definition-of-done.md`](definition-of-done.md) checks apply here |

Omit `require_before_close` to apply all six.

---

## Precedence

Highest wins:

1. What the user said in this session
2. `.agent/config.yml`
3. Cached state under `{{STATE_REPO}}` / `{{STATE_GLOBAL}}`
4. Detection from the git remote
5. Ask the user

Never ask for something the config already answers. Never let a cache override the
config — the config is the declaration, the cache is only a performance aid.

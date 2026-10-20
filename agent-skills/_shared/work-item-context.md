# Work-item context resolution

How skills obtain tracker identity, project context, and work-item data without
re-interrogating the user. Shared by `ado-item`, `gh-issue`, `write-code`,
`pr-description`, and `devlog`.

## Resolution ladder

**Fastest path: run [`../agent-tools/repo-facts.sh`](../agent-tools/README.md) once.** It
returns the remote, code host, branch, default branch, tracker (config or detected),
config presence and stack in a single call, replacing six to eight separate git
invocations.

Run this **only for values you do not already have.** If a value is known from the
user's message or an earlier step this session, skip it — do not re-resolve.

1. **The user's current message** — explicit org, project, repo, item id, assignee.
2. **`.agent/config.yml`** — the repository's own declaration. See
   [`repo-config.md`](repo-config.md).
3. **Session context** — anything already resolved earlier in this session.
4. **Repo cache** — `{{STATE_REPO}}/tracker-context.md`.
5. **Global cache** — `{{STATE_GLOBAL}}/tracker-identity.md`.
6. **Git remote** — a fallback only; see the warning below.
7. **Ask the user** — one batched round, only for what remains.

> If the user already provided the project, item id, or assignee, extract it. Do not ask
> again. Re-asking for something already given is the most common way a skill becomes
> annoying.

## Platform detection

**The code host is not necessarily the work tracker.** Detecting the tracker from the
git remote is wrong whenever they differ — which is the normal case in this setup
(`AUDIT-LOG.md` B21):

```
origin   github.com/<owner>/<repo>          <- code, branches, PRs
items    dev.azure.com/<org>/<project>      <- work items
link     AB#<id> in the commit message      <- Azure Boards GitHub integration
```

So: **read `tracker.system` from `.agent/config.yml` first.** Only when no config file
exists may you fall back to inferring from the remote, and when you do, say so and offer
to write a config file.

| Fallback signal (no config present) | Assume | Skill |
|---|---|---|
| remote on `dev.azure.com` / `visualstudio.com` | Azure DevOps | `ado-item` |
| remote on `github.com` / `*.ghe.com`, **and** commits carry an `AB#` prefix | Azure DevOps tracker on a GitHub host | `ado-item` |
| remote on `github.com` / `*.ghe.com` with no `AB#` history | GitHub | `gh-issue` |
| no remote, or ambiguous | ask, listing what was detected | — |

Check for the `AB#` signal with `git --no-pager log --oneline -20`. It is the cheapest
reliable discriminator when the config is missing.

## Cache files

**`{{STATE_GLOBAL}}/tracker-identity.md`** — stable across repos:

```markdown
- display_name: <name>
- email: <email>
- ado_identity_id: <guid, if applicable>
- github_login: <login, if applicable>
```

**`{{STATE_REPO}}/tracker-context.md`** — per repository:

```markdown
- platform: ado | github
- organization: <org>
- project: <project>            # ADO only
- repository: <repo>
- default_area_path: <path>     # ADO only
- default_iteration: <path>     # ADO only
- current_iteration_finish: <ISO-8601 date>
- default_labels: <list>        # GitHub only
```

## Freshness rules

- **Identity never expires.** Resolve once, reuse forever.
- **Repo context persists** until the repository or org changes.
- **Iteration/sprint data expires** when `current_iteration_finish` has passed —
  re-resolve then, not before.
- Caches are a performance optimization, never a source of truth for the item itself.
  **Always fetch the live item before updating it.**

## Writing to the cache

After resolving something durable, write it back. A value resolved three times is a
value that was never cached.

Use `CAP:MEMORY`; fall back to plain file writes. If neither is available, hold the
values in session only and say that they will need re-entry next session.

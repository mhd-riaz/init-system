# PR fetch procedure

Shared intelligence-gathering for `pr-review`, `resolve-pr`, and `pr-description`.
Referenced, never copied.

**Fastest path: `agent-tools/pr-context.sh <pr> --all`** runs Steps A, B and D and the
file *list* from Step C, in one call. It does **not** return file contents, it paginates
to a cap, and Azure DevOps threads are not implemented there.

Every section it cannot complete is labelled `PARTIAL:` or `UNAVAILABLE:` with the
remaining command. **Those labels are work, not noise.** An exhaustive request — "address
every review comment", "review the whole PR" — is not satisfied until each one is either
fetched by hand or reported to the user as unfetched. Never treat a capped list as the
complete set.

The steps below are the manual procedure and the degradation path.

## Step A — Identify the PR and platform

Resolve from, in order: a URL the user gave, a PR number plus the current repo, or the
current branch's open PR.

| Host pattern | Platform | Capability |
|---|---|---|
| `github.com`, `*.ghe.com` | GitHub | `CAP:GH` — prefer the `gh` CLI |
| `dev.azure.com`, `*.visualstudio.com` | Azure DevOps | `CAP:ADO` |

Extract: org/owner, project (ADO), repository, PR id.

If the platform is ambiguous, read the `origin` remote via `CAP:GIT` before asking.
Ask only if the remote is absent or unrecognised.

## Step B — Fetch metadata

Title, description, author, state, source and target branches, reviewers, labels,
linked work items or issues, CI/check status.

## Step C — Fetch the diff

1. The list of changed files with add/delete counts.
2. The **full current contents** of each changed file — not only the diff hunks.

The diff alone shows what changed but not what surrounds it. Reviewing from hunks
produces false positives about things handled a few lines away. For a very large PR,
fetch full contents for the files you will actually comment on, and say which you
reviewed from diff alone.

## Step D — Fetch existing comments

All review threads and inline comments, with file, line, author, **resolution state**,
and every reply. A list without resolution state cannot tell an open thread from a
settled one, so it cannot support "every comment addressed".

Pass every one through [`evidence-filter.md`](evidence-filter.md) before acting on or
re-raising any of it.

## Local alternative

When the branch is checked out, `CAP:GIT` is faster and always available:

```sh
git --no-pager diff --stat <base>...<head>
git --no-pager diff <base>...<head>
```

Use the platform capability for metadata and threads, local git for file contents.

## Degradation

| Unavailable | Do this |
|---|---|
| Platform MCP | Use the platform CLI (`gh`, `az repos`) |
| Platform CLI | REST API via `CAP:SHELL` + `curl` |
| All remote access | Review the local diff; state that comments and CI status were unavailable |

Never fabricate PR metadata or comment threads. If they could not be fetched, say so.

# Capabilities — the portable tool vocabulary

Skills in this bundle **never name a provider's tool**. They name a capability from the
table below. This file is the only place provider-specific names appear, so adding a
provider means editing one file instead of every skill.

Read this when a skill references a `CAP:` identifier and the right tool is not obvious.

## Contents

- [How to resolve a capability](#how-to-resolve-a-capability)
- [Core capabilities](#core-capabilities)
- [Integration capabilities](#integration-capabilities)
- [Degradation rules](#degradation-rules)
- [Model tiers](#model-tiers)

---

## How to resolve a capability

1. **Check what is already loaded.** If a tool matching the capability is in context,
   use it. Do not search again.
2. **Search by function, not by name.** Tool names differ per provider and many are
   deferred until searched for. Search the capability's *description* — "query library
   documentation", "run tests", "create work item" — not a guessed identifier.
3. **Take the first working match.** The names below are *hints with a shelf life*,
   not guarantees. A suffixed variant (`_s2`, `_se`, `2`) is the same tool.
4. **If nothing matches, degrade.** Follow the fallback chain for that capability. State
   the limitation in one line and continue. Never silently skip the step.

> Any skill that needs a deferred tool must say so: *call tool search for the capability
> first if it is not already loaded this session.* Do not assume preloading.

---

## Core capabilities

| CAP | What it does | Typical tool names | Fallback |
|---|---|---|---|
| `CAP:ASK` | Put a structured question to the user and wait | `ask_user`, `askQuestions`, `AskUserQuestion`, `elicit` | Ask in plain prose, one batched round |
| `CAP:READ` | Read a file, ideally a line range | `view`, `read_file`, `Read`, `str_replace_editor` | `sed -n 'A,Bp'` via `CAP:SHELL` |
| `CAP:EDIT` | Modify an existing file | `edit`, `str_replace`, `Edit`, `apply_patch`, `multi_replace_string_in_file` | Rewrite the file via `CAP:SHELL` heredoc |
| `CAP:CREATE` | Create a new file | `create`, `create_file`, `Write` | `CAP:SHELL` heredoc |
| `CAP:GLOB` | Find files by name pattern | `glob`, `file_search`, `Glob` | `find` via `CAP:SHELL` |
| `CAP:GREP` | Search file contents | `grep`, `grep_search`, `Grep`, `ripgrep` | `rg`/`grep` via `CAP:SHELL` |
| `CAP:SHELL` | Run a shell command | `bash`, `run_in_terminal`, `Bash`, `shell` | None — hard requirement |
| `CAP:SUBAGENT` | Delegate bounded work to a sub-agent | `task`, `runSubagent`, `Task`, `create_session` | Do the work inline; narrow the scope first |
| `CAP:TODO` | Track multi-step work | `sql` (todos table), `TodoWrite`, `manage_todo_list` | A checklist in the reply |
| `CAP:DIAGNOSTICS` | Compiler/linter errors without a build | `problems`, `get_errors`, `Diagnostics` | Run the build/linter via `CAP:SHELL` |
| `CAP:USAGES` | Find references to a symbol | `usages`, `vscode_listCodeUsages`, LSP references | `CAP:GREP` for the symbol name |
| `CAP:TEST-RUN` | Execute tests and return results | `runTests`, `run_vscode_command` + `testing.runAll`, `createAndRunTask` | The project's native runner via `CAP:SHELL` |
| `CAP:WEB` | Search or fetch a public URL | `websearch`, `web_search`, `web_fetch`, `WebFetch` | State that the lookup was unavailable |

---

## Integration capabilities

These depend on an MCP server or CLI being connected. Each has a CLI fallback that
usually survives when the MCP server does not.

| CAP | What it does | Typical tool names | Fallback chain |
|---|---|---|---|
| `CAP:DOCS` | Current library/framework documentation | Context7: `resolve-library-id` → `get-library-docs` | 1. Context7 MCP · 2. `CAP:WEB` on the official docs domain · 3. **State plainly that neither was available before answering from model knowledge** |
| `CAP:ADO` | Azure DevOps work items, PRs, pipelines | `wit_work_item*`, `repo_pull_request*`, `search_workitem` (often suffixed `azure_devops2`, `_s2`) | 1. ADO MCP — **try every registration, see below** · 2. `az boards` / `az repos` CLI · 3. REST API via `CAP:SHELL` + `curl` |
| `CAP:GH` | GitHub issues, PRs, Actions | `issue_read`, `pull_request_read`, `list_pull_requests` | 1. **`gh` CLI — preferred over MCP for GitHub** · 2. GitHub MCP · 3. REST via `curl` |
| `CAP:GIT` | Local git operations | `git_status`, `git_log_or_diff`, `git_commit` | `git` via `CAP:SHELL` — always available, prefer it |
| `CAP:MEMORY` | Durable state across sessions | `memory`, `store_memory`, `create_memory` | Read/write files under `{{STATE_GLOBAL}}` or `{{STATE_REPO}}` |
| `CAP:SESSION-QUERY` | Query past session history | `session_store_sql`, session DB | Grep the provider's session logs; if absent, say the history is unavailable |
| `CAP:BROWSER` | Drive a real browser | `openBrowserPage`, Chrome DevTools MCP, Playwright | Skip visual verification; state it was skipped |

### Duplicate server registrations

**The same MCP server is often registered more than once under different prefixes, and
one registration can fail every single time.** Measured over 90 days:
`microsoft-azure-devops-mcp-wit_work_item` succeeded **0 of 9** times, while
`Azure-DevOps-MCP-Server-wit_work_item` — the same logical tool — succeeded **4 of 4**
(`AUDIT-LOG.md` B11).

So: **one registration failing does not mean the capability is unavailable.** On error,
immediately retry the same operation through an alternate registration before falling
back down the chain. Note which one worked and keep using it for the rest of the session.

**Retry reads freely; never blind-retry a write.** A create, update, comment or link can
succeed remotely and still return an error or time out, so a reflex retry files the item
twice. Before retrying any mutation, query live state for the object you were writing —
by id, title, or the comment's first line — and continue only if it is absent. Where the
API offers an idempotency key or an "update if exists" call, use it instead of retrying.
"The call errored so it cannot have landed" is not an inference; it is a guess.

### GitHub note

Prefer the `gh` CLI over GitHub MCP tools when both exist. It is faster, scriptable,
authenticates from existing credentials, and does not consume a deferred-tool search.

---

## Degradation rules

The bundle must never hard-fail because a provider lacks a tool.

1. **Try the chain in order.** Stop at the first that works.
2. **Announce the degradation once**, in one line: *"Context7 unavailable; answering from
   official docs via web fetch."* Do not repeat it every step.
3. **Never substitute silence for a step.** If coverage cannot be measured, report
   "coverage unmeasured", not a guess and not nothing.
4. **Never fabricate the output of a missing capability.** An unavailable `CAP:ADO` means
   the work item was not updated — say so in the delivery report.
5. **`CAP:SHELL` is the floor.** Any environment without it cannot run this bundle;
   state that and stop.

---

## Model tiers

Skills delegate by **tier**, never by product name. Model strings change constantly and a
hardcoded one breaks on every other provider.

| Tier | Use for | Selection |
|---|---|---|
| `TIER:FAST` | extraction, lookup, mechanical edits, log triage, file discovery, summarizing known-format output | cheapest model the provider offers |
| `TIER:LONG` | same as FAST but large input, or a big context window is the binding constraint | provider's long-context model |
| `TIER:MAIN` | architecture, security review, root-causing a subtle bug, anything where being wrong is expensive | leave unset; inherit the session's model |

Rules:

- A `TIER:FAST` delegation needs a **narrow, closed-ended prompt** stating exactly what to
  return. Vague prompts to small models cost more in retries than they save.
- Never delegate a judgement you would not accept without re-checking. Verifying a bad
  answer costs more than producing a good one.
- Sub-agents do **not** inherit this bundle's rules. Every delegation prompt must restate
  the one-line secrets prohibition from [`../rules/no-secret-files.md`](../rules/no-secret-files.md).
- If the provider exposes no tier control, omit it and delegate on the default model.
- **A tier request can be rejected for reasons unrelated to availability.** A pinned
  model was once refused with *"Reasoning effort 'low' is not supported for model
  'claude-haiku-4.5'"* (`AUDIT-LOG.md` B12). On any rejection, **retry once on the
  provider's default model** rather than abandoning the delegation or reporting failure.

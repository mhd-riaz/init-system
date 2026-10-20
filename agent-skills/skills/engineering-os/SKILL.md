---
name: engineering-os
description: >
  Router into an on-demand library of atomic engineering rule files; opens only the 1 to 3
  files whose triggers match the task. USE FOR: the underlying rules for architecture,
  production code, code review, testing, performance, security, logging, observability, API
  or database design, CI/CD, documentation such as a README, ADR or runbook, refactoring,
  and planning. DO NOT USE FOR: trivial scripts or prose; current library documentation
  (use doc-lookup); work a named skill owns — implementation (write-code), tests
  (write-tests), PR review (pr-review).
license: MIT
metadata:
  version: 1.1.0
---

## Purpose

A router, not a rulebook. The rules live in an on-demand library of small, single-concern
files; this skill decides which one to two of them the current task actually needs and
opens only those.

Every other skill in this bundle that says "the underlying engineering rules" means this
one. It supplies rules to `write-code`, `write-tests` and `pr-review` — it never replaces
their workflows.

Library root: `{{SKILLS_DIR}}/skills/engineering-os/rules/`

Resolve every `CAP:` reference via
[`../../_shared/capabilities.md`](../../_shared/capabilities.md).

## Step 1 — Identify the signals

Read the task for two independent signals:

- **Category** — what kind of engineering judgement is being asked for. Route on the
  signal words in the table below, not on the topic of the code.
- **Technology** — a named language, framework, datastore or platform in the task or in
  the files being touched.

A task usually has exactly one category and at most one technology. If it appears to have
three categories, it is really a sequence of tasks; route the one being worked on now.

## Step 2 — Resolve the path

Take the category path. Add the technology path only when the technology genuinely changes
the rule rather than merely being present.

**Default for ambiguity:** when two categories are equally plausible, or no signal matches
cleanly, open `{{SKILLS_DIR}}/skills/engineering-os/rules/INDEX.md` and route from it.
Opening the index is always cheaper than opening three candidate files, and far cheaper
than stopping to ask.

## Category to path map

| Category | Signals in the task | Path | Reason the signals group this way |
|---|---|---|---|
| architecture | layers, hexagonal, DDD, microservice, CQRS, module boundary, bounded context, coupling, ADR | `rules/architecture/` | decisions that are expensive to reverse; the rules govern boundaries, not syntax |
| coding | implement, production code, error handling, naming, concurrency, null safety, idiomatic | `rules/coding/` | line-level craft inside a boundary someone else already drew |
| review | review, critique, is this correct, blocking comment, approve, nit | `rules/review/` | judging code you did not write, where tone and severity matter as much as correctness |
| testing | unit test, table test, mock, stub, fixture, flaky, coverage, test double | `rules/testing/` | rules about what to assert and what to isolate, not how to call a runner |
| performance | slow, latency, p99, allocation, N+1, profile, benchmark, hot path, memory | `rules/performance/` | measurement precedes change; the rules exist to stop speculative optimisation |
| security | auth, authz, token, injection, secret, CORS, encryption, OWASP, untrusted input | `rules/security/` | adversarial thinking; defaults that fail closed rather than open |
| logging | log level, structured log, correlation id, PII in logs, noisy log, log format | `rules/logging/` | logs are an interface with a cost, read under pressure during an incident |
| observability | metric, trace, span, SLO, SLI, alert, dashboard, cardinality, instrumentation | `rules/observability/` | what to emit so a failure is diagnosable before it is reproduced |
| api | endpoint, REST, gRPC, GraphQL, pagination, versioning, idempotency, status code, contract | `rules/api/` | public contracts; breaking them is a product event, not a code change |
| database | schema, index, migration, transaction, query plan, sharding, normalization, constraint | `rules/database/` | state outlives code, so the rules bias to reversibility |
| ci | pipeline, build, release, deploy, rollback, artifact, environment, gate | `rules/ci/` | automation others depend on; flaky or slow pipelines are a correctness problem |
| documentation | README, ADR, runbook, changelog, API docs, onboarding, comment policy | `rules/documentation/` | written for a reader with no context and no patience |
| refactoring | extract, rename, dead code, duplication, legacy, tech debt, seam, behaviour-preserving | `rules/refactoring/` | behaviour must not change, so the rules are about safety nets, not design taste |
| planning | milestone, PRD, SRS, estimate, break down, sequence, scope, dependency | `rules/planning/` | reducing an ambiguous ask to ordered, verifiable work |
| prompting | prompt, system message, agent instructions, tool description, eval, context budget | `rules/prompting/` | instructions are code for a non-deterministic runtime |

## Technology overlays

Add **at most one** of these on top of the category file, and only when the technology
changes the rule rather than merely appearing in the task.

| Signals | Path |
|---|---|
| Go, golang, goroutine, `go.mod`, context.Context | `rules/golang/` |
| React, hooks, JSX, component state | `rules/react/` |
| Next.js, app router, server component, RSC | `rules/nextjs/` |
| TypeScript, type narrowing, generics, `tsconfig` | `rules/typescript/` |
| Node, npm, pnpm, Express, event loop | `rules/node/` |
| MongoDB, aggregation pipeline, document model | `rules/mongodb/` |
| PostgreSQL, Postgres, psql, `EXPLAIN` | `rules/postgresql/` |
| Redis, cache, TTL, eviction | `rules/redis/` |
| Kubernetes, k8s, pod, deployment, ingress | `rules/kubernetes/` |
| Docker, Dockerfile, image, container | `rules/docker/` |
| Helm, chart, values.yaml | `rules/helm/` |
| GitHub Actions, workflow, runner, job matrix | `rules/github-actions/` |
| Prometheus, PromQL, scrape, recording rule | `rules/prometheus/` |
| Grafana, dashboard, panel | `rules/grafana/` |
| OpenTelemetry, OTel, exporter, span attributes | `rules/opentelemetry/` |
| AWS, S3, Lambda, IAM, ECS, CloudWatch | `rules/aws/` |

## Step 3 — Read only the matched files

Read the matched file or files with `CAP:READ`. One category file; at most one technology
file. Three is the ceiling and it needs a reason.

Do not list the directory and skim. Do not open neighbours "for context". Do not read the
whole category directory because the filenames look relevant — filenames are not triggers.

## Step 4 — Apply the rules to this task

Take the rules and checklists from the matched files and apply them to the actual change
in front of you: name the specific file, function, endpoint or query each rule bears on.

A rule that was read and not applied is worse than one never opened — it spent the tokens
and changed nothing. State which rules were applied, and name any that were deliberately
not applicable here.

## Step 5 — Follow cross-references only on demand

Matched files carry their own cross-references. Follow one **only when the task genuinely
touches that concern** — never speculatively, and never to be thorough.

"The security file links the logging file" is not a reason to open the logging file. "This
change writes a user token into a log line" is.

## When the library is absent

The rule files are **not shipped in this bundle yet**. If
`{{SKILLS_DIR}}/skills/engineering-os/rules/` does not exist, or the matched path is
missing, degrade rather than fail:

1. Say so in one line: *"No engineering-os rules installed for `security/`; applying general
   engineering judgement."*
2. Proceed with the task on general engineering judgement and the bundle's always-on rules.
3. Never invent a citation to a rule file that was not read.

## Related skills

| Situation | Skill |
|---|---|
| Implementing the change these rules govern | `write-code` |
| Designing scenarios, mocks and coverage | `write-tests` |
| Reviewing a pull request against these rules | `pr-review` |
| Current library or framework documentation | `doc-lookup` |
| Adding or editing a skill, including this one | `skill-creator` |

## Rules (token discipline)

- **Report which rule files were loaded, and which matched but were not run.** Naming
  both is what makes a mis-route visible instead of invisible — e.g. *"Skills used:
  engineering-os → milestone-planning.md (R1, R2). Matched-but-not-run: write-code."*
  (`AUDIT-LOG.md` B20).
- **Never bulk-read the library. Open only the 1 to 3 files whose triggers actually match.**
  The library is sized for selective reading; reading it whole converts a cheap router into
  the most expensive skill in the bundle and buries the matched rules in noise.
- Route on signal words, not on the topic of the code.
- One category file; at most one technology overlay. More than three files needs a stated reason.
- When routing is ambiguous, open `INDEX.md` — never guess across several candidate files,
  and never resolve the ambiguity by asking the user.
- Follow a cross-reference only when the task touches that concern.
- Apply the rules to named files and functions; do not restate them back as a summary.
- Never cite a rule file that was not read.
- If the library or a matched path is missing, state it in one line and continue on general
  judgement.

## Completion criteria

Done when the matched rule file or files have been read and their rules applied to the
current task — not merely opened — or, when the library is absent, that absence has been
stated in one line and the task continued on general engineering judgement.

## Outcome logging

Append one record per [`../../_shared/outcome-log.md`](../../_shared/outcome-log.md) to
`{{STATE_REPO}}/skill-outcomes.md`.

## Changelog

- 1.0.0 (2026-10-20) — initial portable version. Consolidates a sprawling always-loaded
  rule set into an on-demand library behind a signal-based router, with an explicit
  token-discipline prohibition and graceful degradation when the library is not installed.
- 1.1.0 (2026-10-20) — Added skill attribution reporting: name the rule files loaded and
  the skills matched-but-not-run, so a mis-route is visible (B20).

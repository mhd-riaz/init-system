# Security review checklist

Shared by `write-code` (applied while implementing) and `pr-review` (applied while
reviewing). Same checklist, two moments.

## Contents

- [Input and output](#input-and-output)
- [Authentication and authorization](#authentication-and-authorization)
- [Secrets and configuration](#secrets-and-configuration)
- [Data handling](#data-handling)
- [Dependencies and supply chain](#dependencies-and-supply-chain)
- [Resource safety](#resource-safety)
- [Reporting](#reporting)

---

## Input and output

- Every external input is validated at the boundary: type, range, length, format.
- Allow-lists over deny-lists.
- SQL/NoSQL via parameterized queries or a query builder — **never string concatenation**.
- Shell invocations never interpolate user input. Pass argument arrays, not strings.
- Output encoded for its sink: HTML escaping, JSON encoding, header sanitization.
- Path inputs resolved and confirmed inside the intended directory (traversal).
- Deserialization of untrusted data is type-constrained.

## Authentication and authorization

- Every non-public endpoint checks authentication.
- **Authorization is checked per resource, not just per route.** The common real bug:
  a valid user accessing another user's object by changing an ID.
- Tokens validated for signature, issuer, audience, and expiry.
- Session/token invalidation works on logout and on privilege change.
- Least privilege for service accounts and DB users.

## Secrets and configuration

- No credential, key, token, or connection string in source, tests, fixtures, logs, or
  error messages.
- Secrets come from the environment or a secret manager.
- Nothing security-relevant defaults to insecure when a config value is missing.
- Debug modes, verbose errors, and stack traces are off in production paths.

## Data handling

- PII and secrets never reach logs, traces, or analytics. Redact at the logging boundary.
- Transport is TLS; sensitive data at rest is encrypted.
- Error messages to users reveal nothing about internals — no stack traces, no SQL, no
  file paths.
- Deletion actually deletes, including caches and derived copies, where required.

## Dependencies and supply chain

- New dependencies are pinned and from a legitimate, maintained source.
- Check for known advisories before adding one.
- Prefer the standard library over a dependency for small needs.

## Resource safety

- Rate limiting on expensive or authentication-adjacent endpoints.
- Timeouts on every outbound call. No unbounded retry.
- Pagination caps on list endpoints; no unbounded result sets.
- Bounded memory for user-controlled sizes — upload limits, body size caps.
- Resources released on every path, including errors.

## Reporting

Report findings by severity, each with `file:line` and a concrete fix:

| Marker | Severity | Meaning |
|---|---|---|
| 🔴 | CRITICAL | exploitable now; blocks release |
| 🟠 | HIGH | serious; fix before merge |
| 🟡 | MEDIUM | should fix; not a merge blocker alone |
| ⚪ | LOW | hardening or defence in depth |

Every finding must be verified against the real code first — see
[`evidence-filter.md`](evidence-filter.md). A speculative security finding wastes more
time than it saves and trains the reader to ignore the next one.

# Repository configuration

Before doing repository work, read `.agent/config.yml` from the repository root if it
exists. It is the authoritative source for the tracker, code host, identity, and
conventions of **this** repository.

## Why it comes first

Inferring these from the git remote is wrong whenever the code host and the work tracker
are different systems — a GitHub remote whose work items live in Azure DevOps is the
common case, not an edge case (`AUDIT-LOG.md` B21). Detection is a fallback, not the
primary source.

## Procedure

1. Read `.agent/config.yml` once per task. Reuse it; do not re-read per step.
2. Use its values instead of asking the user for anything it already answers.
3. If a value is absent, fall back to detection, then to asking.
4. If the file does not exist, proceed on detection and offer to create one.

The full schema is in [`../_shared/repo-config.md`](../_shared/repo-config.md). Read it
only when a key's meaning is unclear.

## Disabled skills

If `skills.disabled` lists the skill that just triggered, **decline in one line and
stop**:

> `ado-item` is disabled for this repository (`.agent/config.yml`). Tell me to override
> if that is wrong.

A disabled skill still loads and can still trigger — a config file cannot prevent that
(`AUDIT-LOG.md` B22). Declining immediately is the enforcement point.

## No tracker

When `tracker.system: none`, skip every work-item step silently rather than asking which
tracker to use. The repository has deliberately opted out.

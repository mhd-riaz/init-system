#!/usr/bin/env python3
"""Validate every skill in this bundle against SPEC.md.

Usage:
    python3 agent-tools/validate.py [bundle-root]

Exits 0 when every skill is compliant, 1 otherwise.
Zero third-party dependencies required; uses PyYAML only if it is installed.
"""

import re
import sys
from pathlib import Path

ALLOWED_KEYS = {"name", "description", "license", "allowed-tools", "metadata"}
MAX_NAME = 64
MAX_DESCRIPTION = 600
MAX_BODY_LINES = 500

REQUIRED_HEADINGS = [
    "## Purpose",
    "## Related skills",
    "## Rules",
    "## Completion criteria",
    "## Outcome logging",
    "## Changelog",
]

# Provider-specific names that break portability. Skills must use CAP: identifiers.
BANNED_PATTERNS = [
    (r"\bmcp_[a-z0-9_]+", "provider-specific MCP tool name"),
    (r"\brunSubagent\b", "provider-specific sub-agent tool (use CAP:SUBAGENT)"),
    (r"\brun_vscode_command\b", "VS Code-specific tool (use CAP:TEST-RUN)"),
    (r"\bcreate_and_run_task\b", "VS Code-specific tool (use CAP:TEST-RUN)"),
    (r"\bClaude (Sonnet|Opus|Haiku) [\d.]+", "hardcoded model name (use TIER:)"),
    (r"\bGPT-[\d.]+\b", "hardcoded model name (use TIER:)"),
    (r"/memories/", "hardcoded state path (use {{STATE_GLOBAL}}/{{STATE_REPO}})"),
    (r"~/\.(copilot|claude|codex)/", "hardcoded provider path (use {{SKILLS_DIR}})"),
]

SEMVER = re.compile(r"^\d+\.\d+\.\d+$")
KEBAB = re.compile(r"^[a-z0-9-]+$")


def parse_frontmatter(text):
    """Return (dict, body, error). Falls back to a minimal parser without PyYAML."""
    if not text.startswith("---"):
        return None, None, "no YAML frontmatter (file must start with ---)"
    match = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.DOTALL)
    if not match:
        return None, None, "malformed frontmatter delimiters"
    raw, body = match.group(1), match.group(2)

    try:
        import yaml

        data = yaml.safe_load(raw)
        if not isinstance(data, dict):
            return None, None, "frontmatter must be a YAML mapping"
        return data, body, None
    except ImportError:
        pass
    except Exception as exc:
        return None, None, f"invalid YAML: {exc}"

    try:
        return _minimal_parse(raw), body, None
    except ValueError as exc:
        return None, None, f"invalid YAML: {exc} (PyYAML absent; reduced parser)"


def _minimal_parse(raw):
    """Handle the flat + one-level-nested + folded-scalar subset the spec allows.

    Raises ValueError on anything outside that subset. The previous version accepted
    malformed YAML silently, so a file that no provider could load still validated.
    """
    data, key, buffer, nested = {}, None, [], None
    for line in raw.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("\t"):
            raise ValueError("tab indentation is invalid in YAML")
        indented = line.startswith(" ")
        if indented:
            if key is None:
                raise ValueError(f"indented line with no parent key: {line.strip()[:40]!r}")
            stripped = line.strip()
            if nested is not None:
                if not re.match(r"^[\w-]+\s*:", stripped):
                    raise ValueError(f"not a mapping entry: {stripped[:40]!r}")
                k, _, v = stripped.partition(":")
                data[nested][k.strip()] = v.strip().strip("\"'")
            else:
                buffer.append(stripped)
            continue
        if key and buffer:
            data[key] = " ".join(buffer)
        buffer, nested = [], None
        if not re.match(r"^[\w-]+\s*:", line):
            raise ValueError(f"not a top-level mapping entry: {line.strip()[:40]!r}")
        k, _, v = line.partition(":")
        key = k.strip()
        v = v.strip()
        if v in (">", "|", ">-", "|-", ""):
            data[key] = ""
            if v == "":
                nested = key
                data[key] = {}
        else:
            data[key] = v.strip("\"'")
            key = None
    if key and buffer:
        data[key] = " ".join(buffer)
    return data


def known_capabilities(root):
    """CAP: identifiers defined in _shared/capabilities.md."""
    path = root / "_shared" / "capabilities.md"
    if not path.exists():
        return None
    return set(re.findall(r"`CAP:([A-Z][A-Z-]*)`", path.read_text(encoding="utf-8")))


def validate(skill_dir, known_caps=None):
    errors = []
    path = skill_dir / "SKILL.md"

    if not path.exists():
        return ["SKILL.md not found"]
    for wrong in skill_dir.glob("SKILL.*"):
        if wrong.name != "SKILL.md" and wrong.name.lower() == "skill.md":
            errors.append(f"{wrong.name} must be named exactly SKILL.md")

    text = path.read_text(encoding="utf-8")
    fm, body, err = parse_frontmatter(text)
    if err:
        return [err]

    unexpected = set(fm) - ALLOWED_KEYS
    if unexpected:
        errors.append(
            f"unexpected frontmatter key(s): {', '.join(sorted(unexpected))} "
            f"(allowed: {', '.join(sorted(ALLOWED_KEYS))})"
        )

    name = str(fm.get("name", "")).strip()
    if not name:
        errors.append("missing 'name'")
    else:
        if not KEBAB.match(name):
            errors.append(f"name '{name}' must be kebab-case [a-z0-9-]")
        if name.startswith("-") or name.endswith("-") or "--" in name:
            errors.append(f"name '{name}' has a leading/trailing or doubled hyphen")
        if len(name) > MAX_NAME:
            errors.append(f"name is {len(name)} chars, max {MAX_NAME}")
        if name != skill_dir.name:
            errors.append(f"name '{name}' != folder '{skill_dir.name}'")

    desc = str(fm.get("description", "")).strip()
    if not desc:
        errors.append("missing 'description'")
    else:
        if len(desc) > MAX_DESCRIPTION:
            errors.append(f"description is {len(desc)} chars, max {MAX_DESCRIPTION}")
        if "<" in desc or ">" in desc:
            errors.append("description contains angle brackets (rejected by Codex)")
        # Positive-only match: a naive 'USE FOR:' also matches inside 'DO NOT USE FOR:'.
        if not re.search(r"(^|[^T] )USE FOR:", desc):
            errors.append("description has no positive 'USE FOR:' triggers")
        if "DO NOT USE FOR:" not in desc:
            errors.append("description has no 'DO NOT USE FOR:' boundary")

    meta = fm.get("metadata")
    if not isinstance(meta, dict) or "version" not in meta:
        errors.append("missing 'metadata.version'")
    elif not SEMVER.match(str(meta["version"]).strip()):
        errors.append(f"metadata.version '{meta['version']}' is not MAJOR.MINOR.PATCH")

    headings = [ln.rstrip() for ln in body.split("\n") if ln.startswith("## ")]
    seen = {}
    for required in REQUIRED_HEADINGS:
        for index, heading in enumerate(headings):
            if heading.startswith(required):
                seen[required] = index
                break
        else:
            errors.append(f"missing required heading '{required}'")
    ordered = [seen[h] for h in REQUIRED_HEADINGS if h in seen]
    if ordered != sorted(ordered):
        errors.append("required headings are out of order (see SPEC.md section 3)")

    body_lines = len(body.split("\n"))
    if body_lines > MAX_BODY_LINES:
        errors.append(f"body is {body_lines} lines, max {MAX_BODY_LINES}")

    for pattern, why in BANNED_PATTERNS:
        for hit in set(re.findall(pattern, text)):
            found = hit if isinstance(hit, str) else hit[0]
            errors.append(f"non-portable reference '{found}' — {why}")

    # A link that resolves to nothing is a procedure the skill only claims to have.
    for target in set(re.findall(r"\]\(([^)\s]+)\)", text)):
        if re.match(r"^(https?:|mailto:|#|\{\{)", target):
            continue
        rel = target.split("#", 1)[0]
        if rel and not (skill_dir / rel).exists():
            errors.append(f"broken relative link '{target}'")

    if known_caps is not None:
        for cap in sorted(set(re.findall(r"CAP:([A-Z][A-Z-]*)", text))):
            if cap not in known_caps:
                errors.append(f"undefined capability 'CAP:{cap}' — not in _shared/capabilities.md")

    return errors


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent.parent)
    skills_dir = root / "skills"
    if not skills_dir.is_dir():
        print(f"no skills/ directory under {root}")
        return 1

    dirs = sorted(d for d in skills_dir.iterdir() if d.is_dir() and not d.name.startswith("_"))
    if not dirs:
        print("no skills found")
        return 1

    caps = known_capabilities(root)
    if caps is None:
        print("  !  _shared/capabilities.md not found; capability checks skipped")

    bad = 0
    for skill_dir in dirs:
        errors = validate(skill_dir, caps)
        if errors:
            bad += 1
            print(f"\n  {skill_dir.name}")
            for error in errors:
                print(f"    - {error}")
        else:
            print(f"  ok  {skill_dir.name}")

    print(f"\n{bad} non-compliant / {len(dirs)} skills")
    print("structure, portability and references only — not behaviour. A compliant "
          "bundle is not a working one.")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

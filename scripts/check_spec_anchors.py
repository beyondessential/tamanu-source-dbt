#!/usr/bin/env python3
"""Validate bidirectional consistency between spec `BL-XXX` clauses and code anchors.

Two passes:

1. **Code → spec (error):** every `# BL-XXX:` / `-- BL-XXX:` / `// BL-XXX:` comment
   in source must reference a BL clause that exists in some spec file.
2. **Spec → code (warning):** every `BL-XXX` clause in a spec should be referenced
   by at least one code anchor. Some BL clauses are configuration-only and won't
   have a code anchor; this is a warning, not an error.

Usage:
    python check_spec_anchors.py [--specs-dir specs] [--code-dir .]
                                 [--strict-spec-coverage]

Vendored from the maui-team repo (beyondessential/maui-team scripts/check_spec_anchors.py).
This repo is public and maui-team is private, so the script is copied in rather than
called via the private reusable `spec-check.yml` workflow. Keep in sync with the source.
Enforced in CI by scripts/tests/test_spec_anchors.py (runs under `pytest scripts/tests`).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Anchor comment in code (Python, SQL, YAML, JS, etc.). Captures the clause id.
ANCHOR_PATTERN = re.compile(
    r"(?:#|--|//)\s*(?P<id>BL-\d{3,4})\s*:",
)

# BL clause heading in a spec body. Matches the common templated form
# `- **BL-001:** …`, but also tolerates `**BL-001** …` and bare `BL-001:` lines.
SPEC_BL_PATTERN = re.compile(
    r"\*?\*?(?P<id>BL-\d{3,4})\*?\*?\s*[:\.]",
)

# File suffixes scanned for anchor comments.
CODE_SUFFIXES = {".py", ".sql", ".yml", ".yaml", ".js", ".ts", ".tsx", ".sh"}

# Directories to skip when walking the code tree.
SKIP_DIRS = {
    ".git",
    ".venv",
    "venv",
    "node_modules",
    "__pycache__",
    ".pytest_cache",
    ".ruff_cache",
    "target",
    "dbt_packages",
    "compiled",
    ".maui",
}


def collect_spec_ids(specs_dir: Path) -> dict[str, list[Path]]:
    """Return a map of BL-XXX -> list of spec files declaring it."""
    spec_ids: dict[str, list[Path]] = {}
    for spec_file in sorted(specs_dir.rglob("*.md")):
        text = spec_file.read_text(encoding="utf-8")
        # Look only at clause headings (lines that introduce a BL clause), not
        # arbitrary mentions of `BL-001` in prose. A heading is one of:
        #   - **BL-001:** ...    (bullet-bold)
        #   - **BL-001**: ...    (bold-then-colon)
        #   - BL-001: ...        (bare prefix)
        for line in text.splitlines():
            stripped = line.lstrip("- *").strip()
            m = SPEC_BL_PATTERN.match(stripped)
            if m:
                spec_ids.setdefault(m.group("id"), []).append(spec_file)
    return spec_ids


def collect_code_anchors(code_dir: Path) -> dict[str, list[tuple[Path, int]]]:
    """Return a map of BL-XXX -> list of (file, line_number) sites."""
    anchors: dict[str, list[tuple[Path, int]]] = {}
    for path in code_dir.rglob("*"):
        if path.is_dir():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix not in CODE_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in ANCHOR_PATTERN.finditer(line):
                anchors.setdefault(m.group("id"), []).append((path, lineno))
    return anchors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--specs-dir", default="specs", help="Path to specs directory (default: specs)")
    parser.add_argument("--code-dir", default=".", help="Root of code tree to scan (default: .)")
    parser.add_argument(
        "--strict-spec-coverage",
        action="store_true",
        help="Make 'spec BL with no code anchor' an error (default: warning)",
    )
    args = parser.parse_args()

    specs_dir = Path(args.specs_dir).resolve()
    code_dir = Path(args.code_dir).resolve()

    if not specs_dir.exists():
        print(f"No specs directory at {specs_dir} — skipping anchor check.")
        return 0

    spec_ids = collect_spec_ids(specs_dir)
    anchors = collect_code_anchors(code_dir)

    errors: list[str] = []
    warnings: list[str] = []

    # Pass 1: every code anchor must hit a spec clause.
    for bl_id, sites in anchors.items():
        if bl_id not in spec_ids:
            for site, lineno in sites:
                try:
                    rel = site.relative_to(code_dir)
                except ValueError:
                    rel = site
                errors.append(f"  {rel}:{lineno}: anchor {bl_id} not found in any spec")

    # Pass 2: every spec clause should have a code anchor (warning unless --strict).
    for bl_id in sorted(spec_ids):
        if bl_id not in anchors:
            for spec_file in spec_ids[bl_id]:
                try:
                    rel = spec_file.relative_to(Path.cwd())
                except ValueError:
                    rel = spec_file
                warnings.append(f"  {rel}: clause {bl_id} has no code anchor")

    if errors:
        print(f"\n{len(errors)} anchor error(s):\n")
        for line in errors:
            print(line)
        print(
            "\nEvery `# BL-XXX:` / `-- BL-XXX:` comment must reference a BL clause "
            "in a file under the specs directory."
        )

    if warnings:
        header = "error(s)" if args.strict_spec_coverage else "warning(s)"
        print(f"\n{len(warnings)} spec-coverage {header}:\n")
        for line in warnings:
            print(line)
        print(
            "\nThese BL clauses exist in specs but no code anchors reference them. "
            "Either add `# BL-XXX:` comments at the implementation site, or document "
            "why this BL is configuration-only."
        )

    fail = bool(errors) or (args.strict_spec_coverage and bool(warnings))
    if not fail:
        scanned_specs = sum(len(v) for v in spec_ids.values())
        scanned_anchors = sum(len(v) for v in anchors.values())
        print(
            f"OK: {len(spec_ids)} BL clauses across {scanned_specs} spec entries, "
            f"{len(anchors)} unique anchors across {scanned_anchors} code sites; "
            "all anchors resolve."
        )
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())

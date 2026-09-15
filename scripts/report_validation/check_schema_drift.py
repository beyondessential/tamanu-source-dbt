"""Detect drift between report-config-schema.json and the Tamanu source of truth.

The report configuration schema (``report-config-schema.json``) and its prose
companion (``documentations/tamanu-report-configuration-schema.md``) hard-code
several enums that are really snapshots of constants maintained in the Tamanu
repo. When Tamanu adds, removes, or renames a suggester endpoint, parameter
field type, date range, status, or data source, those snapshots silently drift
out of date — the schema then rejects valid configs or accepts invalid ones.

This check is run as part of the Tamanu upgrade workflow. It extracts the
authoritative sets from a Tamanu checkout and compares them against the schema,
reporting anything that has drifted so the maintainer can update the schema and
its doc in the upgrade PR.

Intentional divergences (the schema is deliberately stricter than Tamanu) are
listed in ``INTENTIONAL_DIVERGENCES`` and excluded from the drift gate.

Usage:
    python scripts/report_validation/check_schema_drift.py [--tamanu-dir PATH]
        [--fail-on-drift] [--github-output]

If ``--tamanu-dir`` is omitted the script shallow-clones the Tamanu release
branch matching the dbt project version (same mechanism as
``refresh_tamanu_source.py``).
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

# Console may be cp1252 on Windows; the report uses non-ASCII markers.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from utils import execute_command, get_deployment_version, remove_directory  # noqa: E402
from utils.system_utils import cprint  # noqa: E402

REPO_URL = "https://github.com/beyondessential/tamanu.git"
BASE_DIR = Path(__file__).resolve().parent.parent.parent
SCHEMA_PATH = BASE_DIR / "scripts" / "report_validation" / "report-config-schema.json"
TEMP_DIR = BASE_DIR / ".temp" / "tamanu-schema-check"

# Tamanu files (relative to a tamanu checkout root) that define the constants
# the schema mirrors. Used for sparse-checkout and for extraction.
SPARSE_PATHS = [
    "packages/constants/src/reports.ts",
    "packages/constants/src/suggesters.ts",
    "packages/constants/src/importable.ts",
    "packages/constants/src/imaging.ts",
    "packages/web/app/views/reports/ParameterField.jsx",
]

# Cases where the schema is intentionally stricter than Tamanu, so a difference
# here is by design and must not be reported as drift. Keep in sync with the
# rationale in documentations/tamanu-report-configuration-schema.md.
INTENTIONAL_DIVERGENCES = {
    # dbt reports always target the reporting schema, so the schema restricts
    # dbSchema to "reporting" even though Tamanu also allows "raw".
    "dbSchema",
}


def _strip_comments(text: str) -> str:
    """Remove ``//`` line and ``/* */`` block comments, ignoring markers inside
    string/template literals (so a value like ``http://...`` is preserved).

    Comment-stripping keeps the extractors from picking up commented-out enum
    entries or example snippets as if they were live values.
    """
    out = []
    i, n = 0, len(text)
    quote = None  # current string delimiter ('/"/`), or None when outside a string
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < n:  # escape — emit next char verbatim
                out.append(nxt)
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
        elif ch in ("'", '"', "`"):
            quote = ch
            out.append(ch)
            i += 1
        elif ch == "/" and nxt == "/":
            i += 2
            while i < n and text[i] != "\n":
                i += 1
        elif ch == "/" and nxt == "*":
            i += 2
            while i < n and not (text[i] == "*" and text[i + 1 : i + 2] == "/"):
                i += 1
            i += 2  # skip the closing */
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def read(checkout: Path, rel: str) -> str:
    path = checkout / rel
    if not path.exists():
        raise FileNotFoundError(
            f"Expected Tamanu file not found: {rel}. The Tamanu source layout may "
            f"have changed — update SPARSE_PATHS and the extractors in this script."
        )
    return _strip_comments(path.read_text(encoding="utf-8"))


def _object_body(text: str, name: str) -> str:
    """Return the brace-delimited body of ``export const NAME = { ... }``."""
    match = re.search(rf"(?:export\s+)?const\s+{re.escape(name)}\s*=\s*\{{", text)
    if not match:
        raise ValueError(f"Could not locate object `{name}` in Tamanu source")
    start = match.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    return text[start : i - 1]


def _array_body(text: str, name: str) -> str:
    """Return the bracket-delimited body of ``export const NAME = [ ... ]``."""
    match = re.search(rf"(?:export\s+)?const\s+{re.escape(name)}\s*=\s*\[", text)
    if not match:
        raise ValueError(f"Could not locate array `{name}` in Tamanu source")
    start = match.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == "[":
            depth += 1
        elif text[i] == "]":
            depth -= 1
        i += 1
    return text[start : i - 1]


def object_values(text: str, name: str) -> set[str]:
    """Extract the string-literal values from a ``KEY: 'value'`` object body."""
    body = _object_body(text, name)
    return set(re.findall(r"""[A-Z0-9_]+\s*:\s*['"]([^'"]+)['"]""", body))


def object_keys(text: str, name: str) -> set[str]:
    """Extract identifier keys from a shorthand object (e.g. component maps).

    Splits on commas and newlines so multiple keys on one line — or a key with
    a trailing comment/value — are each handled. Spreads (``...Foo``) are
    skipped; for ``Key: Value`` entries only the leading key is taken.
    """
    body = _object_body(text, name)
    keys = set()
    for chunk in re.split(r"[,\n]", body):
        chunk = chunk.strip()
        if not chunk or chunk.startswith("..."):
            continue
        m = re.match(r"^([A-Za-z_]\w*)\s*:?", chunk)
        if m:
            keys.add(m.group(1))
    return keys


def string_literals(body: str) -> set[str]:
    return set(re.findall(r"""['"]([A-Za-z][\w]*)['"]""", body))


def symbol_refs(body: str) -> set[str]:
    """``OTHER_REFERENCE_TYPES.LAB_TEST_PANEL`` style references."""
    return set(re.findall(r"\b[A-Z_]+\.([A-Z0-9_]+)", body))


def extract_tamanu(checkout: Path) -> dict[str, set[str]]:
    reports_ts = read(checkout, "packages/constants/src/reports.ts")
    suggesters_ts = read(checkout, "packages/constants/src/suggesters.ts")
    importable_ts = read(checkout, "packages/constants/src/importable.ts")
    imaging_ts = read(checkout, "packages/constants/src/imaging.ts")
    param_jsx = read(checkout, "packages/web/app/views/reports/ParameterField.jsx")

    # --- simple enums from reports.ts ---
    statuses = object_values(reports_ts, "REPORT_STATUSES")
    date_ranges = object_values(reports_ts, "REPORT_DEFAULT_DATE_RANGES")
    data_sources = object_values(reports_ts, "REPORT_DATA_SOURCES")
    db_connections = object_values(reports_ts, "REPORT_DB_CONNECTIONS")

    # --- parameter field types: keys of PARAMETER_FIELD_COMPONENTS ---
    param_fields = object_keys(param_jsx, "PARAMETER_FIELD_COMPONENTS")

    # --- suggester endpoints (composed across files) ---
    # REFERENCE_TYPES spreads IMAGING_AREA_TYPES, so union both objects' values.
    imaging_values = object_values(imaging_ts, "IMAGING_AREA_TYPES")
    reference_type_values = object_values(importable_ts, "REFERENCE_TYPES") | imaging_values
    other_reference_types = {}  # KEY -> value
    other_body = _object_body(importable_ts, "OTHER_REFERENCE_TYPES")
    for key, value in re.findall(r"""([A-Z0-9_]+)\s*:\s*['"]([^'"]+)['"]""", other_body):
        other_reference_types[key] = value

    # SUGGESTER_ENDPOINTS = [...SUGGESTER_ENDPOINTS_SUPPORTING_ALL, <literals>]
    # SUGGESTER_ENDPOINTS_SUPPORTING_ALL = [...REFERENCE_TYPE_VALUES, <OTHER_REFERENCE_TYPES.X refs>]
    supporting_body = _array_body(suggesters_ts, "SUGGESTER_ENDPOINTS_SUPPORTING_ALL")
    endpoints_body = _array_body(suggesters_ts, "SUGGESTER_ENDPOINTS")

    suggester_endpoints = set(reference_type_values)  # ...REFERENCE_TYPE_VALUES
    for body in (supporting_body, endpoints_body):
        suggester_endpoints |= string_literals(body)
        for key in symbol_refs(body):
            if key in other_reference_types:
                suggester_endpoints.add(other_reference_types[key])

    result = {
        "status": statuses,
        "defaultDateRange": date_ranges,
        "dataSources": data_sources,
        "dbSchema": db_connections,
        "parameterField": param_fields,
        "suggesterEndpoint": suggester_endpoints,
    }

    # Defensive: an empty extraction almost certainly means a layout change.
    for key, values in result.items():
        if not values:
            raise ValueError(
                f"Extracted no values for `{key}` from Tamanu — the source layout "
                f"likely changed. Update the extractor in this script."
            )
    return result


def extract_schema(schema_path: Path) -> dict[str, set[str]]:
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    opts = schema["properties"]["queryOptions"]["properties"]
    param = schema["definitions"]["parameter"]["properties"]
    return {
        "status": set(schema["properties"]["status"]["enum"]),
        "defaultDateRange": set(opts["defaultDateRange"]["enum"]),
        "dataSources": set(opts["dataSources"]["items"]["enum"]),
        "dbSchema": set(schema["properties"]["dbSchema"]["enum"]),
        "parameterField": set(param["parameterField"]["enum"]),
        "suggesterEndpoint": set(param["suggesterEndpoint"]["enum"]),
    }


LABELS = {
    "status": "status",
    "defaultDateRange": "queryOptions.defaultDateRange",
    "dataSources": "queryOptions.dataSources",
    "dbSchema": "dbSchema",
    "parameterField": "parameter.parameterField",
    "suggesterEndpoint": "parameter.suggesterEndpoint",
}


def compare(tamanu: dict, schema: dict) -> tuple[list[str], list[str]]:
    """Return (drift_report_lines, intentional_note_lines)."""
    drift = []
    notes = []
    for key in tamanu:
        missing = sorted(tamanu[key] - schema[key])  # in Tamanu, absent from schema
        extra = sorted(schema[key] - tamanu[key])  # in schema, absent from Tamanu
        if not missing and not extra:
            continue
        lines = []
        if missing:
            lines.append(f"  - missing (add to schema): {', '.join(missing)}")
        if extra:
            lines.append(f"  - stale (remove from schema): {', '.join(extra)}")
        block = [f"- **{LABELS[key]}**"] + lines
        if key in INTENTIONAL_DIVERGENCES:
            notes.append("\n".join(block) + "\n  - _(intentional divergence — not gated)_")
        else:
            drift.append("\n".join(block))
    return drift, notes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--tamanu-dir",
        help="Path to an existing Tamanu checkout. If omitted, the release branch "
        "matching the dbt project version is shallow-cloned.",
    )
    parser.add_argument("--schema", default=str(SCHEMA_PATH), help="Path to the schema JSON")
    parser.add_argument(
        "--fail-on-drift",
        action="store_true",
        help="Exit non-zero when drift is detected (for local/pre-commit use)",
    )
    parser.add_argument(
        "--github-output",
        action="store_true",
        help="Write drift flag to $GITHUB_OUTPUT and a summary to $GITHUB_STEP_SUMMARY",
    )
    parser.add_argument(
        "--report-file",
        help="Write the plain-markdown report (no ANSI colours) to this path",
    )
    args = parser.parse_args()

    cloned = False
    try:
        if args.tamanu_dir:
            checkout = Path(args.tamanu_dir).resolve()
            cprint(f"Using existing Tamanu checkout: {checkout}", "info")
        else:
            version = get_deployment_version()
            branch = f"release/{'.'.join(version.split('.')[:2])}"
            cprint(f"Sparse-cloning Tamanu branch '{branch}' for schema check", "info")
            if TEMP_DIR.exists():
                remove_directory(TEMP_DIR)
            execute_command(
                f"git clone --branch {branch} --depth 1 --filter=blob:none "
                f"--sparse {REPO_URL} {TEMP_DIR}"
            )
            # Mark cloned as soon as TEMP_DIR exists, so the finally block cleans
            # up even if the sparse-checkout step below fails.
            cloned = True
            # --no-cone matches gitignore-style patterns; a leading slash anchors
            # each pattern to a single file (silences the non-cone path warning).
            patterns = " ".join(f"/{p}" for p in SPARSE_PATHS)
            execute_command(
                f"git -C {TEMP_DIR} sparse-checkout set --no-cone {patterns}"
            )
            checkout = TEMP_DIR

        tamanu = extract_tamanu(checkout)
        schema = extract_schema(Path(args.schema))
        drift, notes = compare(tamanu, schema)
    finally:
        if cloned:
            remove_directory(TEMP_DIR)

    has_drift = bool(drift)

    if has_drift:
        report = [
            "### ⚠️ Report config schema drift detected",
            "",
            "`scripts/report_validation/report-config-schema.json` has drifted from "
            "the Tamanu source of truth. Update the schema enums **and** "
            "`documentations/tamanu-report-configuration-schema.md` to match:",
            "",
            *drift,
        ]
    else:
        report = ["### ✅ Report config schema is in sync with Tamanu"]
    if notes:
        report += ["", "Intentional divergences (informational):", "", *notes]
    report_text = "\n".join(report)

    cprint(report_text, "warning" if has_drift else "success")

    if args.report_file:
        Path(args.report_file).write_text(report_text + "\n", encoding="utf-8")

    if args.github_output:
        if out := os.environ.get("GITHUB_OUTPUT"):
            with open(out, "a", encoding="utf-8") as fh:
                fh.write(f"schema_drift={'true' if has_drift else 'false'}\n")
        if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(summary, "a", encoding="utf-8") as fh:
                fh.write(report_text + "\n")
        if has_drift:
            # Surface on the run even when no source-model files changed (so no
            # upgrade PR is opened). GitHub renders ::warning:: as an annotation.
            print(
                "::warning title=Report config schema drift::"
                "report-config-schema.json and its doc are out of sync with Tamanu "
                "— see the job summary."
            )

    if has_drift and args.fail_on_drift:
        return 3
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)

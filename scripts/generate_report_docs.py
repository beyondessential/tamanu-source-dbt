"""
Generate the standard report catalogue: a plain-language, versioned guide to every
published Tamanu report, aimed at people who run reports rather than build them.

dbt docs covers the model layer for technical users. This covers the question a
clinician, M&E officer or programme manager actually asks: "which report do I run,
what can I filter it by, and what columns will I get back?"

Everything is derived, never hand-written:

    models/reports/config/standard/*.json  ->  name, description, filters, date range
    models/reports/sql/standard/*.sql      ->  output columns, in order
    macros/reports/*.sql                   ->  columns for reports that delegate to a macro
    csv/report_translations_standard.csv   ->  the user-facing text of each column header

No database connection is required: the column headers come from the same
translation CSV that `translate_label` reads at compile time, so this can run
anywhere the repository is checked out.

Outputs, into compiled/v{VERSION}/:

    report-catalogue-v{VERSION}-{DEPLOYMENT}.html   self-contained, offline-capable site
    report-catalogue-v{VERSION}-{DEPLOYMENT}.json   the same data, machine-readable

Usage:
    python scripts/generate_report_docs.py
"""

import csv
import json
import os
import re
import sys
from pathlib import Path

import yaml

from utils.system_utils import cprint

BASE_DIR = Path(os.getcwd())


def _project_config():
    """Read dbt_project.yml, the source of both the version and the deployment name."""
    with open(BASE_DIR / "dbt_project.yml", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


_CONFIG = _project_config()
VERSION = _CONFIG["version"]
DEPLOYMENT = (
    "standard"
    if _CONFIG["name"] == "tamanu_source_dbt"
    else _CONFIG["name"].replace("tamanu_dbt_", "")
)
VERSION_DIR = BASE_DIR / "compiled" / f"v{VERSION}"

CONFIG_DIR = BASE_DIR / "models" / "reports" / "config" / "standard"
SENSITIVE_CONFIG_DIR = BASE_DIR / "models" / "reports" / "config" / "sensitive"
SQL_DIR = BASE_DIR / "models" / "reports" / "sql" / "standard"
MACRO_DIR = BASE_DIR / "macros" / "reports"
TRANSLATIONS_CSV = BASE_DIR / "csv" / "report_translations_standard.csv"
TEMPLATE = BASE_DIR / "scripts" / "templates" / "report_catalogue.html"

# The first release that shipped a catalogue. Earlier versions have no artifact to
# link to, so the in-page version picker starts here and grows with each release.
FIRST_CATALOGUE_VERSION = (2, 62)

# Matches a quoted output-column alias, e.g. `as "{{ translate_label('facility') }}"`.
# Report SQL uses quoted aliases only for the final, user-facing select; CTEs use
# bare snake_case, so this cannot pick up intermediate columns.
ALIAS_RE = re.compile(r'as\s+"([^"]*translate_label[^"]*)"', re.IGNORECASE)
LABEL_RE = re.compile(r"\{\{-?\s*translate_label\(\s*['\"]([^'\"]+)['\"].*?\)\s*-?\}\}")
MACRO_CALL_RE = re.compile(r"^\{\{-?\s*([a-z0-9_]+)\s*\(", re.IGNORECASE)
JINJA_RE = re.compile(r"\{\{.*?\}\}|\{%.*?%\}", re.DOTALL)

DATE_RANGES = {
    "24hours": "Last 24 hours",
    "7days": "Last 7 days",
    "30days": "Last 30 days",
    "18years": "Last 18 years",
    "next30days": "Next 30 days",
    "allTime": "All time",
}

DATA_SOURCES = {
    "thisFacility": "This facility",
    "allFacilities": "All facilities",
}

# How each filter behaves for the person running the report. Every parameterField
# in models/reports/config/standard is covered; unknown ones fall back to a generic
# description rather than failing the build.
FILTER_BEHAVIOUR = {
    "AppointmentTypeField": "Search and select an appointment type",
    "BookingTypeField": "Search and select a booking type",
    "DiagnosisField": "Search and select a diagnosis",
    "FacilityField": "Search and select a facility",
    "ImagingTypeField": "Search and select an imaging type",
    "LabTestCategoryField": "Search and select a lab test category",
    "ParameterAutocompleteField": "Type to search, then select a value",
    "ParameterMultiselectField": "Choose one or more options",
    "ParameterSelectField": "Choose one option from a list",
    "PatientField": "Search and select a patient",
    "PractitionerField": "Search and select a clinician",
    "VaccineCategoryField": "Search and select a vaccine category",
    "VaccineField": "Search and select a vaccine",
    "VillageField": "Search and select a village",
}


def load_translations():
    """
    Read csv/report_translations_standard.csv into {stringId: default text}.

    Returns:
        dict: Mapping of translation string ID to its default (English) text.
    """
    translations = {}
    with open(TRANSLATIONS_CSV, newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            string_id = row.get("stringId")
            if string_id and row.get("default"):
                translations[string_id] = row["default"]
    return translations


def resolve_label(key, translations):
    """
    Resolve a translate_label key to its display text.

    Mirrors the lookup order of the translate_label macro in macros/translations.sql:
    the 'report.reporting.' prefixed ID wins, then the bare ID, then the key itself.

    Args:
        key (str): The string ID passed to translate_label.
        translations (dict): Mapping from load_translations().

    Returns:
        str: The text a user sees as the column header.
    """
    return translations.get(f"report.reporting.{key}") or translations.get(key) or key


def resolve_alias(alias, translations):
    """
    Turn a raw SQL alias into the column header a user sees.

    An alias may combine several labels, e.g.
    "{{ translate_label('dischargeAssignedTime') }} {{ translate_label('dischargeDepartment') }}",
    so every label in the alias is resolved and the remaining Jinja is stripped.

    Args:
        alias (str): The raw text between the quotes of a SQL alias.
        translations (dict): Mapping from load_translations().

    Returns:
        str: The resolved, whitespace-normalised column header.
    """
    resolved = LABEL_RE.sub(lambda m: resolve_label(m.group(1), translations), alias)
    resolved = JINJA_RE.sub("", resolved)
    return " ".join(resolved.split())


def resolve_report_sql(report_id):
    """
    Read a report's SQL, following the macro when the model is a single macro call.

    Most reports hold their select list inline. A handful are one-line wrappers such
    as `{{ admissions_line_list_report(is_sensitive=false) }}`, whose columns live in
    macros/reports/. Those are followed to the macro definition.

    Args:
        report_id (str): The report's file stem, e.g. 'admissions-line-list'.

    Returns:
        tuple[str, str]: The SQL text and a repository-relative path describing its source.

    Raises:
        FileNotFoundError: If the report has no SQL model.
        ValueError: If a macro call cannot be resolved to a macro definition.
    """
    sql_path = SQL_DIR / f"{report_id}.sql"
    if not sql_path.is_file():
        raise FileNotFoundError(f"No SQL model for report '{report_id}' at {sql_path}")

    text = sql_path.read_text(encoding="utf-8")
    stripped = text.strip()
    match = MACRO_CALL_RE.match(stripped)

    # Only follow a wrapper whose entire body is the macro call; a report that merely
    # opens with a macro still holds its own select list.
    if match and stripped.count("{{") == 1:
        macro_name = match.group(1)
        definition = re.compile(r"\{%-?\s*macro\s+" + re.escape(macro_name) + r"\s*\(")
        for candidate in sorted(MACRO_DIR.rglob("*.sql")):
            candidate_text = candidate.read_text(encoding="utf-8")
            if definition.search(candidate_text):
                return candidate_text, str(candidate.relative_to(BASE_DIR))
        raise ValueError(f"Report '{report_id}' calls macro '{macro_name}', which was not found")

    return text, str(sql_path.relative_to(BASE_DIR))


def extract_columns(sql, translations):
    """
    Extract the report's output columns, in the order a user sees them.

    An alias that interpolates anything other than a translate_label call is
    generated from deployment reference data -- invoice-products-summary builds one
    column per configured price list, for instance. Those headers are not fixed, so
    they are reported as dynamic rather than documented as static columns.

    Args:
        sql (str): The report's SQL text.
        translations (dict): Mapping from load_translations().

    Returns:
        tuple[list[str], bool]: Resolved column headers, and whether the report also
            emits columns whose names depend on deployment reference data.
    """
    columns = []
    dynamic = bool(re.search(r"\{%-?\s*for\b", sql)) and bool(ALIAS_RE.search(sql))

    for alias in ALIAS_RE.findall(sql):
        if JINJA_RE.search(LABEL_RE.sub("", alias)):
            dynamic = True
            continue
        columns.append(resolve_alias(alias, translations))

    return columns, dynamic


def categorise(report_id, name):
    """
    Group a report by the kind of output it produces, using the project's own naming.

    Args:
        report_id (str): The report's file stem.
        name (str): The report's display name.

    Returns:
        str: The category heading the report is listed under.
    """
    haystack = f"{report_id} {name}".lower()
    if "audit" in haystack or "usage-quality" in haystack or "user-access" in haystack:
        return "Audit and data quality"
    if haystack.rstrip().endswith("summary") or "summary" in report_id:
        return "Summaries"
    if "line list" in haystack or "line-list" in report_id:
        return "Line lists"
    return "Other reports"


def describe_filter(parameter):
    """
    Describe one report filter in plain language.

    Args:
        parameter (dict): A queryOptions.parameters entry from the report config.

    Returns:
        dict: Label, behaviour, and the fixed options where the filter has them.
    """
    field = parameter.get("parameterField", "")
    behaviour = FILTER_BEHAVIOUR.get(field, "Select a value")
    if parameter.get("filterBySelectedFacility"):
        behaviour += ", limited to the facility you are logged in to"
    return {
        "label": parameter.get("label") or parameter.get("name", ""),
        "behaviour": behaviour,
        "options": [option.get("label", "") for option in parameter.get("options", [])],
    }


def sensitive_report_ids():
    """
    Report IDs that also have a sensitive-facility variant.

    Returns:
        set[str]: File stems with a matching sensitive-*.json config.
    """
    if not SENSITIVE_CONFIG_DIR.is_dir():
        return set()
    return {
        path.name[len("sensitive-") : -len(".json")]
        for path in SENSITIVE_CONFIG_DIR.glob("sensitive-*.json")
    }


def build_report(config_path, translations, sensitive_ids):
    """
    Build the catalogue entry for a single standard report.

    Args:
        config_path (Path): Path to the report's JSON config.
        translations (dict): Mapping from load_translations().
        sensitive_ids (set): Report IDs with a sensitive variant.

    Returns:
        dict: The report's catalogue entry.
    """
    config = json.loads(config_path.read_text(encoding="utf-8"))
    report_id = config_path.stem
    query_options = config.get("queryOptions", {})

    sql, source = resolve_report_sql(report_id)
    columns, dynamic_columns = extract_columns(sql, translations)
    name = config.get("name") or report_id.replace("-", " ").capitalize()

    return {
        "id": report_id,
        "name": name,
        "category": categorise(report_id, name),
        "status": config.get("status", ""),
        "description": (config.get("notes") or "").strip(),
        "filters": [describe_filter(p) for p in query_options.get("parameters", [])],
        "default_date_range": DATE_RANGES.get(
            query_options.get("defaultDateRange", ""),
            query_options.get("defaultDateRange", ""),
        ),
        "data_sources": [
            DATA_SOURCES.get(source_name, source_name)
            for source_name in query_options.get("dataSources", [])
        ],
        "columns": columns,
        "dynamic_columns": dynamic_columns,
        "has_sensitive_variant": f"{report_id}.json" in sensitive_ids
        or report_id in sensitive_ids,
        "schema": config.get("dbSchema", ""),
        "source_path": source,
    }


def released_versions():
    """
    Every M.m.x release that ships a catalogue, newest first.

    Derived from the committed compiled/ bundles, which are this project's
    distribution, and floored at the release that introduced the catalogue so the
    version picker never links to an artifact that was never built.

    Returns:
        list[str]: Version strings in M.m.x form, e.g. ['2.63.x', '2.62.x'].
    """
    versions = set()
    for path in (BASE_DIR / "compiled").glob("v*"):
        parts = path.name.lstrip("v").split(".")
        try:
            major, minor = int(parts[0]), int(parts[1])
        except (IndexError, ValueError):
            continue
        if (major, minor) >= FIRST_CATALOGUE_VERSION:
            versions.add((major, minor))

    current = tuple(int(part) for part in VERSION.split(".")[:2])
    if current >= FIRST_CATALOGUE_VERSION:
        versions.add(current)

    return [f"{major}.{minor}.x" for major, minor in sorted(versions, reverse=True)]


def build_catalogue():
    """
    Build the full catalogue for the standard report set.

    Returns:
        dict: Catalogue metadata plus every report entry, ordered by name.
    """
    translations = load_translations()
    sensitive_ids = sensitive_report_ids()

    reports = []
    for config_path in sorted(CONFIG_DIR.glob("*.json")):
        report = build_report(config_path, translations, sensitive_ids)
        if report["status"] and report["status"] != "published":
            cprint(f"Skipping '{report['id']}' (status: {report['status']})", "info")
            continue
        if not report["columns"]:
            cprint(f"Warning: no columns resolved for '{report['id']}'", "error")
        reports.append(report)

    return {
        "version": VERSION,
        "version_series": f"{'.'.join(VERSION.split('.')[:2])}.x",
        "deployment": DEPLOYMENT,
        "available_versions": released_versions(),
        "report_count": len(reports),
        "reports": sorted(reports, key=lambda report: report["name"].lower()),
    }


def render_html(catalogue):
    """
    Inject the catalogue into the HTML template as embedded data.

    Args:
        catalogue (dict): Output of build_catalogue().

    Returns:
        str: A self-contained HTML document.
    """
    template = TEMPLATE.read_text(encoding="utf-8")
    if "__CATALOGUE_DATA__" not in template:
        raise ValueError(f"{TEMPLATE} is missing the __CATALOGUE_DATA__ placeholder")

    # </script> inside the data would close the tag early; < keeps it inert
    # and still parses as the same JSON string.
    payload = json.dumps(catalogue, ensure_ascii=False).replace("<", "\\u003c")
    return template.replace("__CATALOGUE_DATA__", payload)


def main():
    """Generate the versioned report catalogue into compiled/v{VERSION}/."""
    cprint(f"\nGenerating report catalogue v{VERSION} ({DEPLOYMENT})", "info")

    catalogue = build_catalogue()
    VERSION_DIR.mkdir(parents=True, exist_ok=True)

    stem = f"report-catalogue-v{VERSION}-{DEPLOYMENT}"
    json_path = VERSION_DIR / f"{stem}.json"
    html_path = VERSION_DIR / f"{stem}.html"

    json_path.write_text(
        json.dumps(catalogue, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    html_path.write_text(render_html(catalogue), encoding="utf-8")

    columns = sum(len(report["columns"]) for report in catalogue["reports"])
    cprint(
        f"✓ {catalogue['report_count']} reports, {columns} documented columns", "success"
    )
    cprint(f"  {html_path.relative_to(BASE_DIR)}", "success")
    cprint(f"  {json_path.relative_to(BASE_DIR)}", "success")


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)

import json
import re
from pathlib import Path

from .dbt_utils import get_dbt_target_arg
from .file_utils import ensure_directory_exists, write_file
from .system_utils import cprint, execute_command_with_output

BASE_DIR = Path.cwd()
SURVEYS_DIR = BASE_DIR / "models" / "surveys"

# Prefixes the get_all_survey_docs macro logs before each survey and question row.
_LOGGED_ROW_MARKER = re.compile(r"(SURVEY_DATA|COLUMN_DATA):")

# Base columns emitted by the get_survey macro. A survey data element whose
# normalised code matches one of these is aliased to "<code>_answer" in the
# model SQL to avoid a duplicate-column collision; keep this in sync with the
# `reserved` list in macros/surveys.sql.
RESERVED_COLUMNS = {
    "encounter_id",
    "response_id",
    "patient_id",
    "start_datetime",
    "end_datetime",
    "result_text",
}


def get_surveys_with_columns_from_deployment():
    """
    Get every current survey and its questions from the database in a single
    dbt call, using the get_all_survey_docs macro.
    Returns:
        list: (survey_id, survey_name, columns) tuples, where columns is a list
            of (id, code, name) tuples in question order -- empty for a survey
            with no questions. Empty where the deployment has no surveys.
    Raises:
        RuntimeError: Where the dbt call itself failed, so a database that could
            not be read is not mistaken for surveys with no questions (#896).
    """
    cmd = f"dbt run-operation get_all_survey_docs --profiles-dir config{get_dbt_target_arg()}"
    try:
        result = execute_command_with_output(cmd, cwd=BASE_DIR)
    except Exception as e:
        cprint(f"Error getting surveys from dbt: {e}", "error")
        raise RuntimeError(f"Failed to list the deployment's surveys: {e}") from e

    if not result or result.returncode != 0:
        if result:
            # dbt writes its errors to stdout, so print both streams.
            output = "\n".join(
                stream.strip() for stream in (result.stdout, result.stderr) if stream and stream.strip()
            )
            cprint(f"Error running dbt command {cmd}:\n{output or '(dbt printed nothing)'}", "error")
        raise RuntimeError("Failed to list the deployment's surveys -- see error logged above")

    surveys = []
    columns_by_survey = {}
    for line in (result.stdout + result.stderr).split("\n"):
        # The first marker on the line is the row's own, so a name quoting the
        # other marker does not change how the row is read.
        marker = _LOGGED_ROW_MARKER.search(line)
        if not marker:
            continue
        if marker.group(1) == "SURVEY_DATA":
            surveys.append(tuple(_parse_logged_row(line, marker.end(), 2)))
        else:
            survey_id, *column = _parse_logged_row(line, marker.end(), 4)
            columns_by_survey.setdefault(survey_id, []).append(tuple(column))

    return [
        (survey_id, survey_name, columns_by_survey.get(survey_id, []))
        for survey_id, survey_name in surveys
    ]


def _parse_logged_row(line, start, field_count):
    """
    Read the JSON array the get_all_survey_docs macro logs from position start.
    Raises:
        RuntimeError: Where the line does not hold field_count fields, so a
            survey or question is never silently dropped.
    """
    try:
        fields, _ = json.JSONDecoder().raw_decode(line[start:].lstrip())
    except ValueError as e:
        raise RuntimeError(f"Could not read dbt output line: {line!r}") from e
    if not isinstance(fields, list) or len(fields) != field_count:
        raise RuntimeError(f"Expected {field_count} fields in dbt output line: {line!r}")
    return [str(field).strip() for field in fields]


def generate_survey_doc(survey_id, survey_name, columns):
    """
    Create a YML documentation file and MD documentation file for a survey.
    Args:
        survey_id (str): The survey identifier
        survey_name (str): The survey name
        columns (list): List of (id, code, name) tuples for the survey's questions,
            from get_surveys_with_columns_from_deployment. Callers must skip generation
            entirely for a survey with no questions -- see generate_survey_models.main().
    Returns:
        str: Path to the created documentation file
    """
    ensure_directory_exists(str(SURVEYS_DIR))

    survey_id = survey_id.replace("-", "_")
    # JSON string syntax is valid YAML, so a quote or backslash in the name is escaped.
    description = json.dumps(
        f"Dataset containing responses for **{survey_name}** survey", ensure_ascii=False
    )

    doc = ""
    yml = f"""version: 2

models:
  - name: {survey_id}
    description: {description}
    columns:
      - name: encounter_id
        description: '{{{{ doc("survey_responses__encounter_id") }}}}'
      - name: response_id
        description: '{{{{ doc("generic__id") }}}} in survey_responses.'
      - name: patient_id
        description: '{{{{ doc("encounters__patient_id") }}}}'
      - name: start_datetime
        description: '{{{{ doc("survey_responses__start_time") }}}}'
      - name: end_datetime
        description: '{{{{ doc("survey_responses__end_time") }}}}'
      - name: result_text
        description: '{{{{ doc("survey_responses__result_text") }}}}'"""

    doc_parts = []  
    yml_parts = []  
    for id, code, name in columns:  
        doc_id = id.replace("-", "_")
        prefixed_doc_id = f"{survey_id}__{doc_id}"
        
        column_name = f"{code}_answer" if code in RESERVED_COLUMNS else code

        doc_parts.append(f"""{{% docs {prefixed_doc_id} %}}\n{name.replace('"', "'")}\n{{% enddocs %}}""")
        yml_parts.append(f"""\n      - name: {column_name}\n        description: '{{{{ doc("{prefixed_doc_id}") }}}}'""")

    # Assuming 'doc' was initialized as an empty string  
    doc = "\n\n".join(doc_parts)  
    # 'yml' is appended to  
    yml += "".join(yml_parts)  

    md_file = SURVEYS_DIR / f"{survey_id}.md"
    write_file(str(md_file), doc.strip() + "\n")
    cprint(f"Created MD docs: {md_file}", "success")

    yml_file = SURVEYS_DIR / f"{survey_id}.yml"
    write_file(str(yml_file), yml.strip() + "\n")
    cprint(f"Created DBT docs: {yml_file}", "success")

    return str(yml_file)


def create_survey_model(survey_id):
    """
    Create an individual survey model file using the existing get_survey macro.
    Args:
        survey_id (str): The survey identifier
    """
    ensure_directory_exists(str(SURVEYS_DIR))

    model = f"{survey_id.replace('-', '_')}.sql"
    path = SURVEYS_DIR / model

    content = f"({{{{ get_survey('{survey_id}') }}}})"

    write_file(str(path), content)
    cprint(f"Created model: {path}", "success")
    return str(path)


def remove_survey_files(survey_id):
    """
    Remove any previously generated model/doc files for a survey.

    Model generation is not idempotent against its own output directory (it
    only ever writes, never clears): if a survey had questions on a previous
    run and has since been emptied, skipping generation for it leaves the
    stale .sql/.yml/.md from that earlier run in place, still pointing at
    get_survey() for a survey that no longer has anything to select. Call
    this when skipping a survey to remove that leftover.

    Args:
        survey_id (str): The survey identifier

    Returns:
        list[str]: Paths of any files that were removed
    """
    normalised_id = survey_id.replace("-", "_")
    removed = []
    for suffix in ("sql", "yml", "md"):
        path = SURVEYS_DIR / f"{normalised_id}.{suffix}"
        if path.exists():
            path.unlink()
            removed.append(str(path))
    return removed


def find_non_current_survey_models(current_survey_ids):
    """
    List generated survey models whose survey is no longer current.

    A survey that is retired or deleted in Tamanu drops out of the listing,
    but its model stays in models/surveys/, where a report may still read it.

    Args:
        current_survey_ids (iterable[str]): Ids of every current survey

    Returns:
        list[str]: Sorted paths of .sql models matching no current survey
    """
    if not SURVEYS_DIR.is_dir():
        return []
    current = {survey_id.replace("-", "_") for survey_id in current_survey_ids}
    return sorted(str(path) for path in SURVEYS_DIR.glob("*.sql") if path.stem not in current)

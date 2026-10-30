import json
from pathlib import Path

from .dbt_utils import get_dbt_target_arg
from .file_utils import ensure_directory_exists, write_file
from .system_utils import cprint, execute_command_with_output

BASE_DIR = Path.cwd()
SURVEYS_DIR = BASE_DIR / "models" / "surveys"

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


SURVEY_DOCS_MARKER = "SURVEY_DOCS_JSON:"


def get_survey_docs_from_deployment():
    """
    Get every current survey and its question columns from the database in a
    single dbt call, using the get_all_survey_docs macro. One call rather than
    one per survey: each dbt invocation pays its own startup, parse and
    connection, which is what made generation take minutes.

    Returns:
        list: (survey_id, survey_name, columns) for each survey, where columns
            is a list of (id, code, name) tuples in question order -- empty
            for a survey with no questions. Empty where the deployment
            genuinely has no surveys.
    Raises:
        RuntimeError: Where the dbt call itself failed, or its output carried
            no payload, so a database that could not be read is not mistaken
            for a deployment with no surveys or questions (#896).
    """
    cmd = f"dbt run-operation get_all_survey_docs --profiles-dir config{get_dbt_target_arg()}"
    try:
        result = execute_command_with_output(cmd, cwd=BASE_DIR)
        if not result or result.returncode != 0:
            if result:
                # dbt reports its own errors on stdout, not stderr.
                cprint(f"Error running dbt command {cmd}:\n {result.stdout}{result.stderr}", "error")
            raise RuntimeError("Failed to read the deployment's surveys -- see error logged above")

        payload = None
        for line in (result.stdout + result.stderr).split("\n"):
            if SURVEY_DOCS_MARKER in line:
                payload = json.loads(line.split(SURVEY_DOCS_MARKER, 1)[1])
                break
        if payload is None:
            raise RuntimeError(
                f"dbt ran but logged no {SURVEY_DOCS_MARKER} payload for the deployment's surveys"
            )

        columns_by_survey = {}
        for survey_id, column_id, code, name in payload["columns"]:
            columns_by_survey.setdefault(survey_id, []).append((column_id, code, name))

        return [
            (survey_id, survey_name, columns_by_survey.get(survey_id, []))
            for survey_id, survey_name in payload["surveys"]
        ]

    except RuntimeError:
        raise
    except Exception as e:
        cprint(f"Error getting surveys from dbt: {e}", "error")
        raise RuntimeError(f"Failed to read the deployment's surveys: {e}") from e


def render_survey_model(survey_id):
    """
    Render the model SQL for a survey, built on the existing get_survey macro.
    Args:
        survey_id (str): The survey identifier
    Returns:
        str: The model file content
    """
    return f"({{{{ get_survey('{survey_id}') }}}})"


def render_survey_doc(survey_id, survey_name, columns):
    """
    Render the MD and YML documentation for a survey.
    Args:
        survey_id (str): The survey identifier
        survey_name (str): The survey name
        columns (list): List of (id, code, name) tuples for the survey's questions,
            from get_survey_docs_from_deployment. Callers must skip generation
            entirely for a survey with no questions -- see generate_survey_models.main().
    Returns:
        tuple[str, str]: The MD and YML file content
    """
    survey_id = survey_id.replace("-", "_")

    yml = f"""version: 2

models:
  - name: {survey_id}
    description: "Dataset containing responses for **{survey_name}** survey"
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

    doc = "\n\n".join(doc_parts)
    yml += "".join(yml_parts)

    return doc.strip() + "\n", yml.strip() + "\n"


def write_survey_files(survey_id, survey_name, columns):
    """
    Write a survey's model, MD and YML files, skipping any whose content on
    disk already matches -- so an unchanged survey is never rewritten, and the
    diff after a run holds only the surveys whose questions actually changed.
    Args:
        survey_id (str): The survey identifier
        survey_name (str): The survey name
        columns (list): List of (id, code, name) tuples for the survey's questions
    Returns:
        list[str]: Paths of the files that were written
    """
    ensure_directory_exists(str(SURVEYS_DIR))

    normalised_id = survey_id.replace("-", "_")
    md, yml = render_survey_doc(survey_id, survey_name, columns)
    contents = {
        "sql": render_survey_model(survey_id),
        "md": md,
        "yml": yml,
    }

    written = []
    for suffix, content in contents.items():
        path = SURVEYS_DIR / f"{normalised_id}.{suffix}"
        # newline="" so a CRLF file on disk reads back as CRLF and is
        # rewritten as LF, rather than being normalised away and kept.
        if path.exists():
            with open(path, "r", encoding="utf-8", newline="") as f:
                if f.read() == content:
                    continue
        write_file(str(path), content)
        written.append(str(path))
    return written


def find_orphaned_survey_models(survey_ids):
    """
    Find generated survey models in models/surveys/ for surveys that are no
    longer current (retired or deleted). These are reported, not removed: a
    retired survey still holds responses, and a report may still select from
    its model.
    Args:
        survey_ids (iterable[str]): Identifiers of every current survey
    Returns:
        list[str]: Paths of generated model files with no current survey
    """
    if not SURVEYS_DIR.exists():
        return []
    current = {survey_id.replace("-", "_") for survey_id in survey_ids}
    return sorted(
        str(path)
        for path in SURVEYS_DIR.glob("*.sql")
        if path.stem not in current
        and path.read_text(encoding="utf-8").startswith("({{ get_survey('")
    )


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

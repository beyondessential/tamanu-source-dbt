from pathlib import Path

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


def get_surveys_from_deployment():
    """
    Get all surveys from the database using dbt using the get_surveys_list macro.
    Returns:
        list: List of tuples containing (id, code, name) for each survey
    """
    surveys = []
    cmd = f"dbt run-operation get_surveys_list --profiles-dir config"
    try:
        result = execute_command_with_output(cmd, cwd=BASE_DIR)
        if not result or result.returncode != 0:
            if result:
                cprint(f"Error running dbt command {cmd}:\n {result.stderr}", "error")
            return surveys

        for line in (result.stdout + result.stderr).split("\n"):
            if "SURVEY_DATA:" in line:
                parts = line.split("SURVEY_DATA:")[1].split("|")
                if len(parts) == 2:
                    surveys.append(tuple(part.strip() for part in parts))

        return surveys

    except Exception as e:
        cprint(f"Error getting surveys from dbt: {e}", "error")
        return surveys


def get_survey_columns_from_deployment(survey_id):
    """
    Get survey column information from the database using dbt using the get_survey_docs macro.
    Args:
        survey_id (str): The survey identifier

    Returns:
        list: List of tuples containing (code, name) for each survey column
    """
    columns = []
    cmd = f'dbt run-operation get_survey_docs --args "{{"survey_id": "{survey_id}"}}" --profiles-dir config'

    try:
        result = execute_command_with_output(cmd, cwd=BASE_DIR)

        if not result or result.returncode != 0:
            if result:
                cprint(f"Error running dbt command: {result.stderr}", "error")
            return columns

        for line in (result.stdout + result.stderr).split("\n"):
            if "COLUMN_DATA:" in line:
                parts = line.split("COLUMN_DATA:")[1].split("|")
                if len(parts) == 3:
                    columns.append(tuple(part.strip() for part in parts))

        return columns

    except Exception as e:
        cprint(f"Error getting survey columns from dbt: {e}", "error")
        return columns


def generate_survey_doc(survey_id, survey_name, columns):
    """
    Create a YML documentation file and MD documentation file for a survey.
    Args:
        survey_id (str): The survey identifier
        survey_name (str): The survey name
        columns (list): List of (id, code, name) tuples for the survey's questions,
            from get_survey_columns_from_deployment. Callers must skip generation
            entirely for a survey with no questions -- see create_survey_model.
    Returns:
        str: Path to the created documentation file
    """
    ensure_directory_exists(str(SURVEYS_DIR))

    survey_id = survey_id.replace("-", "_")

    doc = ""
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

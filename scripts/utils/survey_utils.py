import os
from pathlib import Path

from .file_utils import ensure_directory_exists, write_file
from .system_utils import cprint, execute_command_with_output

BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent.parent
SURVEYS_DIR = BASE_DIR / "models" / "surveys"


def get_surveys_from_deployment():
    """
    Get all surveys from the database using dbt using the get_surveys_list macro.
    Returns:
        list: List of tuples containing (id, name) for each survey
    """
    surveys = []
    cmd = f"dbt run-operation get_surveys_list --target {project} --profiles-dir config"
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
    cmd = ["dbt", "run-operation", "get_survey_docs", '--args', '{"survey_id": "' + f'{survey_id}' + '"}',
           "--profiles-dir", "config"]

    try:
        result = execute_command_with_output(cmd, cwd=BASE_DIR)

        if not result or result.returncode != 0:
            if result:
                cprint(f"Error running dbt command: {result.stderr}", "error")
            return columns

        for line in (result.stdout + result.stderr).split("\n"):
            if "COLUMN_DATA:" in line:
                parts = line.split("COLUMN_DATA:")[1].split("|")
                if len(parts) == 2:
                    columns.append(tuple(part.strip() for part in parts))

        return columns

    except Exception as e:
        cprint(f"Error getting survey columns from dbt: {e}", "error")
        return columns


def generate_survey_doc(survey_id, survey_name):
    """
    Create a YML documentation file for a survey.
    Args:
        project (str): The project name
        survey_id (str): The survey identifier
        survey_name (str): The survey name
    Returns:
        str: Path to the created documentation file
    """

    columns = get_survey_columns_from_deployment(survey_id)
    content = f"""version: 2

models:
  - name: {survey_id}
    description: "Dataset containing responses for '{survey_name}' survey"
    columns:
      - name: encounter_id
        description: '{{{{ doc("survey_responses__encounter_id") }}}}'
      - name: response_id
        description: '{{{{ doc("generic__id") }}}} in survey_responses.'
      - name: patient_id
        description: '{{{{ doc("encounters__patient_id") }}}}'
      - name: start_datetime
        description: '{{{{ doc("survey_responses__start_time") }}}}'
      - name: result_text
        description: '{{{{ doc("survey_responses__result_text") }}}}'
"""
    for code, name in columns:
        content += f"""      - name: {code}
        description: "{name.replace('"', "'")}"
"""

    ensure_directory_exists(str(SURVEYS_DIR))

    doc = f"{survey_id}.yml"
    path = SURVEYS_DIR / doc

    write_file(str(path), content)
    cprint(f"Created documentation: {path}", "success")
    return str(path)


def create_survey_model(survey_id):
    """
    Create an individual survey model file using the existing get_survey macro.
    Args:
        survey_id (str): The survey identifier
    """
    ensure_directory_exists(str(SURVEYS_DIR))

    model = f"{survey_id}.sql"
    path = SURVEYS_DIR / model

    content = f"""{{{{
    config(
        materialized='view',
        tags=['survey']
    )
}}}}

({{{{ get_survey('{survey_id}') }}}})
"""
    write_file(str(path), content)
    cprint(f"Created model: {path}", "success")
    return str(path)

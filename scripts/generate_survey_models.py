import sys
from pathlib import Path

from utils import ensure_directory_exists, get_surveys_from_dbt, write_file
from utils.system_utils import get_arg_value

BASE_DIR = Path(__file__).resolve().parent.parent
SURVEYS_DIR = BASE_DIR / "models" / "surveys"


def create_survey_model(project, survey_id):
    """
    Create an individual survey model file using the existing get_survey macro.

    Args:
        project (str): The project name
        survey_id (str): The survey identifier
    """
    project_dir = SURVEYS_DIR / project
    ensure_directory_exists(str(project_dir))

    model = f"survey_{project}__{survey_id}.sql"
    path = project_dir / model

    content = f"""{{{{
    config(
        materialized='view',
        tags=['survey', '{project}']
    )
}}}}

select * from ({{{{ get_survey('{survey_id}') }}}})
"""
    write_file(str(path), content)
    print(f"Created model: {path}")
    return str(path)


def main():
    try:
        project = get_arg_value(sys.argv, "--project", "-p")
        print(f"Generating survey models for project: {project}")
        surveys = get_surveys_from_dbt(project)
        models = []
        for survey_id, survey_name in surveys:
            print(f"Creating: {survey_name}")
            model_path = create_survey_model(project, survey_id)
            models.append(model_path)
        print(f"\nSuccessfully generated {len(models)} survey models!")

    except Exception as e:
        print(f"Error generating survey models: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

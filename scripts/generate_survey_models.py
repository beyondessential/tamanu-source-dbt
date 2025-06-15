import sys

from utils.survey_utils import (
    create_survey_model,
    generate_survey_doc,
    get_surveys_from_deployment,
)
from utils.system_utils import cprint, get_arg_value


def main():
    try:
        project = get_arg_value(sys.argv, "--project", "-p")
        cprint(f"Generating survey models for project: {project}", "info")

        surveys = get_surveys_from_deployment(project)
        total = len(surveys)

        for index, (survey_id, survey_name) in enumerate(surveys, 1):
            cprint(f"\n\nProgress: [{index}/{total}]", "warning")
            cprint(f"Creating: {survey_name}", "info")
            create_survey_model(project, survey_id)
            generate_survey_doc(project, survey_id, survey_name)

        cprint(f"Successfully generated {total} survey models!", "success")

    except Exception as e:
        cprint(f"Error generating survey models: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    main()

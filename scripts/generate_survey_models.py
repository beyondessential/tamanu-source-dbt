import sys

from utils.file_utils import clean_directory
from utils.survey_utils import (
    SURVEYS_DIR,
    create_survey_model,
    generate_survey_doc,
    get_surveys_from_deployment,
)
from utils.system_utils import cprint


def main():
    try:
        cprint(f"Generating survey models", "info")

        surveys = get_surveys_from_deployment()
        total = len(surveys)

        # Clean up existing survey models before regenerating
        cprint(f"\nCleaning up existing survey models...", "info")
        clean_directory(SURVEYS_DIR)

        cprint(f"\nGenerating {total} survey models...", "info")

        for index, (survey_id, survey_name) in enumerate(surveys, 1):
            cprint(f"\n\nProgress: [{index}/{total}]", "warning")
            cprint(f"Creating: {survey_name}", "info")
            create_survey_model(survey_id)
            generate_survey_doc(survey_id, survey_name)

        cprint(f"Successfully generated {total} survey models!", "success")

    except Exception as e:
        cprint(f"Error generating survey models: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    main()

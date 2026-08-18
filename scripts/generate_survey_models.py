import sys

from utils.survey_utils import (
    create_survey_model,
    generate_survey_doc,
    get_survey_columns_from_deployment,
    get_surveys_from_deployment,
)
from utils.system_utils import cprint


def main():
    try:
        cprint(f"Generating survey models", "info")

        surveys = get_surveys_from_deployment()
        total = len(surveys)
        skipped = 0

        for index, (survey_id, survey_name) in enumerate(surveys, 1):
            cprint(f"\n\nProgress: [{index}/{total}]", "warning")
            cprint(f"Creating: {survey_name}", "info")

            columns = get_survey_columns_from_deployment(survey_id)
            if not columns:
                # An empty survey (no questions) has nothing to model or
                # document -- skip it rather than emitting a stub model with
                # only the base columns.
                cprint(
                    f"Survey '{survey_name}' ({survey_id}) has no questions -- skipping",
                    "warning",
                )
                skipped += 1
                continue

            create_survey_model(survey_id)
            generate_survey_doc(survey_id, survey_name, columns)

        generated = total - skipped
        cprint(
            f"Successfully generated {generated} survey models ({skipped} skipped -- no questions)!",
            "success",
        )

    except Exception as e:
        cprint(f"Error generating survey models: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    main()

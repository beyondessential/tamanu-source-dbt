import sys

from utils.survey_utils import (
    create_survey_model,
    find_non_current_survey_models,
    generate_survey_doc,
    get_surveys_with_columns_from_deployment,
    remove_survey_files,
)
from utils.system_utils import cprint


def main():
    try:
        cprint(f"Generating survey models", "info")

        # One dbt call for every survey. A failed call raises rather than
        # reading as surveys with no questions (#896).
        surveys = get_surveys_with_columns_from_deployment()
        total = len(surveys)
        skipped = 0

        for index, (survey_id, survey_name, columns) in enumerate(surveys, 1):
            cprint(f"\n\nProgress: [{index}/{total}]", "warning")
            cprint(f"Creating: {survey_name}", "info")

            if not columns:
                # An empty survey (no questions) has nothing to model or
                # document -- skip it rather than emitting a stub model with
                # only the base columns. Also clear any model/doc left behind
                # by an earlier run from before the survey was emptied.
                cprint(
                    f"Survey '{survey_name}' ({survey_id}) has no questions -- skipping",
                    "warning",
                )
                removed = remove_survey_files(survey_id)
                if removed:
                    cprint(
                        f"Removed stale generated files for '{survey_id}': {', '.join(removed)}",
                        "warning",
                    )
                skipped += 1
                continue

            create_survey_model(survey_id)
            generate_survey_doc(survey_id, survey_name, columns)

        generated = total - skipped
        summary = f"Successfully generated {generated} survey models!"
        if skipped:
            summary = (
                f"Successfully generated {generated} survey models "
                f"({skipped} skipped -- no questions)!"
            )
        cprint(summary, "success")

        # Listed for review only: a report may still read one of these models.
        non_current = find_non_current_survey_models(survey_id for survey_id, _, _ in surveys)
        if non_current:
            cprint(
                f"\n{len(non_current)} survey model(s) belong to surveys that are no longer "
                "current in Tamanu. Review whether they are still needed:",
                "warning",
            )
            for path in non_current:
                cprint(f"  {path}", "warning")

    except Exception as e:
        cprint(f"Error generating survey models: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    main()

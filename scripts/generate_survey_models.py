import sys

from utils.survey_utils import (
    find_orphaned_survey_models,
    get_survey_docs_from_deployment,
    remove_survey_files,
    write_survey_files,
)
from utils.system_utils import cprint


def main():
    try:
        cprint(f"Generating survey models", "info")

        # One dbt call for every survey and its questions -- see
        # get_survey_docs_from_deployment for why it is not one per survey.
        surveys = get_survey_docs_from_deployment()
        total = len(surveys)
        skipped = 0
        updated = 0

        for survey_id, survey_name, columns in surveys:
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

            written = write_survey_files(survey_id, survey_name, columns)
            if written:
                updated += 1
                cprint(f"Updated: {survey_name}", "info")
                for path in written:
                    cprint(f"  Wrote {path}", "success")

        orphaned = find_orphaned_survey_models(survey_id for survey_id, _, _ in surveys)
        if orphaned:
            cprint(
                "Models kept for surveys that are no longer current (remove by hand "
                f"if nothing reports on them): {', '.join(orphaned)}",
                "warning",
            )

        generated = total - skipped
        summary = (
            f"Successfully generated {generated} survey models "
            f"({updated} updated, {generated - updated} unchanged)"
        )
        if skipped:
            summary += f", {skipped} skipped -- no questions"
        cprint(summary + "!", "success")

    except Exception as e:
        cprint(f"Error generating survey models: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    main()

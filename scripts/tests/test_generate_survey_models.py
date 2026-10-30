from unittest.mock import patch

import pytest

import generate_survey_models


def test_main_skips_survey_with_no_questions():
    # An empty survey (no questions) has nothing to model or document --
    # main() must skip write_survey_files for it rather than emitting a stub
    # model with only the base columns.
    real_columns = [("pde-q1", "q1", "Question one?")]
    surveys = [
        ("empty-survey", "Empty Survey", []),
        ("real-survey", "Real Survey", real_columns),
    ]

    with (
        patch(
            "generate_survey_models.get_survey_docs_from_deployment",
            return_value=surveys,
        ),
        patch(
            "generate_survey_models.write_survey_files", return_value=[]
        ) as mock_write_files,
        patch("generate_survey_models.remove_survey_files", return_value=[]),
        patch("generate_survey_models.find_orphaned_survey_models", return_value=[]),
    ):
        generate_survey_models.main()

    mock_write_files.assert_called_once_with("real-survey", "Real Survey", real_columns)


def test_main_removes_stale_files_for_skipped_survey():
    # Model generation only ever writes -- it never clears models/surveys/ --
    # so skipping a now-empty survey must explicitly remove any .sql/.yml/.md
    # left behind by an earlier run from before the survey was emptied.
    surveys = [("empty-survey", "Empty Survey", [])]

    with (
        patch(
            "generate_survey_models.get_survey_docs_from_deployment",
            return_value=surveys,
        ),
        patch(
            "generate_survey_models.remove_survey_files",
            return_value=["models/surveys/empty_survey.sql"],
        ) as mock_remove_files,
        patch("generate_survey_models.find_orphaned_survey_models", return_value=[]),
    ):
        generate_survey_models.main()

    mock_remove_files.assert_called_once_with("empty-survey")


def test_main_reports_but_keeps_models_of_surveys_no_longer_current():
    # A retired survey still holds responses a report may select from, so
    # its model is reported for a person to remove, never removed here.
    surveys = [("real-survey", "Real Survey", [("pde-q1", "q1", "Question one?")])]

    with (
        patch(
            "generate_survey_models.get_survey_docs_from_deployment",
            return_value=surveys,
        ),
        patch("generate_survey_models.write_survey_files", return_value=[]),
        patch(
            "generate_survey_models.find_orphaned_survey_models",
            return_value=["models/surveys/retired_survey.sql"],
        ) as mock_find_orphans,
        patch("generate_survey_models.remove_survey_files") as mock_remove_files,
    ):
        generate_survey_models.main()

    assert list(mock_find_orphans.call_args.args[0]) == ["real-survey"]
    mock_remove_files.assert_not_called()


def test_main_exits_nonzero_when_survey_fetch_fails():
    # Regression guard for #896: a failed dbt call must not be treated the
    # same as a deployment with no surveys or a survey with no questions --
    # main() must fail loudly rather than silently write or remove nothing.
    with (
        patch(
            "generate_survey_models.get_survey_docs_from_deployment",
            side_effect=RuntimeError("Failed to read the deployment's surveys"),
        ),
        patch("generate_survey_models.write_survey_files") as mock_write_files,
        patch("generate_survey_models.remove_survey_files") as mock_remove_files,
        pytest.raises(SystemExit) as exc_info,
    ):
        generate_survey_models.main()

    assert exc_info.value.code == 1
    mock_write_files.assert_not_called()
    mock_remove_files.assert_not_called()

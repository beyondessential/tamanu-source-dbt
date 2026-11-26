from unittest.mock import patch

import pytest

import generate_survey_models


def test_main_skips_survey_with_no_questions():
    # An empty survey (no questions) has nothing to model or document --
    # main() must skip both create_survey_model and generate_survey_doc for
    # it rather than emitting a stub model with only the base columns.
    real_columns = [("pde-q1", "q1", "Question one?")]
    surveys = [
        ("empty-survey", "Empty Survey", []),
        ("real-survey", "Real Survey", real_columns),
    ]

    with (
        patch(
            "generate_survey_models.get_surveys_with_columns_from_deployment",
            return_value=surveys,
        ),
        patch("generate_survey_models.create_survey_model") as mock_create_model,
        patch("generate_survey_models.generate_survey_doc") as mock_generate_doc,
        patch("generate_survey_models.remove_survey_files", return_value=[]),
    ):
        generate_survey_models.main()

    mock_create_model.assert_called_once_with("real-survey")
    mock_generate_doc.assert_called_once_with("real-survey", "Real Survey", real_columns)


def test_main_removes_stale_files_for_skipped_survey():
    # Model generation only ever writes -- it never clears models/surveys/ --
    # so skipping a now-empty survey must explicitly remove any .sql/.yml/.md
    # left behind by an earlier run from before the survey was emptied.
    surveys = [("empty-survey", "Empty Survey", [])]

    with (
        patch(
            "generate_survey_models.get_surveys_with_columns_from_deployment",
            return_value=surveys,
        ),
        patch(
            "generate_survey_models.remove_survey_files",
            return_value=["models/surveys/empty_survey.sql"],
        ) as mock_remove_files,
    ):
        generate_survey_models.main()

    mock_remove_files.assert_called_once_with("empty-survey")


def test_main_exits_nonzero_when_survey_fetch_fails():
    # Regression guard for #896: a failed dbt call must not be treated the
    # same as surveys with no questions -- main() must fail loudly, and
    # neither write nor remove any generated file.
    with (
        patch(
            "generate_survey_models.get_surveys_with_columns_from_deployment",
            side_effect=RuntimeError("Failed to list the deployment's surveys"),
        ),
        patch("generate_survey_models.create_survey_model") as mock_create_model,
        patch("generate_survey_models.generate_survey_doc") as mock_generate_doc,
        patch("generate_survey_models.remove_survey_files") as mock_remove_files,
        pytest.raises(SystemExit) as exc_info,
    ):
        generate_survey_models.main()

    assert exc_info.value.code == 1
    mock_create_model.assert_not_called()
    mock_generate_doc.assert_not_called()
    mock_remove_files.assert_not_called()


def test_main_reports_but_keeps_models_of_non_current_surveys(capsys):
    # A retired survey's model may still feed a report, so it is listed for
    # review and never removed.
    surveys = [("real-survey", "Real Survey", [("pde-q1", "q1", "Question one?")])]
    retired = "models/surveys/program_retired.sql"

    with (
        patch(
            "generate_survey_models.get_surveys_with_columns_from_deployment",
            return_value=surveys,
        ),
        patch("generate_survey_models.create_survey_model"),
        patch("generate_survey_models.generate_survey_doc"),
        patch("generate_survey_models.remove_survey_files") as mock_remove_files,
        patch(
            "generate_survey_models.find_non_current_survey_models",
            return_value=[retired],
        ) as mock_find,
    ):
        generate_survey_models.main()

    assert list(mock_find.call_args.args[0]) == ["real-survey"]
    mock_remove_files.assert_not_called()
    assert retired in capsys.readouterr().out

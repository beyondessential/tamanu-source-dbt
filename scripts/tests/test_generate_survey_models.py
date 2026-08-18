from unittest.mock import patch

import generate_survey_models


def test_main_skips_survey_with_no_questions():
    # An empty survey (no questions) has nothing to model or document --
    # main() must skip both create_survey_model and generate_survey_doc for
    # it rather than emitting a stub model with only the base columns.
    surveys = [("empty-survey", "Empty Survey"), ("real-survey", "Real Survey")]
    columns_by_survey = {
        "empty-survey": [],
        "real-survey": [("pde-q1", "q1", "Question one?")],
    }

    with (
        patch(
            "generate_survey_models.get_surveys_from_deployment", return_value=surveys
        ),
        patch(
            "generate_survey_models.get_survey_columns_from_deployment",
            side_effect=lambda survey_id: columns_by_survey[survey_id],
        ),
        patch("generate_survey_models.create_survey_model") as mock_create_model,
        patch("generate_survey_models.generate_survey_doc") as mock_generate_doc,
    ):
        generate_survey_models.main()

    mock_create_model.assert_called_once_with("real-survey")
    mock_generate_doc.assert_called_once_with(
        "real-survey", "Real Survey", columns_by_survey["real-survey"]
    )

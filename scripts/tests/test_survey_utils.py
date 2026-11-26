import ast
import re
from pathlib import Path

import pytest
import yaml

from utils.survey_utils import (
    RESERVED_COLUMNS,
    find_non_current_survey_models,
    generate_survey_doc,
    get_surveys_with_columns_from_deployment,
)

# repo root: scripts/tests -> scripts -> root
REPO_ROOT = Path(__file__).resolve().parents[2]
SURVEYS_MACRO = REPO_ROOT / "macros" / "surveys.sql"


def _reserved_from_macro():
    """Extract the `reserved` list literal from the get_survey macro."""
    text = SURVEYS_MACRO.read_text(encoding="utf-8")
    match = re.search(r"set\s+reserved\s*=\s*(\[.*?\])", text, re.DOTALL)
    assert match, "could not find `set reserved = [...]` in macros/surveys.sql"
    return set(ast.literal_eval(match.group(1)))


def test_reserved_columns_in_sync_with_macro():
    # The Python RESERVED_COLUMNS and the Jinja `reserved` list are
    # hand-maintained in two files and must stay identical, otherwise survey
    # data elements collide with base columns inconsistently across the
    # generated SQL and YAML. Guards the drift the cross-reference comment warns about.
    assert RESERVED_COLUMNS == _reserved_from_macro()


# ---------------------------------------------------------------------------
# generate_survey_doc -- columns are supplied by the caller, which is
# responsible for skipping generation entirely for a survey with no
# questions (see test_generate_survey_models.py)
# ---------------------------------------------------------------------------


def test_generate_survey_doc_writes_files_when_columns_present(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    columns = [("pde-q1", "q1", "Question one?")]

    generate_survey_doc("my-survey", "My Survey", columns)

    md = (tmp_path / "my_survey.md").read_text(encoding="utf-8")
    yml = (tmp_path / "my_survey.yml").read_text(encoding="utf-8")
    assert "Question one?" in md
    assert "name: q1" in yml


def test_a_quote_or_backslash_in_a_survey_name_keeps_the_yml_valid(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    name = 'Child "under 5" \\ adult'

    generate_survey_doc("my-survey", name, [("pde-q1", "q1", "Question one?")])

    yml = yaml.safe_load((tmp_path / "my_survey.yml").read_text(encoding="utf-8"))
    assert yml["models"][0]["description"] == f"Dataset containing responses for **{name}** survey"


# get_surveys_with_columns_from_deployment


class _Result:
    def __init__(self, returncode, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def _dbt_output(monkeypatch, stdout, stderr=""):
    calls = []

    def fake(cmd, cwd=None):
        calls.append(cmd)
        return _Result(0, stdout=stdout, stderr=stderr)

    monkeypatch.setattr("utils.survey_utils.execute_command_with_output", fake)
    return calls


def test_a_deployment_with_no_surveys_lists_none(monkeypatch):
    _dbt_output(monkeypatch, "nothing to report\n")

    assert get_surveys_with_columns_from_deployment() == []


def test_every_survey_and_its_questions_come_from_one_dbt_call(monkeypatch):
    calls = _dbt_output(
        monkeypatch,
        '10:00:00  SURVEY_DATA:["survey-a", "Survey A"]\n'
        '10:00:00  SURVEY_DATA:["survey-b", "Survey B"]\n'
        '10:00:00  COLUMN_DATA:["survey-a", "pde-1", "q1", "Question one?"]\n'
        '10:00:00  COLUMN_DATA:["survey-b", "pde-3", "q3", "Question three?"]\n'
        '10:00:00  COLUMN_DATA:["survey-a", "pde-2", "q2", "Question two?"]\n',
    )

    assert get_surveys_with_columns_from_deployment() == [
        (
            "survey-a",
            "Survey A",
            [("pde-1", "q1", "Question one?"), ("pde-2", "q2", "Question two?")],
        ),
        ("survey-b", "Survey B", [("pde-3", "q3", "Question three?")]),
    ]
    assert len(calls) == 1
    assert "get_all_survey_docs" in calls[0]


def test_a_survey_with_no_questions_has_empty_columns(monkeypatch):
    _dbt_output(monkeypatch, 'SURVEY_DATA:["empty-survey", "Empty Survey"]\n')

    assert get_surveys_with_columns_from_deployment() == [
        ("empty-survey", "Empty Survey", [])
    ]


def test_questions_of_unlisted_surveys_are_ignored(monkeypatch):
    # The column query reads every survey's questions, including surveys that
    # are deleted or not current; only listed surveys are returned.
    _dbt_output(
        monkeypatch,
        'SURVEY_DATA:["survey-a", "Survey A"]\n'
        'COLUMN_DATA:["retired-survey", "pde-9", "q9", "Old question"]\n',
    )

    assert get_surveys_with_columns_from_deployment() == [("survey-a", "Survey A", [])]


def test_a_pipe_or_newline_in_a_name_is_kept(monkeypatch):
    _dbt_output(
        monkeypatch,
        'SURVEY_DATA:["survey-a", "Survey A | adult"]\n'
        'COLUMN_DATA:["survey-a", "pde-1", "q1", "Systolic | diastolic\\nmmHg"]\n',
    )

    assert get_surveys_with_columns_from_deployment() == [
        ("survey-a", "Survey A | adult", [("pde-1", "q1", "Systolic | diastolic\nmmHg")])
    ]


def test_a_question_name_quoting_the_survey_marker_is_read_as_a_question(monkeypatch):
    _dbt_output(
        monkeypatch,
        'SURVEY_DATA:["survey-a", "Survey A"]\n'
        'COLUMN_DATA:["survey-a", "pde-1", "q1", "See SURVEY_DATA: notes"]\n',
    )

    assert get_surveys_with_columns_from_deployment() == [
        ("survey-a", "Survey A", [("pde-1", "q1", "See SURVEY_DATA: notes")])
    ]


def test_an_unreadable_row_fails_rather_than_dropping_a_question(monkeypatch):
    _dbt_output(
        monkeypatch,
        'SURVEY_DATA:["survey-a", "Survey A"]\n'
        'COLUMN_DATA:["survey-a", "pde-1", "q1"]\n',
    )

    with pytest.raises(RuntimeError, match="fields"):
        get_surveys_with_columns_from_deployment()


def test_a_failed_listing_is_not_an_empty_one(monkeypatch):
    monkeypatch.setattr(
        "utils.survey_utils.execute_command_with_output",
        lambda cmd, cwd=None: _Result(2, stderr="could not connect"),
    )

    with pytest.raises(RuntimeError, match="surveys"):
        get_surveys_with_columns_from_deployment()


def test_a_listing_that_raises_is_not_an_empty_one(monkeypatch):
    def boom(cmd, cwd=None):
        raise OSError("dbt is not on PATH")

    monkeypatch.setattr("utils.survey_utils.execute_command_with_output", boom)

    with pytest.raises(RuntimeError, match="surveys"):
        get_surveys_with_columns_from_deployment()


def test_a_failed_call_shows_the_error_dbt_wrote_to_stdout(monkeypatch, capsys):
    # dbt writes its errors to stdout, so a failed call prints stdout too.
    monkeypatch.setattr(
        "utils.survey_utils.execute_command_with_output",
        lambda cmd, cwd=None: _Result(
            1, stdout="Encountered an error:\nNo such file: models/surveys/x.md\n", stderr=""
        ),
    )

    with pytest.raises(RuntimeError, match="surveys"):
        get_surveys_with_columns_from_deployment()

    assert "No such file: models/surveys/x.md" in capsys.readouterr().out


# find_non_current_survey_models


def test_models_of_non_current_surveys_are_listed(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    for name in ("program_a_current.sql", "program_a_current.yml", "program_b_retired.sql"):
        (tmp_path / name).write_text("", encoding="utf-8")

    assert find_non_current_survey_models(["program-a-current"]) == [
        str(tmp_path / "program_b_retired.sql")
    ]


def test_no_surveys_directory_lists_nothing(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path / "missing")

    assert find_non_current_survey_models(["program-a"]) == []

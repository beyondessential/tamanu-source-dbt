import ast
import json
import re
from pathlib import Path

import pytest

from utils.survey_utils import (
    RESERVED_COLUMNS,
    find_orphaned_survey_models,
    get_survey_docs_from_deployment,
    write_survey_files,
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
# write_survey_files -- columns are supplied by the caller, which is
# responsible for skipping generation entirely for a survey with no
# questions (see test_generate_survey_models.py)
# ---------------------------------------------------------------------------


def test_write_survey_files_writes_model_and_docs(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    columns = [("pde-q1", "q1", "Question one?")]

    written = write_survey_files("my-survey", "My Survey", columns)

    assert len(written) == 3
    sql = (tmp_path / "my_survey.sql").read_text(encoding="utf-8")
    md = (tmp_path / "my_survey.md").read_text(encoding="utf-8")
    yml = (tmp_path / "my_survey.yml").read_text(encoding="utf-8")
    assert sql == "({{ get_survey('my-survey') }})"
    assert "Question one?" in md
    assert "name: q1" in yml


def test_write_survey_files_leaves_an_unchanged_survey_alone(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    columns = [("pde-q1", "q1", "Question one?")]
    write_survey_files("my-survey", "My Survey", columns)

    assert write_survey_files("my-survey", "My Survey", columns) == []


def test_write_survey_files_rewrites_only_what_changed(monkeypatch, tmp_path):
    # A renamed question changes the MD text only; the model SQL and the YML
    # (keyed on code and id) stay as they were.
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    write_survey_files("my-survey", "My Survey", [("pde-q1", "q1", "Question one?")])

    written = write_survey_files("my-survey", "My Survey", [("pde-q1", "q1", "Question 1?")])

    assert written == [str(tmp_path / "my_survey.md")]


def test_write_survey_files_rewrites_a_crlf_file(monkeypatch, tmp_path):
    # Same text with CRLF line endings is not the same file: it must be
    # rewritten as LF (see test_file_utils.py for why CRLF matters here).
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    columns = [("pde-q1", "q1", "Question one?")]
    write_survey_files("my-survey", "My Survey", columns)
    md = tmp_path / "my_survey.md"
    md.write_bytes(md.read_bytes().replace(b"\n", b"\r\n"))

    assert write_survey_files("my-survey", "My Survey", columns) == [str(md)]
    assert b"\r\n" not in md.read_bytes()


# find_orphaned_survey_models


def test_orphaned_models_are_generated_ones_with_no_current_survey(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    (tmp_path / "current_survey.sql").write_text("({{ get_survey('current-survey') }})")
    (tmp_path / "retired_survey.sql").write_text("({{ get_survey('retired-survey') }})")
    (tmp_path / "hand_written.sql").write_text("select 1")

    assert find_orphaned_survey_models(["current-survey"]) == [
        str(tmp_path / "retired_survey.sql")
    ]


def test_no_orphaned_models_without_a_surveys_directory(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path / "missing")

    assert find_orphaned_survey_models(["any-survey"]) == []


# get_survey_docs_from_deployment


class _Result:
    def __init__(self, returncode, stdout="", stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


def _dbt_log(surveys, columns):
    payload = json.dumps({"surveys": surveys, "columns": columns})
    return f"12:00:00  Running with dbt\n12:00:01  SURVEY_DOCS_JSON:{payload}\n"


def test_surveys_come_back_with_their_columns_in_order(monkeypatch):
    stdout = _dbt_log(
        [["survey-a", "Survey A"], ["survey-b", "Survey B"], ["survey-c", "Survey C"]],
        [
            ["survey-a", "pde-1", "q1", "First?"],
            ["survey-a", "pde-2", "q2", "Second?"],
            ["survey-b", "pde-3", "q3", "Has | pipe and\nline break"],
        ],
    )
    monkeypatch.setattr(
        "utils.survey_utils.execute_command_with_output",
        lambda cmd, cwd=None: _Result(0, stdout=stdout),
    )

    assert get_survey_docs_from_deployment() == [
        ("survey-a", "Survey A", [("pde-1", "q1", "First?"), ("pde-2", "q2", "Second?")]),
        ("survey-b", "Survey B", [("pde-3", "q3", "Has | pipe and\nline break")]),
        ("survey-c", "Survey C", []),
    ]


def test_a_deployment_with_no_surveys_lists_none(monkeypatch):
    monkeypatch.setattr(
        "utils.survey_utils.execute_command_with_output",
        lambda cmd, cwd=None: _Result(0, stdout=_dbt_log([], [])),
    )

    assert get_survey_docs_from_deployment() == []


def test_a_run_with_no_payload_is_not_an_empty_one(monkeypatch):
    monkeypatch.setattr(
        "utils.survey_utils.execute_command_with_output",
        lambda cmd, cwd=None: _Result(0, stdout="nothing to report\n"),
    )

    with pytest.raises(RuntimeError, match="surveys"):
        get_survey_docs_from_deployment()


def test_a_failed_listing_is_not_an_empty_one(monkeypatch):
    monkeypatch.setattr(
        "utils.survey_utils.execute_command_with_output",
        lambda cmd, cwd=None: _Result(2, stderr="could not connect"),
    )

    with pytest.raises(RuntimeError, match="surveys"):
        get_survey_docs_from_deployment()


def test_a_listing_that_raises_is_not_an_empty_one(monkeypatch):
    def boom(cmd, cwd=None):
        raise OSError("dbt is not on PATH")

    monkeypatch.setattr("utils.survey_utils.execute_command_with_output", boom)

    with pytest.raises(RuntimeError, match="surveys"):
        get_survey_docs_from_deployment()

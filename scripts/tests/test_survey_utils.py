import ast
import re
from pathlib import Path
from unittest.mock import patch

import pytest

from utils.survey_utils import RESERVED_COLUMNS, generate_survey_doc

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
# generate_survey_doc -- a survey with zero columns means the fetch failed,
# not that the survey is genuinely blank
# ---------------------------------------------------------------------------


def test_generate_survey_doc_raises_on_empty_columns(monkeypatch, tmp_path):
    # A real survey always has at least one question. An empty result means
    # get_survey_columns_from_deployment failed (network blip, encoding
    # error, permissions, ...) -- writing a stub doc/yml for that used to
    # succeed silently and only surface much later as a missing doc()
    # reference at dbt parse time in a downstream deployment repo.
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)

    with patch("utils.survey_utils.get_survey_columns_from_deployment", return_value=[]):
        with pytest.raises(RuntimeError, match="my-survey"):
            generate_survey_doc("my-survey", "My Survey")

    # must not leave behind a stub file that looks like real generated output
    assert list(tmp_path.iterdir()) == []


def test_generate_survey_doc_writes_files_when_columns_present(monkeypatch, tmp_path):
    monkeypatch.setattr("utils.survey_utils.SURVEYS_DIR", tmp_path)
    columns = [("pde-q1", "q1", "Question one?")]

    with patch(
        "utils.survey_utils.get_survey_columns_from_deployment", return_value=columns
    ):
        generate_survey_doc("my-survey", "My Survey")

    md = (tmp_path / "my_survey.md").read_text(encoding="utf-8")
    yml = (tmp_path / "my_survey.yml").read_text(encoding="utf-8")
    assert "Question one?" in md
    assert "name: q1" in yml

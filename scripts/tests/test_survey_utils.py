import ast
import re
from pathlib import Path

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

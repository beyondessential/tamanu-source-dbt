import ast
import re
from pathlib import Path

from utils.survey_utils import RESERVED_COLUMNS

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

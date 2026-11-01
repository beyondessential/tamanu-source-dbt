"""Every parameter a report config declares is read by the report's SQL, and the reverse.

Tamanu binds a declared parameter to null when the user leaves it blank and rejects a
placeholder the config does not declare. Nothing else checks that a declared parameter is
used, so a picker that filters nothing ships without an error.
"""

import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = ROOT / "models" / "reports" / "config"
SQL_DIR = ROOT / "models" / "reports" / "sql"
MACRO_DIR = ROOT / "macros"

# Tamanu always binds these, whether or not the config declares them.
ALWAYS_BOUND = {"fromDate", "toDate", "timezone", "currentFacilityId"}

PARAMETER_CALL = re.compile(r"""(?:parameter|date_param_bound)\(\s*['"](\w+)['"]""")
MACRO_CALL = re.compile(r"\{\{-?\s*(\w+)\s*\(")
MACRO_DEF = re.compile(r"\{%-?\s*macro\s+(\w+)\s*\(.*?%\}(.*?)\{%-?\s*endmacro", re.S)


def _macro_bodies():
    bodies = {}
    for path in MACRO_DIR.rglob("*.sql"):
        for name, body in MACRO_DEF.findall(path.read_text(encoding="utf-8")):
            bodies[name] = body
    return bodies


MACROS = _macro_bodies()


def _parameters_read(sql: str) -> set:
    """Parameter names read by `sql`, following macro calls transitively."""
    read, seen, pending = set(), set(), [sql]
    while pending:
        text = pending.pop()
        read |= set(PARAMETER_CALL.findall(text))
        for name in MACRO_CALL.findall(text):
            if name in MACROS and name not in seen:
                seen.add(name)
                pending.append(MACROS[name])
    return read


def _report_pairs():
    pairs = []
    for config in sorted(CONFIG_DIR.rglob("*.json")):
        category = config.parent.name
        sql = SQL_DIR / category / f"{config.stem}.sql"
        if sql.exists():
            pairs.append(pytest.param(config, sql, id=f"{category}/{config.stem}"))
    return pairs


@pytest.mark.parametrize("config_path, sql_path", _report_pairs())
def test_declared_parameters_match_parameters_read(config_path, sql_path):
    config = json.loads(config_path.read_text(encoding="utf-8"))
    declared = {p["name"] for p in config.get("queryOptions", {}).get("parameters", [])}
    read = _parameters_read(sql_path.read_text(encoding="utf-8"))

    unused = declared - read
    undeclared = read - declared - ALWAYS_BOUND

    assert not unused, f"declared but never read by the SQL: {sorted(unused)}"
    assert not undeclared, f"read by the SQL but not declared: {sorted(undeclared)}"


def test_reports_were_discovered():
    assert len(_report_pairs()) > 40

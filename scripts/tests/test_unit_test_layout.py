"""Guards where unit tests live.

An analytics target disables the report models, and dbt fails to parse a unit test whose model is
disabled. dbt_project.yml disables tests/unit_tests/reports/ on analytics targets, so every
unit test that targets a report must sit there and no other unit test may.
"""

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
UNIT_TESTS = ROOT / "tests" / "unit_tests"
REPORTS = UNIT_TESTS / "reports"


def _report_models():
    return {path.stem for path in (ROOT / "models" / "reports" / "sql").rglob("*.sql")}


def _unit_tests():
    for path in sorted(UNIT_TESTS.rglob("*.yml")):
        document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        for unit_test in document.get("unit_tests", []):
            yield path, unit_test


def test_unit_tests_are_found():
    assert any(True for _ in _unit_tests()), f"no unit tests under {UNIT_TESTS}"


def test_a_report_unit_test_lives_under_reports():
    reports = _report_models()
    misplaced = [
        f"{path.relative_to(ROOT).as_posix()}: {unit_test['name']}"
        for path, unit_test in _unit_tests()
        if unit_test.get("model") in reports and REPORTS not in path.parents
    ]

    assert not misplaced, "report unit tests outside tests/unit_tests/reports/:\n" + "\n".join(misplaced)


def test_only_report_unit_tests_live_under_reports():
    reports = _report_models()
    misplaced = [
        f"{path.relative_to(ROOT).as_posix()}: {unit_test['name']}"
        for path, unit_test in _unit_tests()
        if unit_test.get("model") not in reports and REPORTS in path.parents
    ]

    assert not misplaced, "non-report unit tests under tests/unit_tests/reports/:\n" + "\n".join(misplaced)

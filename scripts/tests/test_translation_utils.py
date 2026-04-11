import pytest

from utils.translation_utils import find_default_overrides_for_standard


STANDARD = {
    "report.reporting.admissionDate": {"default": "Admission date"},
    "report.reporting.admissionStatus": {"default": "Admission status"},
}


# ---------------------------------------------------------------------------
# find_default_overrides_for_standard
# ---------------------------------------------------------------------------


def test_no_localised_returns_empty():
    assert find_default_overrides_for_standard({}, STANDARD) == []


def test_localised_only_en_for_standard_id_is_allowed():
    localised = {"report.reporting.admissionDate": {"en": "Admission date"}}
    assert find_default_overrides_for_standard(localised, STANDARD) == []


def test_localised_default_for_standard_id_is_an_error():
    localised = {"report.reporting.admissionDate": {"default": "Admission date"}}
    errors = find_default_overrides_for_standard(localised, STANDARD)
    assert errors == ["report.reporting.admissionDate"]


def test_localised_default_and_en_for_standard_id_is_an_error():
    localised = {
        "report.reporting.admissionDate": {"default": "Admission date", "en": "Admission date"}
    }
    errors = find_default_overrides_for_standard(localised, STANDARD)
    assert errors == ["report.reporting.admissionDate"]


def test_new_string_id_with_default_is_allowed():
    """A string ID not in standard may define its own default."""
    localised = {"report.reporting.customField": {"default": "Custom field"}}
    assert find_default_overrides_for_standard(localised, STANDARD) == []


def test_multiple_errors_reported():
    localised = {
        "report.reporting.admissionDate": {"default": "Admission date"},
        "report.reporting.admissionStatus": {"default": "Admission status"},
        "report.reporting.customField": {"default": "Custom field"},
    }
    errors = find_default_overrides_for_standard(localised, STANDARD)
    assert sorted(errors) == [
        "report.reporting.admissionDate",
        "report.reporting.admissionStatus",
    ]

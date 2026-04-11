
from utils.translation_utils import (
    find_default_overrides_for_standard,
    read_translations_csv,
)

# ---------------------------------------------------------------------------
# read_translations_csv
# ---------------------------------------------------------------------------


def test_missing_file_returns_empty(tmp_path):
    assert read_translations_csv(tmp_path / "nonexistent.csv") == {}


def test_basic_read(tmp_path):
    csv = tmp_path / "t.csv"
    csv.write_text(
        "stringId,default\nreport.reporting.foo,Foo label\n", encoding="utf-8"
    )
    assert read_translations_csv(csv) == {
        "report.reporting.foo": {"default": "Foo label"}
    }


def test_single_quote_is_escaped(tmp_path):
    csv = tmp_path / "t.csv"
    csv.write_text(
        "stringId,default\nreport.reporting.foo,It's a label\n", encoding="utf-8"
    )
    result = read_translations_csv(csv)
    assert result["report.reporting.foo"]["default"] == "It\\'s a label"


def test_backslash_is_escaped(tmp_path):
    csv = tmp_path / "t.csv"
    csv.write_text(
        "stringId,default\nreport.reporting.foo,C:\\path\n", encoding="utf-8"
    )
    result = read_translations_csv(csv)
    assert result["report.reporting.foo"]["default"] == "C:\\\\path"


def test_empty_cell_is_omitted(tmp_path):
    csv = tmp_path / "t.csv"
    csv.write_text(
        "stringId,default,en\nreport.reporting.foo,,English label\n", encoding="utf-8"
    )
    result = read_translations_csv(csv)
    assert "default" not in result["report.reporting.foo"]
    assert result["report.reporting.foo"]["en"] == "English label"


def test_row_without_string_id_is_skipped(tmp_path):
    csv = tmp_path / "t.csv"
    csv.write_text(
        "stringId,default\n,Orphan label\nreport.reporting.foo,Foo label\n",
        encoding="utf-8",
    )
    result = read_translations_csv(csv)
    assert list(result.keys()) == ["report.reporting.foo"]


def test_multiple_languages(tmp_path):
    csv = tmp_path / "t.csv"
    csv.write_text(
        "stringId,default,en,fr\nreport.reporting.foo,Foo,Foo EN,Foo FR\n",
        encoding="utf-8",
    )
    assert read_translations_csv(csv) == {
        "report.reporting.foo": {"default": "Foo", "en": "Foo EN", "fr": "Foo FR"}
    }


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
        "report.reporting.admissionDate": {
            "default": "Admission date",
            "en": "Admission date",
        }
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

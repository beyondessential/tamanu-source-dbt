import textwrap

from generate_metric_definitions_macro import (
    COLUMNS,
    build_macro_content,
    read_definitions,
    read_definitions_dir,
    sql_literal,
)


def _row(metric_id, **overrides):
    """Build a full definition row, defaulting every column to empty string."""
    row = {col: "" for col in COLUMNS}
    row["metric_id"] = metric_id
    row.update(overrides)
    return row


# ---------------------------------------------------------------------------
# sql_literal — empty cell → NULL, escaping
# ---------------------------------------------------------------------------


def test_sql_literal_empty_becomes_null():
    assert sql_literal("") == "null"


def test_sql_literal_quotes_text():
    assert sql_literal("patient") == "'patient'"


def test_sql_literal_escapes_single_quote():
    assert sql_literal("lost to follow-up'd") == "'lost to follow-up''d'"


def test_sql_literal_preserves_commas():
    assert sql_literal("age_group,sex,facility_id") == "'age_group,sex,facility_id'"


# ---------------------------------------------------------------------------
# build_macro_content — sorting, NULL rendering, column casts
# ---------------------------------------------------------------------------


def test_build_macro_sorts_rows_by_metric_id():
    content = build_macro_content({"b": _row("b"), "a": _row("a")})
    assert content.index("('a'") < content.index("('b'")


def test_build_macro_renders_empty_cells_as_null():
    content = build_macro_content({"a": _row("a", name="Active", description="")})
    # name populated, description empty → quoted then null in the row tuple
    assert "'Active'" in content
    assert ", null," in content


def test_build_macro_casts_every_column_to_text():
    content = build_macro_content({"a": _row("a")})
    for col in COLUMNS:
        assert f"{col}::text as {col}" in content


def test_build_macro_is_a_jinja_macro():
    content = build_macro_content({"a": _row("a")})
    assert "{%- macro get_metric_definitions() -%}" in content
    assert "{%- endmacro -%}" in content


# ---------------------------------------------------------------------------
# read_definitions — keyed by metric_id, list columns joined, blanks skipped
# ---------------------------------------------------------------------------


def _write(tmp_path, body):
    path = tmp_path / "metric_definitions.yml"
    path.write_text(textwrap.dedent(body), encoding="utf-8")
    return str(path)


def test_read_definitions_keys_by_metric_id(tmp_path):
    path = _write(
        tmp_path,
        """\
        metrics:
          - metric_id: patients_active
            kind: metric
            name: Active
            description: desc
            unit: count
            subject_grain: patient
            disaggregations:
              - sex
            owner: bes-maui
            status: draft
            spec_path: specs/x.md
        """,
    )
    rows = read_definitions(path)
    assert set(rows) == {"patients_active"}
    assert rows["patients_active"]["kind"] == "metric"
    # every column is present, absent ones as empty string (rendered to NULL later)
    assert set(rows["patients_active"]) == set(COLUMNS)
    assert rows["patients_active"]["numerator_description"] == ""


def test_read_definitions_joins_list_columns(tmp_path):
    path = _write(
        tmp_path,
        """\
        metrics:
          - metric_id: a
            disaggregations:
              - age_group
              - sex
              - facility_id
        """,
    )
    # the macro emits disaggregations as comma-joined text
    assert read_definitions(path)["a"]["disaggregations"] == "age_group,sex,facility_id"


def test_read_definitions_renders_null_as_empty(tmp_path):
    path = _write(
        tmp_path,
        """\
        metrics:
          - metric_id: a
            variant_of: null
            definition_source_code: 746091
        """,
    )
    rows = read_definitions(path)
    assert rows["a"]["variant_of"] == ""
    # a numeric-looking code stays text, so the macro quotes it unchanged
    assert rows["a"]["definition_source_code"] == "746091"


def test_read_definitions_skips_blank_metric_id(tmp_path):
    path = _write(
        tmp_path,
        """\
        metrics:
          - metric_id: null
            name: nameless
        """,
    )
    assert read_definitions(path) == {}


def test_read_definitions_missing_file_returns_empty(tmp_path):
    assert read_definitions(str(tmp_path / "nope.yml")) == {}


def test_read_definitions_empty_file_returns_empty(tmp_path):
    assert read_definitions(_write(tmp_path, "")) == {}


# ---------------------------------------------------------------------------
# read_definitions_dir — merges every *.yml, rejects a duplicate metric_id
# ---------------------------------------------------------------------------


def _write_named(tmp_path, filename, metric_id):
    (tmp_path / filename).write_text(
        "metrics:\n  - metric_id: %s\n" % metric_id, encoding="utf-8"
    )


def test_read_definitions_dir_merges_files(tmp_path):
    _write_named(tmp_path, "emergency.yml", "ed_visit")
    _write_named(tmp_path, "msf_opd.yml", "anaemia_followup")
    assert set(read_definitions_dir(str(tmp_path))) == {"ed_visit", "anaemia_followup"}


def test_read_definitions_dir_rejects_duplicate_metric_id(tmp_path):
    _write_named(tmp_path, "a.yml", "ed_visit")
    _write_named(tmp_path, "b.yml", "ed_visit")
    try:
        read_definitions_dir(str(tmp_path))
    except ValueError as exc:
        assert "ed_visit" in str(exc)
    else:
        raise AssertionError("a duplicate metric_id across files must raise")


def test_read_definitions_dir_ignores_non_yaml(tmp_path):
    _write_named(tmp_path, "notes.md", "ignored")
    assert read_definitions_dir(str(tmp_path)) == {}


def test_read_definitions_dir_missing_returns_empty(tmp_path):
    assert read_definitions_dir(str(tmp_path / "nope")) == {}

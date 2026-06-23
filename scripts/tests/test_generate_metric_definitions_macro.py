from generate_metric_definitions_macro import (
    COLUMNS,
    build_macro_content,
    merge_definitions,
    read_csv,
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
# merge_definitions — localised wins, by metric_id
# ---------------------------------------------------------------------------


def test_merge_localised_overrides_standard():
    standard = {"a": _row("a", name="standard")}
    localised = {"a": _row("a", name="localised")}
    merged = merge_definitions(standard, localised)
    assert merged["a"]["name"] == "localised"


def test_merge_localised_extends_catalogue():
    standard = {"a": _row("a")}
    localised = {"b": _row("b", variant_of="a")}
    merged = merge_definitions(standard, localised)
    assert set(merged) == {"a", "b"}


def test_merge_does_not_mutate_standard():
    standard = {"a": _row("a", name="standard")}
    merge_definitions(standard, {"a": _row("a", name="localised")})
    assert standard["a"]["name"] == "standard"


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
# read_csv — keyed by metric_id, blank metric_id skipped
# ---------------------------------------------------------------------------


def test_read_csv_keys_by_metric_id(tmp_path):
    csv_file = tmp_path / "metric_definitions.csv"
    header = ",".join(COLUMNS)
    csv_file.write_text(
        f"{header}\n"
        "patients_active,metric,Active,desc,,,tamanu,MSF,,,count,patient,sex,,bes-maui,draft,specs/x.md\n",
        encoding="utf-8",
    )
    rows = read_csv(str(csv_file))
    assert set(rows) == {"patients_active"}
    assert rows["patients_active"]["kind"] == "metric"
    # empty cells preserved as empty string at read time (rendered to NULL later)
    assert rows["patients_active"]["numerator_description"] == ""


def test_read_csv_skips_blank_metric_id(tmp_path):
    csv_file = tmp_path / "metric_definitions.csv"
    header = ",".join(COLUMNS)
    csv_file.write_text(f"{header}\n" + "," * (len(COLUMNS) - 1) + "\n", encoding="utf-8")
    assert read_csv(str(csv_file)) == {}


def test_read_csv_missing_file_returns_empty(tmp_path):
    assert read_csv(str(tmp_path / "nope.csv")) == {}

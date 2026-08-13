import os

import pytest
import yaml

import validate_data_tables
from validate_data_tables import (
    read_configs,
    read_model_columns,
    validate_bands,
    validate_config,
)


MODEL_COLUMNS = ["metric_id", "period_start", "facility_id", "age_years", "value_numeric"]


def _config(**overrides):
    """A minimal valid config, so each test varies one thing."""
    config = {
        "data_table": "example__standard",
        "model": "metric__example",
        "description": "One row per thing.",
        "metrics": [{"column": "value_numeric", "aggregation": "sum"}],
        "columns": [{"name": "facility_id", "filter": "array"}],
    }
    config.update(overrides)
    return config


def _validate(config, filename="example__standard.yml", columns=MODEL_COLUMNS):
    return validate_config(config, filename, columns)


# ---------------------------------------------------------------------------
# validate_bands — ordering, overlap, bounds
# ---------------------------------------------------------------------------


def test_bands_ascending_half_open_are_valid():
    bands = [
        {"label": "a", "gte": 0, "lt": 15},
        {"label": "b", "gte": 15, "lt": 25},
        {"label": "c", "gte": 25},
    ]
    assert validate_bands(bands, "at") == []


def test_bands_may_leave_a_gap():
    # A gap falls to unmatched_label, which is how an age over 120 becomes 'Unknown age'.
    bands = [{"label": "a", "gte": 0, "lt": 15}, {"label": "b", "gte": 75, "lt": 121}]
    assert validate_bands(bands, "at") == []


def test_overlapping_bands_are_rejected():
    bands = [{"label": "a", "gte": 0, "lt": 20}, {"label": "b", "gte": 15, "lt": 25}]
    errors = validate_bands(bands, "at")
    assert any("overlap" in e for e in errors)


def test_descending_bands_are_rejected():
    bands = [{"label": "a", "gte": 15, "lt": 25}, {"label": "b", "gte": 0, "lt": 15}]
    assert validate_bands(bands, "at") != []


def test_inverted_bounds_are_rejected():
    bands = [{"label": "a", "gte": 25, "lt": 15}]
    errors = validate_bands(bands, "at")
    assert any("matches nothing" in e for e in errors)


def test_unbounded_band_must_be_last():
    bands = [{"label": "a", "gte": 0}, {"label": "b", "gte": 15, "lt": 25}]
    errors = validate_bands(bands, "at")
    assert any("swallows" in e for e in errors)


def test_duplicate_band_labels_are_rejected():
    bands = [{"label": "a", "lt": 15}, {"label": "a", "gte": 15}]
    errors = validate_bands(bands, "at")
    assert any("more than once" in e for e in errors)


def test_band_without_label_is_rejected():
    assert validate_bands([{"lt": 15}], "at") != []


def test_empty_band_list_is_rejected():
    assert validate_bands([], "at") != []


# ---------------------------------------------------------------------------
# validate_config — the model contract
# ---------------------------------------------------------------------------


def test_minimal_config_is_valid():
    assert _validate(_config()) == []


def test_filename_must_match_data_table_name():
    errors = _validate(_config(), filename="something_else.yml")
    assert any("filename" in e for e in errors)


def test_unknown_column_is_rejected():
    errors = _validate(_config(columns=[{"name": "not_a_column", "filter": "array"}]))
    assert any("not a column" in e for e in errors)


def test_unknown_metric_column_is_rejected():
    errors = _validate(_config(metrics=[{"column": "nope", "aggregation": "sum"}]))
    assert any("metric column" in e for e in errors)


def test_metric_without_aggregation_is_rejected():
    errors = _validate(_config(metrics=[{"column": "value_numeric"}]))
    assert any("no aggregation" in e for e in errors)


def test_config_without_metrics_is_rejected():
    errors = _validate(_config(metrics=[]))
    assert any("no metrics" in e for e in errors)


def test_unknown_filter_type_is_rejected():
    errors = _validate(_config(columns=[{"name": "facility_id", "filter": "checkbox"}]))
    assert any("checkbox" in e for e in errors)


def test_column_without_filter_is_valid():
    # No filter means groupable but not filterable, which is a legitimate choice.
    assert _validate(_config(columns=[{"name": "facility_id"}])) == []


def test_duplicate_column_is_rejected():
    errors = _validate(
        _config(columns=[{"name": "facility_id"}, {"name": "facility_id"}])
    )
    assert any("listed twice" in e for e in errors)


def test_missing_model_schema_is_rejected():
    errors = _validate(_config(), columns=None)
    assert any("no schema" in e for e in errors)


# ---------------------------------------------------------------------------
# validate_config — derived columns
# ---------------------------------------------------------------------------


def _derived(**overrides):
    derived = {
        "column": "age_years",
        "unmatched_label": "Unknown age",
        "bands": [{"label": "0-14 years", "gte": 0, "lt": 15}, {"label": "15+ years", "gte": 15}],
    }
    derived.update(overrides)
    return _config(
        columns=[{"name": "age_group", "filter": "array", "derived_from": derived}]
    )


def test_derived_column_is_valid():
    assert _validate(_derived()) == []


def test_derived_source_must_exist():
    errors = _validate(_derived(column="not_a_column"))
    assert any("derives from" in e for e in errors)


def test_derived_without_unmatched_label_is_rejected():
    config = _derived()
    del config["columns"][0]["derived_from"]["unmatched_label"]
    errors = _validate(config)
    assert any("unmatched_label" in e for e in errors)


def test_derived_name_may_not_shadow_a_model_column():
    config = _derived()
    config["columns"][0]["name"] = "facility_id"
    errors = _validate(config)
    assert any("already emits" in e for e in errors)


def test_derived_bands_are_validated():
    errors = _validate(_derived(bands=[{"label": "a", "gte": 25, "lt": 15}]))
    assert any("matches nothing" in e for e in errors)


# ---------------------------------------------------------------------------
# The real configurations in this repo
# ---------------------------------------------------------------------------


def test_repo_data_tables_are_valid():
    configs = read_configs()
    assert configs, "no data table configurations found"
    for filename, config in configs:
        columns = read_model_columns(config.get("model"))
        assert validate_config(config, filename, columns) == []


def test_repo_data_table_names_are_unique():
    names = [config.get("data_table") for _filename, config in read_configs()]
    assert len(names) == len(set(names))

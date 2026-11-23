"""Tests for the sensitive network model generator.

See specs/dbt-model/sensitive-facility-partition.md for the BL and AC clauses these assert.
"""

import json
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from generate_sensitive_network_models import (  # noqa: E402
    MARKER,
    generate,
    network_key,
    partition_name,
    partitioned_models,
)

FIXTURE_NETWORK = "example"


def _write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


@pytest.fixture
def source(tmp_path):
    models = tmp_path / "source" / "models"
    _write(models / "bases" / "encounters.sql", "{{ encounters_base(network=none) }}\n")
    _write(
        models / "bases" / "encounters.yml",
        yaml.safe_dump(
            {
                "version": 2,
                "models": [
                    {
                        "name": "encounters",
                        "columns": [
                            {
                                "name": "id",
                                "data_tests": [
                                    {"not_null": {"name": "ac_001_encounters_id_not_null"}},
                                    {"unique": {"name": "ac_002_id_unique"}},
                                    "not_null",
                                ],
                            }
                        ],
                    }
                ],
            }
        ),
    )
    _write(models / "bases" / "patients.sql", "select 1\n")
    _write(models / "datasets" / "standard" / "ds__admissions.sql", "{{ admissions_dataset(network=none) }}\n")
    _write(
        models / "reports" / "sql" / "standard" / "admissions-line-list.sql",
        "{%- set network = none -%}\nselect * from {{ partition_ref('ds__admissions', network) }}\n",
    )
    _write(
        models / "reports" / "config" / "standard" / "admissions-line-list.json",
        json.dumps({"query": "replace this", "name": "Admissions line list", "notes": "Lists admissions."}),
    )
    return models


def test_network_key_lowercases_and_joins_other_characters():
    assert network_key("HIV") == "hiv"
    assert network_key("Mental-Health 2") == "mental_health_2"


def test_partition_name_follows_each_layer():
    assert partition_name("encounters", "HIV") == "sensitive_hiv_encounters"
    assert partition_name("ds__admissions", "HIV") == "ds__sensitive_hiv_admissions"
    assert partition_name("clinical__visit_occurrence", "HIV") == "clinical__sensitive_hiv_visit_occurrence"
    assert partition_name("admissions-line-list", "Mental Health") == "sensitive-mental-health-admissions-line-list"


def test_ac_002_generates_each_partitioned_model_for_each_network(source, tmp_path):
    # BL-012
    output = tmp_path / "out" / "models"

    written = generate(source, output, ["hiv", "mh"])

    assert [path.as_posix() for path in written] == [
        "bases/sensitive/sensitive_hiv_encounters.sql",
        "bases/sensitive/sensitive_hiv_encounters.yml",
        "bases/sensitive/sensitive_mh_encounters.sql",
        "bases/sensitive/sensitive_mh_encounters.yml",
        "datasets/sensitive/ds__sensitive_hiv_admissions.sql",
        "datasets/sensitive/ds__sensitive_mh_admissions.sql",
        "reports/config/sensitive/sensitive-hiv-admissions-line-list.json",
        "reports/config/sensitive/sensitive-mh-admissions-line-list.json",
        "reports/sql/sensitive/sensitive-hiv-admissions-line-list.sql",
        "reports/sql/sensitive/sensitive-mh-admissions-line-list.sql",
    ]
    sql = (output / "bases/sensitive/sensitive_hiv_encounters.sql").read_text(encoding="utf-8")
    assert MARKER in sql
    assert "{{ encounters_base(network='hiv') }}" in sql
    report = (output / "reports/sql/sensitive/sensitive-hiv-admissions-line-list.sql").read_text(encoding="utf-8")
    assert "{%- set network = 'hiv' -%}" in report


def test_generated_properties_rename_the_model_and_its_named_tests(source, tmp_path):
    output = tmp_path / "out" / "models"

    generate(source, output, ["hiv"])

    document = yaml.safe_load((output / "bases/sensitive/sensitive_hiv_encounters.yml").read_text(encoding="utf-8"))
    (model,) = document["models"]
    assert model["name"] == "sensitive_hiv_encounters"
    assert model["columns"][0]["data_tests"] == [
        {"not_null": {"name": "ac_001_sensitive_hiv_encounters_id_not_null"}},
        {"unique": {"name": "ac_002_id_unique__sensitive_hiv_encounters"}},
        "not_null",
    ]


def test_generated_report_config_names_the_network(source, tmp_path):
    output = tmp_path / "out" / "models"

    generate(source, output, ["HIV"])

    config = json.loads(
        (output / "reports/config/sensitive/sensitive-hiv-admissions-line-list.json").read_text(encoding="utf-8")
    )
    assert config["name"] == "Sensitive HIV admissions line list"
    assert config["notes"].startswith("Lists admissions.")
    assert "'HIV' sensitive network" in config["notes"]


def test_regenerating_removes_a_dropped_network_and_keeps_other_files(source, tmp_path):
    output = tmp_path / "out" / "models"
    generate(source, output, ["hiv", "mh"])
    hand_written = output / "bases" / "sensitive" / "sensitive_notes.sql"
    _write(hand_written, "select 1\n")

    generate(source, output, ["hiv"])

    remaining = sorted(path.name for path in output.rglob("*") if path.is_file())
    assert not [name for name in remaining if "mh" in name.replace("-", "_").split("_")]
    assert "sensitive_hiv_encounters.sql" in remaining
    assert hand_written.exists()


def test_generated_models_are_not_partitioned_again(source):
    generate(source, source, ["hiv"])

    assert [path.as_posix() for path in partitioned_models(source)] == [
        "bases/encounters.sql",
        "datasets/standard/ds__admissions.sql",
        "reports/sql/standard/admissions-line-list.sql",
    ]


def test_committed_fixture_network_models_are_in_sync(tmp_path):
    # BL-013: regenerating the fixture network changes nothing
    written = generate(ROOT / "models", tmp_path, [FIXTURE_NETWORK])

    assert written, "no partitioned models found"
    stale = [
        path.as_posix()
        for path in written
        if not (ROOT / "models" / path).exists()
        or (ROOT / "models" / path).read_text(encoding="utf-8") != (tmp_path / path).read_text(encoding="utf-8")
    ]
    assert not stale, (
        "Generated sensitive network models are out of date. Run "
        "`python scripts/generate_sensitive_network_models.py --networks example` and commit the result: "
        f"{stale}"
    )

    committed = {
        path.relative_to(ROOT / "models")
        for path in (ROOT / "models").rglob("*")
        if path.is_file() and "sensitive" in path.relative_to(ROOT / "models").parent.parts
    }
    assert committed == set(written), "the sensitive folders hold files the generator did not write"

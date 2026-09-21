"""Guards the cohort_definitions allocation registry.

The seed is disabled in dbt_project.yml, so dbt schema tests on it never run: an enabled seed
puts its tests into every consuming deployment's graph, where they fail because a deployment
never runs `dbt seed`. These checks run in CI here instead, and cost a deployment nothing.

See seeds/cohort_definitions.yml for why the seed exists at all.
"""

import csv
from pathlib import Path

SEED = Path(__file__).resolve().parents[2] / "seeds" / "cohort_definitions.csv"

EXPECTED_COLUMNS = [
    "cohort_definition_id",
    "cohort_name",
    "description",
    "omop_concept_id",
    "vocabulary_id",
]


def _rows():
    with SEED.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def test_seed_exists():
    assert SEED.is_file(), f"{SEED} is missing"


def test_columns_match_the_convention():
    with SEED.open(newline="", encoding="utf-8") as handle:
        header = next(csv.reader(handle))
    assert header == EXPECTED_COLUMNS


def test_ids_are_unique():
    ids = [row["cohort_definition_id"] for row in _rows()]
    assert len(ids) == len(set(ids)), f"duplicate cohort_definition_id in {ids}"


def test_names_are_unique():
    names = [row["cohort_name"] for row in _rows()]
    assert len(names) == len(set(names)), f"duplicate cohort_name in {names}"


def test_ids_are_positive_integers():
    for row in _rows():
        value = row["cohort_definition_id"]
        assert value.isdigit() and int(value) > 0, (
            f"cohort_definition_id {value!r} is not a positive integer"
        )


def test_id_and_name_are_always_populated():
    for row in _rows():
        assert row["cohort_definition_id"], f"row missing an id: {row}"
        assert row["cohort_name"], f"row missing a name: {row}"

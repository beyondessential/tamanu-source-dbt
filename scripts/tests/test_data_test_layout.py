"""Guards where singular data tests live.

Each kind of singular test has its own folder under tests/data_tests/, and dbt_project.yml tags
every test in a folder with the folder's name, so `dbt test --select tag:<folder>` runs one kind.
A test outside those folders carries no kind tag, so every tag-selected run skips it.
"""

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
DATA_TESTS = ROOT / "tests" / "data_tests"


def _folder_tags():
    project = yaml.safe_load((ROOT / "dbt_project.yml").read_text(encoding="utf-8"))
    folders = project["data_tests"]["tamanu_source_dbt"]["data_tests"]
    return {name: config.get("+tags", []) for name, config in folders.items()}


def test_each_kind_folder_is_tagged_with_its_own_name():
    mismatched = {name: tags for name, tags in _folder_tags().items() if tags != [name]}

    assert not mismatched, f"tests/data_tests/ folders not tagged with their own name: {mismatched}"


def test_each_tagged_folder_exists():
    missing = [name for name in _folder_tags() if not (DATA_TESTS / name).is_dir()]

    assert not missing, f"dbt_project.yml tags tests/data_tests/ folders that do not exist: {missing}"


def test_every_singular_test_sits_in_a_tagged_folder():
    folders = set(_folder_tags())
    misplaced = [
        path.relative_to(ROOT).as_posix()
        for path in sorted(DATA_TESTS.rglob("*.sql"))
        if path.relative_to(DATA_TESTS).parts[0] not in folders
    ]

    assert not misplaced, (
        f"singular tests outside the tagged folders {sorted(folders)}:\n" + "\n".join(misplaced)
    )

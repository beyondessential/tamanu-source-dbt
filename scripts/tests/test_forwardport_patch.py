import os
import textwrap
from pathlib import Path

import pytest

from create_version_branch import find_latest_tag_for_major, find_latest_tag_for_minor
from forwardport_patch import (
    get_higher_minor_branches_from_list,
    get_major_minor_patch,
    get_previous_tag,
    get_version_tags_for_minor_from_list,
    update_version_in_files,
)


# ---------------------------------------------------------------------------
# get_major_minor_patch
# ---------------------------------------------------------------------------


def test_get_major_minor_patch_standard():
    assert get_major_minor_patch("2.50.4") == (2, 50, 4)


def test_get_major_minor_patch_with_v():
    assert get_major_minor_patch("v2.50.4") == (2, 50, 4)


def test_get_major_minor_patch_large_patch():
    assert get_major_minor_patch("2.49.10") == (2, 49, 10)


def test_get_major_minor_patch_zero_patch():
    assert get_major_minor_patch("v2.51.0") == (2, 51, 0)


def test_get_major_minor_patch_quoted():
    assert get_major_minor_patch('"2.50.4"') == (2, 50, 4)


def test_get_major_minor_patch_two_part_raises():
    with pytest.raises(ValueError):
        get_major_minor_patch("2.50")


def test_get_major_minor_patch_non_numeric_raises():
    with pytest.raises(ValueError):
        get_major_minor_patch("2.50.x")


# ---------------------------------------------------------------------------
# get_version_tags_for_minor_from_list  (pure helper used by get_previous_tag)
# ---------------------------------------------------------------------------


ALL_TAGS = ["v2.49.0", "v2.49.1", "v2.49.9", "v2.49.10", "v2.50.0", "v2.50.1"]


def test_get_version_tags_sorted_numerically():
    result = get_version_tags_for_minor_from_list(ALL_TAGS, "2.49")
    assert result == ["v2.49.0", "v2.49.1", "v2.49.9", "v2.49.10"]


def test_get_version_tags_no_match():
    result = get_version_tags_for_minor_from_list(ALL_TAGS, "2.48")
    assert result == []


def test_get_version_tags_single():
    result = get_version_tags_for_minor_from_list(["v2.49.3"], "2.49")
    assert result == ["v2.49.3"]


# ---------------------------------------------------------------------------
# get_previous_tag
# ---------------------------------------------------------------------------


def test_get_previous_tag_standard():
    tags = ["v2.49.0", "v2.49.1", "v2.49.9", "v2.49.10"]
    assert get_previous_tag("v2.49.9", tags) == "v2.49.1"


def test_get_previous_tag_with_v():
    tags = ["v2.49.0", "v2.49.1", "v2.49.2"]
    assert get_previous_tag("v2.49.2", tags) == "v2.49.1"


def test_get_previous_tag_first_patch_returns_none():
    tags = ["v2.49.0", "v2.49.1"]
    assert get_previous_tag("v2.49.0", tags) is None


def test_get_previous_tag_not_found_returns_none():
    tags = ["v2.49.0", "v2.49.1"]
    assert get_previous_tag("v2.49.5", tags) is None


def test_get_previous_tag_large_patch():
    tags = ["v2.49.0", "v2.49.9", "v2.49.10"]
    assert get_previous_tag("v2.49.10", tags) == "v2.49.9"


# ---------------------------------------------------------------------------
# find_latest_tag_for_minor  (from create_version_branch.py)
# ---------------------------------------------------------------------------

def _make_refs(*tags):
    return [{"ref": f"refs/tags/{t}"} for t in tags]


def test_find_latest_tag_standard():
    refs = _make_refs("v2.49.0", "v2.49.1", "v2.49.9", "v2.49.10", "v2.50.0")
    assert find_latest_tag_for_minor(refs, 2, 49) == "v2.49.10"


def test_find_latest_tag_single():
    refs = _make_refs("v2.50.0")
    assert find_latest_tag_for_minor(refs, 2, 50) == "v2.50.0"


def test_find_latest_tag_no_match_returns_none():
    refs = _make_refs("v2.50.0", "v2.50.1")
    assert find_latest_tag_for_minor(refs, 2, 49) is None


def test_find_latest_tag_ignores_other_major():
    refs = _make_refs("v3.49.5", "v2.49.3")
    assert find_latest_tag_for_minor(refs, 2, 49) == "v2.49.3"


def test_find_latest_tag_numeric_not_lexicographic():
    # lexicographic sort would give v2.49.9 > v2.49.10, numeric gives v2.49.10
    refs = _make_refs("v2.49.1", "v2.49.9", "v2.49.10")
    assert find_latest_tag_for_minor(refs, 2, 49) == "v2.49.10"


# ---------------------------------------------------------------------------
# find_latest_tag_for_major  (major-bump case: v3.0.0 → branch for last v2.* minor)
# ---------------------------------------------------------------------------


def test_find_latest_tag_for_major_standard():
    # v3.0.0 released: find the last tag across all of major 2
    refs = _make_refs("v2.49.7", "v2.50.0", "v2.51.3", "v3.0.0")
    assert find_latest_tag_for_major(refs, 2) == "v2.51.3"


def test_find_latest_tag_for_major_single_minor():
    refs = _make_refs("v2.50.4")
    assert find_latest_tag_for_major(refs, 2) == "v2.50.4"


def test_find_latest_tag_for_major_no_match_returns_none():
    refs = _make_refs("v3.0.0", "v3.1.0")
    assert find_latest_tag_for_major(refs, 2) is None


def test_find_latest_tag_for_major_ignores_other_majors():
    refs = _make_refs("v1.99.9", "v2.50.1", "v3.0.0")
    assert find_latest_tag_for_major(refs, 2) == "v2.50.1"


def test_find_latest_tag_for_major_numeric_minor_sort():
    # minor 9 < minor 10 numerically; lexicographic would give 9 > 10
    refs = _make_refs("v2.9.5", "v2.10.0")
    assert find_latest_tag_for_major(refs, 2) == "v2.10.0"


# ---------------------------------------------------------------------------
# get_higher_minor_branches_from_list
# ---------------------------------------------------------------------------


def test_get_higher_minor_branches_basic():
    branches = ["2.49", "2.50", "2.51", "main", "feature/foo"]
    result = get_higher_minor_branches_from_list(branches, major=2, minor=49)
    assert result == ["2.50", "2.51"]


def test_get_higher_minor_branches_none_above():
    branches = ["2.49", "2.48"]
    result = get_higher_minor_branches_from_list(branches, major=2, minor=49)
    assert result == []


def test_get_higher_minor_branches_sorted_ascending():
    branches = ["2.51", "2.50", "2.49"]
    result = get_higher_minor_branches_from_list(branches, major=2, minor=48)
    assert result == ["2.49", "2.50", "2.51"]


def test_get_higher_minor_branches_ignores_other_major():
    branches = ["2.50", "3.50"]
    result = get_higher_minor_branches_from_list(branches, major=2, minor=49)
    assert result == ["2.50"]


# ---------------------------------------------------------------------------
# update_version_in_files
# ---------------------------------------------------------------------------

DBT_PROJECT = textwrap.dedent("""\
    name: tamanu_source_dbt
    version: 2.50.4
    config-version: 2
""")

PYPROJECT = textwrap.dedent("""\
    [project]
    name = "tamanu-source-dbt"
    version = "2.50.4"
    description = "..."
""")


def test_update_version_dbt_project(tmp_path):
    (tmp_path / "dbt_project.yml").write_text(DBT_PROJECT)
    (tmp_path / "pyproject.toml").write_text(PYPROJECT)
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        changed = update_version_in_files("2.50.5")
    finally:
        os.chdir(orig)
    assert "dbt_project.yml" in changed
    assert "pyproject.toml" in changed
    assert "version: 2.50.5" in (tmp_path / "dbt_project.yml").read_text()
    assert 'version = "2.50.5"' in (tmp_path / "pyproject.toml").read_text()


def test_update_version_preserves_other_content(tmp_path):
    (tmp_path / "dbt_project.yml").write_text(DBT_PROJECT)
    (tmp_path / "pyproject.toml").write_text(PYPROJECT)
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        update_version_in_files("2.50.5")
    finally:
        os.chdir(orig)
    assert "name: tamanu_source_dbt" in (tmp_path / "dbt_project.yml").read_text()
    assert 'name = "tamanu-source-dbt"' in (tmp_path / "pyproject.toml").read_text()


def test_update_version_no_change_when_already_correct(tmp_path):
    content = DBT_PROJECT.replace("2.50.4", "2.50.5")
    (tmp_path / "dbt_project.yml").write_text(content)
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        changed = update_version_in_files("2.50.5")
    finally:
        os.chdir(orig)
    assert "dbt_project.yml" not in changed


def test_update_version_missing_file_ignored(tmp_path):
    (tmp_path / "dbt_project.yml").write_text(DBT_PROJECT)
    # pyproject.toml intentionally absent
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        changed = update_version_in_files("2.50.5")
    finally:
        os.chdir(orig)
    assert "dbt_project.yml" in changed
    assert "pyproject.toml" not in changed


def test_update_version_overrides_wrong_version(tmp_path):
    """After a cherry-pick sets version to 2.49.9, we should be able to override to 2.50.5."""
    wrong = DBT_PROJECT.replace("2.50.4", "2.49.9")
    (tmp_path / "dbt_project.yml").write_text(wrong)
    orig = os.getcwd()
    os.chdir(tmp_path)
    try:
        update_version_in_files("2.50.5")
    finally:
        os.chdir(orig)
    assert "version: 2.50.5" in (tmp_path / "dbt_project.yml").read_text()

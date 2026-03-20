import os
import tempfile

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


def test_get_major_minor_patch_with_v_prefix():
    assert get_major_minor_patch("v2.49.9") == (2, 49, 9)


def test_get_major_minor_patch_without_v_prefix():
    assert get_major_minor_patch("2.49.9") == (2, 49, 9)


def test_get_major_minor_patch_zero_patch():
    assert get_major_minor_patch("v2.51.0") == (2, 51, 0)


def test_get_major_minor_patch_large_minor():
    assert get_major_minor_patch("v2.100.3") == (2, 100, 3)


def test_get_major_minor_patch_major_bump():
    assert get_major_minor_patch("v3.0.0") == (3, 0, 0)


# ---------------------------------------------------------------------------
# get_version_tags_for_minor_from_list
# ---------------------------------------------------------------------------


def test_get_version_tags_filters_correctly():
    all_tags = ["v2.49.0", "v2.49.1", "v2.50.0", "v2.50.1", "v3.0.0"]
    assert get_version_tags_for_minor_from_list(all_tags, "2.49") == ["v2.49.0", "v2.49.1"]


def test_get_version_tags_sorts_by_patch():
    all_tags = ["v2.49.3", "v2.49.1", "v2.49.2", "v2.49.0"]
    assert get_version_tags_for_minor_from_list(all_tags, "2.49") == [
        "v2.49.0", "v2.49.1", "v2.49.2", "v2.49.3"
    ]


def test_get_version_tags_empty_when_no_match():
    all_tags = ["v2.50.0", "v2.51.0"]
    assert get_version_tags_for_minor_from_list(all_tags, "2.49") == []


def test_get_version_tags_single_tag():
    all_tags = ["v2.49.0"]
    assert get_version_tags_for_minor_from_list(all_tags, "2.49") == ["v2.49.0"]


def test_get_version_tags_no_partial_match():
    # v2.490.0 should NOT match major_minor "2.49"
    all_tags = ["v2.490.0", "v2.49.0"]
    assert get_version_tags_for_minor_from_list(all_tags, "2.49") == ["v2.49.0"]


# ---------------------------------------------------------------------------
# get_previous_tag
# ---------------------------------------------------------------------------


def test_get_previous_tag_standard():
    tags = ["v2.49.0", "v2.49.1", "v2.49.2"]
    assert get_previous_tag("v2.49.2", tags) == "v2.49.1"


def test_get_previous_tag_first_returns_none():
    tags = ["v2.49.0", "v2.49.1"]
    assert get_previous_tag("v2.49.0", tags) is None


def test_get_previous_tag_not_in_list_returns_none():
    tags = ["v2.49.0", "v2.49.1"]
    assert get_previous_tag("v2.49.9", tags) is None


def test_get_previous_tag_single_element():
    tags = ["v2.49.0"]
    assert get_previous_tag("v2.49.0", tags) is None


# ---------------------------------------------------------------------------
# find_latest_tag_for_minor (from create_version_branch)
# ---------------------------------------------------------------------------

def _make_refs(tags: list[str]) -> list[dict]:
    return [{"ref": f"refs/tags/{t}", "object": {"sha": "abc", "type": "commit"}} for t in tags]


def test_find_latest_tag_for_minor_standard():
    refs = _make_refs(["v2.50.0", "v2.50.1", "v2.50.4", "v2.50.2"])
    assert find_latest_tag_for_minor(refs, 2, 50) == "v2.50.4"


def test_find_latest_tag_for_minor_single():
    refs = _make_refs(["v2.50.0"])
    assert find_latest_tag_for_minor(refs, 2, 50) == "v2.50.0"


def test_find_latest_tag_for_minor_no_match():
    refs = _make_refs(["v2.51.0", "v2.51.1"])
    assert find_latest_tag_for_minor(refs, 2, 50) is None


def test_find_latest_tag_for_minor_ignores_other_majors():
    refs = _make_refs(["v2.50.5", "v3.50.9"])
    assert find_latest_tag_for_minor(refs, 2, 50) == "v2.50.5"


# ---------------------------------------------------------------------------
# find_latest_tag_for_major (from create_version_branch)
# ---------------------------------------------------------------------------


def test_find_latest_tag_for_major_standard():
    refs = _make_refs(["v2.49.3", "v2.50.4", "v2.51.0"])
    assert find_latest_tag_for_major(refs, 2) == "v2.51.0"


def test_find_latest_tag_for_major_picks_highest_minor_then_patch():
    refs = _make_refs(["v2.49.9", "v2.50.1"])
    assert find_latest_tag_for_major(refs, 2) == "v2.50.1"


def test_find_latest_tag_for_major_no_match():
    refs = _make_refs(["v3.0.0", "v3.1.0"])
    assert find_latest_tag_for_major(refs, 2) is None


def test_find_latest_tag_for_major_avoids_lexicographic_trap():
    # v2.9.0 must not beat v2.10.0
    refs = _make_refs(["v2.9.0", "v2.10.0"])
    assert find_latest_tag_for_major(refs, 2) == "v2.10.0"


def test_find_latest_tag_for_major_ignores_other_majors():
    refs = _make_refs(["v2.51.3", "v3.0.0"])
    assert find_latest_tag_for_major(refs, 2) == "v2.51.3"


# ---------------------------------------------------------------------------
# get_higher_minor_branches_from_list
# ---------------------------------------------------------------------------


def test_higher_minor_branches_same_major():
    branches = ["2.49", "2.50", "2.51", "main", "feat/foo"]
    assert get_higher_minor_branches_from_list(branches, 2, 49) == ["2.50", "2.51"]


def test_higher_minor_branches_excludes_same():
    branches = ["2.50", "2.51"]
    assert get_higher_minor_branches_from_list(branches, 2, 51) == []


def test_higher_minor_branches_cross_major():
    branches = ["2.51", "3.0"]
    assert get_higher_minor_branches_from_list(branches, 2, 51) == ["3.0"]


def test_higher_minor_branches_cross_major_lower_minor():
    # Patching v2.51 when v3.0 exists: (3, 0) > (2, 51) → included
    branches = ["3.0"]
    assert get_higher_minor_branches_from_list(branches, 2, 51) == ["3.0"]


def test_higher_minor_branches_ignores_non_version_branches():
    branches = ["main", "feat/foo", "2.50"]
    assert get_higher_minor_branches_from_list(branches, 2, 49) == ["2.50"]


def test_higher_minor_branches_empty_list():
    assert get_higher_minor_branches_from_list([], 2, 50) == []


# ---------------------------------------------------------------------------
# update_version_in_files
# ---------------------------------------------------------------------------


def test_update_version_in_files(tmp_path, monkeypatch):
    dbt_project = tmp_path / "dbt_project.yml"
    pyproject = tmp_path / "pyproject.toml"

    dbt_project.write_text("name: tamanu\nversion: '2.50.3'\nprofile: tamanu\n")
    pyproject.write_text('[project]\nname = "tamanu"\nversion = "2.50.3"\n')

    monkeypatch.chdir(tmp_path)
    update_version_in_files("2.50.4")

    assert "version: '2.50.4'" in dbt_project.read_text()
    assert 'version = "2.50.4"' in pyproject.read_text()


def test_update_version_preserves_other_content(tmp_path, monkeypatch):
    dbt_project = tmp_path / "dbt_project.yml"
    pyproject = tmp_path / "pyproject.toml"

    dbt_project.write_text("name: tamanu\nversion: '2.50.3'\nprofile: tamanu\n")
    pyproject.write_text('[project]\nname = "tamanu"\nversion = "2.50.3"\n')

    monkeypatch.chdir(tmp_path)
    update_version_in_files("2.50.4")

    dbt_content = dbt_project.read_text()
    assert "name: tamanu" in dbt_content
    assert "profile: tamanu" in dbt_content

    py_content = pyproject.read_text()
    assert 'name = "tamanu"' in py_content

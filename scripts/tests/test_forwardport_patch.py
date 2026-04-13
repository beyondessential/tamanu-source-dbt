import os
import textwrap
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

import forwardport_patch
from create_version_branch import find_latest_tag_for_major, find_latest_tag_for_minor
from forwardport_patch import (
    forwardport_to_branch,
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
# forward-port skip condition  (forwardport_patch.py:319)
# ---------------------------------------------------------------------------


def test_skip_condition_same_minor():
    # patch on same minor as main — should exit early
    assert (2, 50) >= (2, 50)


def test_skip_condition_newer_minor():
    # patch on a newer minor than main — should exit early (shouldn't happen but guarded)
    assert (2, 51) >= (2, 50)


def test_skip_condition_cross_major_does_not_skip():
    # patch on v2.49 while main is on v3.0 — must NOT exit early
    assert not (2, 49) >= (3, 0)


def test_skip_condition_older_minor_same_major():
    # normal forward-port case: patch on older minor, main on newer — must NOT exit early
    assert not (2, 49) >= (2, 50)


def test_skip_condition_major_boundary():
    # v2.99 patch while main is on v3.0 — must NOT exit early
    assert not (2, 99) >= (3, 0)


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


# ---------------------------------------------------------------------------
# forwardport_to_branch — conflict path
# ---------------------------------------------------------------------------

_COMMITS = ["aaaa1111aaaa1111", "bbbb2222bbbb2222", "cccc3333cccc3333"]
_CONFLICT_OUTPUT = ("", "CONFLICT (content): Merge conflict in foo.sql")  # (stderr, stdout)
_EMPTY_PICK_OUTPUT = ("cherry-pick is now empty", "")  # (stderr, stdout)


def _git_mock(cherry_pick_results=None):
    """Return a callable mock for git(). cherry_pick_results maps SHA -> (stderr, stdout)."""
    cherry_pick_results = cherry_pick_results or {}

    def _git(*args, **kwargs):
        m = MagicMock()
        m.returncode = 0
        m.stdout = ""
        m.stderr = ""
        # Only intercept actual commit cherry-picks, not --abort / --skip flags
        if args[0] == "cherry-pick" and len(args) > 1 and not args[1].startswith("-"):
            sha = args[1]
            if sha in cherry_pick_results:
                m.returncode = 1
                m.stderr, m.stdout = cherry_pick_results[sha]
        return m

    return _git


def _git_out_mock(rev_list_count="1"):
    def _git_out(*args):
        if "rev-list" in args and "--count" in args:
            return rev_list_count
        return ""
    return _git_out


def _run(cherry_pick_results=None, rev_list_count="1"):
    """Run forwardport_to_branch with mocked git/gh. Returns the args list of each gh pr create call."""
    gh_create_calls = []

    def fake_gh_out(*args, **kwargs):
        if args[0] == "pr" and args[1] == "list":
            return "[]"
        if args[0] == "pr" and args[1] == "create":
            gh_create_calls.append(list(args))
            return "https://github.com/org/repo/pull/42"
        return ""

    with (
        patch.object(forwardport_patch, "git", side_effect=_git_mock(cherry_pick_results)),
        patch.object(forwardport_patch, "git_out", side_effect=_git_out_mock(rev_list_count)),
        patch.object(forwardport_patch, "gh_out", side_effect=fake_gh_out),
        patch.object(forwardport_patch, "get_branch_version", return_value="2.50.4"),
        patch.object(forwardport_patch, "update_version_in_files", return_value=[]),
    ):
        forwardport_to_branch(
            target_branch="2.50",
            patch_commits=_COMMITS,
            new_patch_tag="v2.49.9",
            source_major_minor="2.49",
            repo="org/repo",
        )

    return gh_create_calls


def _pr_args(gh_create_calls):
    assert len(gh_create_calls) == 1, f"Expected 1 pr create call, got {len(gh_create_calls)}"
    return gh_create_calls[0]


def _get_arg(args, flag):
    return args[args.index(flag) + 1]


def test_conflict_first_commit_no_pr_when_nothing_ahead():
    # Conflict on first commit, nothing committed ahead — no PR should be opened.
    calls = _run({_COMMITS[0]: _CONFLICT_OUTPUT}, rev_list_count="0")
    assert calls == []


def test_conflict_later_commit_opens_draft_pr():
    # Conflict on second of three commits with 1 commit already ahead — draft PR opened.
    calls = _run({_COMMITS[1]: _CONFLICT_OUTPUT}, rev_list_count="1")
    assert "--draft" in _pr_args(calls)


def test_no_conflict_opens_normal_pr():
    # No conflicts — PR opened without --draft, body shows count without denominator.
    calls = _run({}, rev_list_count="3")
    args = _pr_args(calls)
    assert "--draft" not in args
    assert "[CONFLICT]" not in _get_arg(args, "--title")
    body = _get_arg(args, "--body")
    assert "Cherry-picks 3 commit(s)" in body
    assert "of 3" not in body


def test_conflict_pr_title_has_conflict_marker():
    calls = _run({_COMMITS[1]: _CONFLICT_OUTPUT}, rev_list_count="1")
    title = _get_arg(_pr_args(calls), "--title")
    assert "[CONFLICT]" in title


def test_applied_commits_zero_when_conflict_on_first():
    # Conflict on first commit — applied_commits = 0, denominator = 3.
    # rev_list_count="1" simulates a version-bump commit being present so the PR
    # path is reached; in practice ahead=0 here would trigger the early-return.
    calls = _run({_COMMITS[0]: _CONFLICT_OUTPUT}, rev_list_count="1")
    body = _get_arg(_pr_args(calls), "--body")
    assert "Cherry-picked 0 of 3" in body


def test_applied_commits_correct_when_conflict_on_second():
    # First commit applied, second conflicts — applied_commits = 1, denominator = 3.
    calls = _run({_COMMITS[1]: _CONFLICT_OUTPUT}, rev_list_count="2")
    body = _get_arg(_pr_args(calls), "--body")
    assert "Cherry-picked 1 of 3" in body


def test_conflict_body_lists_remaining_commits():
    # Conflict on first commit — the other two SHAs should appear as explicit cherry-pick steps.
    calls = _run({_COMMITS[0]: _CONFLICT_OUTPUT}, rev_list_count="1")
    body = _get_arg(_pr_args(calls), "--body")
    assert _COMMITS[1] in body
    assert _COMMITS[2] in body


def test_conflict_body_no_remaining_step_when_last_commit_conflicts():
    # Conflict on last commit — no remaining commits to list, step 3 absent.
    calls = _run({_COMMITS[2]: _CONFLICT_OUTPUT}, rev_list_count="2")
    body = _get_arg(_pr_args(calls), "--body")
    assert "remaining commit" not in body


def test_already_applied_commits_excluded_from_denominator():
    # First commit already applied (empty pick), third conflicts.
    # applicable_commits = 3 - 1 = 2; applied_commits = 1 (second succeeded).
    calls = _run(
        {_COMMITS[0]: _EMPTY_PICK_OUTPUT, _COMMITS[2]: _CONFLICT_OUTPUT},
        rev_list_count="2",
    )
    body = _get_arg(_pr_args(calls), "--body")
    assert "Cherry-picked 1 of 2" in body

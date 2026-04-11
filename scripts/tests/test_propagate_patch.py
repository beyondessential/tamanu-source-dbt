import pytest
from propagate_patch import bump_patch, find_revision, get_major_minor, replace_revision

# ---------------------------------------------------------------------------
# get_major_minor
# ---------------------------------------------------------------------------


def test_get_major_minor_standard():
    assert get_major_minor("v2.50.2") == "2.50"


def test_get_major_minor_no_prefix():
    assert get_major_minor("2.50.2") == "2.50"


def test_get_major_minor_zero_patch():
    assert get_major_minor("v2.50.0") == "2.50"


def test_get_major_minor_no_patch():
    # two-part version is valid — some callers may pass it
    assert get_major_minor("v2.50") == "2.50"


def test_get_major_minor_invalid_raises():
    with pytest.raises(ValueError):
        get_major_minor("notaversion")


# ---------------------------------------------------------------------------
# bump_patch
# ---------------------------------------------------------------------------


def test_bump_patch_standard():
    assert bump_patch("2.50.1") == "v2.50.2"


def test_bump_patch_with_v_prefix():
    assert bump_patch("v2.50.1") == "v2.50.2"


def test_bump_patch_single_digit_rollover():
    assert bump_patch("2.50.9") == "v2.50.10"


def test_bump_patch_quoted():
    assert bump_patch('"2.50.1"') == "v2.50.2"


def test_bump_patch_two_part_raises():
    with pytest.raises(ValueError):
        bump_patch("2.50")


def test_bump_patch_non_numeric_patch_raises():
    with pytest.raises(ValueError):
        bump_patch("v2.50.x")


# ---------------------------------------------------------------------------
# find_revision
# ---------------------------------------------------------------------------

PACKAGES_SINGLE = """\
packages:
  - git: https://github.com/beyondessential/tamanu-source-dbt/
    revision: v2.49.6
"""

PACKAGES_QUOTED = """\
packages:
  - git: "https://github.com/beyondessential/tamanu-source-dbt/"
    revision: "v2.49.6"
"""

PACKAGES_MULTI = """\
packages:
  - git: https://github.com/beyondessential/tamanu-source-dbt/
    revision: v2.49.6
  - git: https://github.com/dbt-labs/dbt-utils/
    revision: v1.2.0
"""

PACKAGES_OTHER_FIRST = """\
packages:
  - git: https://github.com/dbt-labs/dbt-utils/
    revision: v1.2.0
  - git: https://github.com/beyondessential/tamanu-source-dbt/
    revision: v2.49.6
"""

PACKAGES_NO_TAMANU = """\
packages:
  - git: https://github.com/dbt-labs/dbt-utils/
    revision: v1.2.0
"""


def test_find_revision_basic():
    assert find_revision(PACKAGES_SINGLE) == "v2.49.6"


def test_find_revision_quoted():
    assert find_revision(PACKAGES_QUOTED) == "v2.49.6"


def test_find_revision_multiple_packages():
    assert find_revision(PACKAGES_MULTI) == "v2.49.6"


def test_find_revision_other_package_first():
    assert find_revision(PACKAGES_OTHER_FIRST) == "v2.49.6"


def test_find_revision_no_tamanu_returns_none():
    assert find_revision(PACKAGES_NO_TAMANU) is None


def test_find_revision_empty_returns_none():
    assert find_revision("packages: []\n") is None


# ---------------------------------------------------------------------------
# replace_revision
# ---------------------------------------------------------------------------


def test_replace_revision_unquoted():
    result = replace_revision(PACKAGES_SINGLE, "v2.49.7")
    assert "revision: v2.49.7" in result


def test_replace_revision_double_quoted():
    result = replace_revision(PACKAGES_QUOTED, "v2.49.7")
    assert 'revision: "v2.49.7"' in result


def test_replace_revision_preserves_other_package():
    result = replace_revision(PACKAGES_MULTI, "v2.49.7")
    assert "revision: v2.49.7" in result  # tamanu-source-dbt updated
    assert "revision: v1.2.0" in result  # dbt-utils untouched


def test_replace_revision_other_first_preserves_both():
    result = replace_revision(PACKAGES_OTHER_FIRST, "v2.49.7")
    assert "revision: v1.2.0" in result  # dbt-utils untouched
    assert "revision: v2.49.7" in result  # tamanu-source-dbt updated


def test_replace_revision_no_tamanu_unchanged():
    result = replace_revision(PACKAGES_NO_TAMANU, "v2.49.7")
    assert result == PACKAGES_NO_TAMANU  # file not modified
    assert "v2.49.7" not in result


def test_replace_revision_branch_name():
    # replace_revision substitutes whatever revision YAML parsing finds — callers are
    # responsible for skipping non-semver revisions (propagate() does this via get_major_minor).
    content = "packages:\n  - git: https://github.com/beyondessential/tamanu-source-dbt/\n    revision: main\n"
    assert replace_revision(content, "v2.49.7") == content.replace("main", "v2.49.7")


def test_replace_revision_sha():
    content = (
        "packages:\n  - git: https://github.com/beyondessential/tamanu-source-dbt/\n    revision: abc1234def5678\n"
    )
    assert replace_revision(content, "v2.49.7") == content.replace("abc1234def5678", "v2.49.7")


def test_replace_revision_idempotent():
    once = replace_revision(PACKAGES_SINGLE, "v2.49.7")
    twice = replace_revision(once, "v2.49.7")
    assert once == twice


def test_replace_revision_only_updates_tamanu_block():
    # Ensures the tamanu block update doesn't bleed into the preceding dbt-utils package
    result = replace_revision(PACKAGES_OTHER_FIRST, "v2.49.7")
    lines = result.splitlines()
    dbt_utils_line = next(line for line in lines if "revision" in line and "v1.2.0" in line)
    assert "v1.2.0" in dbt_utils_line
    assert "v2.49.7" not in dbt_utils_line

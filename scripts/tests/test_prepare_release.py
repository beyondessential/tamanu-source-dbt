"""Unit tests for the pure helpers in prepare_release.py.

Only the logic that does not touch git, dbt or the filesystem is covered here, so the
suite stays runnable in CI where neither a database nor a dbt install is available.
"""

import pytest

import prepare_release
from prepare_release import (
    _render_change_list,
    bump_patch,
    compare_bundles,
    bundle_versions_from_paths,
    determine_base,
    host_matches_series,
    minor_series,
    normalise,
    render_pr_body,
    parse_commit_log,
    parse_dbt_host,
    parse_version,
    read_dbt_project_version,
    replace_dbt_project_version,
    replace_pyproject_version,
    _describe_diff,
)


class TestVersions:
    def test_parse_version(self):
        assert parse_version("2.54.32") == (2, 54, 32)

    @pytest.mark.parametrize("bad", ["2.54", "v2.54.32", "2.54.32-rc1", ""])
    def test_parse_version_rejects_non_semver(self, bad):
        with pytest.raises(ValueError):
            parse_version(bad)

    def test_bump_patch(self):
        assert bump_patch("2.54.32") == "2.54.33"
        assert bump_patch("2.60.9") == "2.60.10"

    def test_minor_series(self):
        assert minor_series("2.54.32") == "2.54"


class TestVersionStamps:
    # The `version:` key does not sit at a fixed line across version branches, so the
    # rewrite has to key on the pattern rather than a position.
    DBT_PROJECT_VERSION_FIRST = "version: 2.54.32\nconfig-version: 2\nprofile: tamanu\n"
    DBT_PROJECT_NAME_FIRST = "name: tamanu_source_dbt\nversion: 2.54.32\nconfig-version: 2\n"

    @pytest.mark.parametrize(
        "text", [DBT_PROJECT_VERSION_FIRST, DBT_PROJECT_NAME_FIRST]
    )
    def test_reads_version_at_any_line(self, text):
        assert read_dbt_project_version(text) == "2.54.32"

    def test_read_rejects_missing_key(self):
        with pytest.raises(ValueError):
            read_dbt_project_version("name: tamanu_source_dbt\n")

    def test_replace_leaves_the_rest_untouched(self):
        updated = replace_dbt_project_version(self.DBT_PROJECT_NAME_FIRST, "2.54.33")
        assert "version: 2.54.33" in updated
        assert "name: tamanu_source_dbt" in updated
        assert "config-version: 2" in updated

    def test_replace_does_not_touch_nested_version_keys(self):
        text = "version: 2.54.32\nvars:\n  some_version: 1.0.0\n"
        updated = replace_dbt_project_version(text, "2.54.33")
        assert "some_version: 1.0.0" in updated
        assert "version: 2.54.33" in updated

    def test_replace_pyproject_version(self):
        text = '[project]\nname = "tamanu-source-dbt"\nversion = "2.54.32"\n'
        updated = replace_pyproject_version(text, "2.54.33")
        assert 'version = "2.54.33"' in updated
        assert 'name = "tamanu-source-dbt"' in updated

    def test_replace_pyproject_rejects_missing_key(self):
        with pytest.raises(ValueError):
            replace_pyproject_version('[project]\nname = "x"\n', "2.54.33")


class TestBundleVersions:
    def test_orders_numerically_not_lexically(self):
        paths = [
            "compiled/v2.54.7/reporting-schema-v2.54.7-standard.sql",
            "compiled/v2.54.32/reporting-schema-v2.54.32-standard.sql",
            "compiled/v2.54.6/reporting-docs-v2.54.6-standard.html",
        ]
        # Lexical ordering would put 2.54.7 first and pick the wrong baseline.
        assert bundle_versions_from_paths(paths, "2.54") == ["2.54.32", "2.54.7", "2.54.6"]

    def test_ignores_other_series(self):
        paths = [
            "compiled/v2.54.32/reporting-schema-v2.54.32-standard.sql",
            "compiled/v2.57.15/reporting-schema-v2.57.15-standard.sql",
        ]
        assert bundle_versions_from_paths(paths, "2.54") == ["2.54.32"]

    def test_empty_when_nothing_matches(self):
        assert bundle_versions_from_paths([], "2.54") == []


class TestCommitLog:
    def test_splits_sha_from_subject(self):
        log = "abc1234 feat(metrics): emergency visit metrics (#870)"
        assert parse_commit_log(log) == [
            ("abc1234", "feat(metrics): emergency visit metrics (#870)")
        ]

    @pytest.mark.parametrize(
        "subject",
        [
            "release: bump version to 2.57.15 and rebuild the bundle",
            "chore: bump version to 2.59.5",
            "chore(release): bump version to 2.60.8",
        ],
    )
    def test_drops_previous_version_bumps_in_any_style(self, subject):
        log = f"abc1234 fix(unit_tests): even up the expect columns (#853)\ndef5678 {subject}"
        assert [sha for sha, _ in parse_commit_log(log)] == ["abc1234"]

    def test_keeps_commits_that_merely_mention_a_version(self):
        log = "abc1234 chore: forwardport v2.57.6 to 2.59 (→ 2.59.2) (#604)"
        assert [sha for sha, _ in parse_commit_log(log)] == ["abc1234"]

    def test_keeps_non_ascii_subjects_intact(self):
        log = "abc1234 refactor: rename ds__outpatient_visit's seed to m…"
        assert parse_commit_log(log)[0][1].endswith("m…")

    def test_handles_empty_log(self):
        assert parse_commit_log("") == []


class TestPrBodyProvenance:
    """The body must never claim work this run did not do."""

    ARGS = ("2.60.13", "2.60.12", [("abc1234", "fix: something")], {"reporting-schema": 0})

    def test_claims_a_rebuild_only_when_it_rebuilt(self):
        body = render_pr_body(*self.ARGS, "2.60", "k8s-pg-release-2-60", built=True)
        assert "rebuilt the bundle" in body
        assert "was built against `k8s-pg-release-2-60`" in body

    def test_says_so_when_the_bundle_was_reused(self):
        body = render_pr_body(*self.ARGS, "2.60", "k8s-pg-release-2-60", built=False)
        assert "not rebuilt by this run" in body
        assert "rebuilt the bundle via" not in body
        assert "consistency check rather than proof" in body

    def test_flags_a_waived_database_check(self):
        body = render_pr_body(*self.ARGS, "2.60", None, built=False, db_waived=True)
        assert "was waived (`--no-db-check`)" in body

    def test_does_not_blame_a_flag_the_user_never_passed(self):
        # The check can fail without being waived; saying otherwise is a false claim.
        body = render_pr_body(*self.ARGS, "2.60", None, built=False, db_waived=False)
        assert "could not be verified" in body
        assert "--no-db-check" not in body

    def test_reports_an_uncomputable_change_list(self):
        body = render_pr_body(
            "2.55.7", "2.55.6", None, {"reporting-schema": 0}, "2.55", None, False
        )
        assert "could not locate" in body


class TestChangeList:
    """"Could not tell" and "nothing to tell" are different claims."""

    def test_renders_commits(self):
        rendered = _render_change_list([("abc1234", "fix: thing")], "2.59.2")
        assert rendered == ["- abc1234 fix: thing"]

    def test_empty_list_means_genuinely_no_commits(self):
        assert _render_change_list([], "2.59.2") == ["- no commits since the last bundle"]

    def test_none_means_the_range_could_not_be_computed(self):
        # The forward-port case: the baseline bundle is not in this branch's history,
        # so claiming "no commits" would assert something the run cannot know.
        rendered = _render_change_list(None, "2.59.2")[0]
        assert "could not locate" in rendered
        assert "v2.59.2" in rendered
        assert "no commits since the last bundle" not in rendered


class TestCompareBundles:
    """The drafted body's central claim rests on this comparison."""

    @staticmethod
    def _write(root, version, schema="select 1"):
        d = root / f"v{version}"
        d.mkdir(parents=True, exist_ok=True)
        (d / f"reporting-schema-v{version}-standard.sql").write_text(schema, encoding="utf-8")
        (d / f"reporting-docs-v{version}-standard.html").write_text("<html>", encoding="utf-8")

    @pytest.fixture
    def compiled(self, tmp_path, monkeypatch):
        monkeypatch.setattr(prepare_release, "COMPILED_DIR", tmp_path)
        return tmp_path

    def test_version_only_rebuild_reports_zero(self, compiled):
        # Same content, different version stamp -- must not read as a change.
        self._write(compiled, "2.60.12", schema="create view v2.60.12 as select 1")
        self._write(compiled, "2.60.13", schema="create view v2.60.13 as select 1")
        assert compare_bundles("2.60.13", "2.60.12") == {"reporting-schema": 0}

    def test_real_change_is_counted(self, compiled):
        self._write(compiled, "2.60.12", schema="select 1")
        self._write(compiled, "2.60.13", schema="select 1\nselect 2")
        assert compare_bundles("2.60.13", "2.60.12")["reporting-schema"] > 0

    def test_docs_are_never_compared(self, compiled):
        # dbt orders the manifest non-deterministically, so docs can never match.
        self._write(compiled, "2.60.12")
        self._write(compiled, "2.60.13")
        assert "reporting-docs" not in compare_bundles("2.60.13", "2.60.12")

    def test_missing_counterpart_reports_none(self, compiled):
        self._write(compiled, "2.60.13")
        (compiled / "v2.60.12").mkdir()
        summary = compare_bundles("2.60.13", "2.60.12")
        assert summary == {"reporting-schema": None}
        assert "No previous bundle" in _describe_diff(summary)


class TestBaseBranch:
    ALL_EXIST = staticmethod(lambda name: True)
    NONE_EXIST = staticmethod(lambda name: False)

    def test_version_branch_is_its_own_base(self):
        assert determine_base("2.54", "2.54", self.ALL_EXIST) == "2.54"

    def test_main_is_its_own_base(self):
        assert determine_base("main", "2.61", self.ALL_EXIST) == "main"

    def test_release_branch_targets_the_version_branch_not_itself(self):
        # Resuming on an already-cut release branch must not target that branch.
        assert determine_base("release/v2.57.15", "2.57", self.ALL_EXIST) == "2.57"

    def test_work_branch_targets_the_version_branch(self):
        assert determine_base("chore/tidy", "2.54", self.ALL_EXIST) == "2.54"

    def test_falls_back_to_main_without_a_version_branch(self):
        assert determine_base("release/v2.61.2", "2.61", self.NONE_EXIST) == "main"


class TestDatabaseGuard:
    def test_matches_the_release_host(self):
        assert host_matches_series("k8s-pg-release-2-57", "2.57")

    def test_rejects_another_series(self):
        # The guard exists for exactly this case: a stale .env pointing at another
        # version's release database builds a bundle that is wrong but looks valid.
        assert not host_matches_series("k8s-pg-release-2-60", "2.57")

    def test_rejects_a_prefix_collision(self):
        assert not host_matches_series("k8s-pg-release-2-57", "2.5")

    def test_rejects_a_non_release_host(self):
        assert not host_matches_series("tamanu-demo.example.internal", "2.57")

    def test_rejects_a_deployment_replica(self):
        # Seen in the wild: a worktree .env still pointing at a deployment replica
        # (hostname synthesised -- this repo is public).
        assert not host_matches_series("infra-replica-example-central", "2.54")


class TestDbtHostParsing:
    # dbt prefixes each line with an ANSI reset and a timestamp, so the host line is
    # not anchorable to the start of the line.
    DBT_DEBUG_OUTPUT = (
        "\x1b[0m22:39:00  Connection:\n"
        "\x1b[0m22:39:00    host: infra-replica-example-central\n"
        "\x1b[0m22:39:00    port: 5432\n"
        "\x1b[0m22:39:00    Connection test: [\x1b[32mOK connection ok\x1b[0m]\n"
    )

    def test_parses_host_through_ansi_and_timestamps(self):
        assert parse_dbt_host(self.DBT_DEBUG_OUTPUT) == "infra-replica-example-central"

    def test_returns_none_when_absent(self):
        assert parse_dbt_host("dbt failed to start") is None

    def test_returns_none_on_empty_output(self):
        assert parse_dbt_host("") is None
        assert parse_dbt_host(None) is None


class TestDiffDescription:
    def test_reports_a_version_only_rebuild(self):
        summary = {"reporting-schema": 0}
        assert "byte-identical" in _describe_diff(summary)

    def test_reports_real_changes(self):
        summary = {"reporting-schema": 340}
        described = _describe_diff(summary)
        assert "reporting-schema (340 lines)" in described

    def test_always_explains_why_docs_are_not_compared(self):
        for summary in ({"reporting-schema": 0}, {"reporting-schema": 5}):
            assert "reporting-docs is not compared" in _describe_diff(summary)

    def test_handles_no_previous_bundle(self):
        assert "No previous bundle" in _describe_diff({"reporting-schema": None})

    def test_normalise_blanks_the_version_stamp(self):
        assert normalise("view v2.54.32 x", "2.54.32") == "view vVERSION x"

    def test_normalise_keeps_real_content_differences(self):
        old = "create view v2.60.12 as select a from t"
        new = "create view v2.60.13 as select b from t"
        assert normalise(old, "2.60.12") != normalise(new, "2.60.13")

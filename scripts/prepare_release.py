#!/usr/bin/env python3
"""Prepare a release: cut the branch, bump the version, build and verify the bundle.

Replaces the hand-run sequence behind every `release: bump version to X.Y.Z` commit:
work out the next version, cut a `release/vX.Y.Z` branch off the version branch, write
both version stamps, build the reporting assets, then verify the result and draft the
commit message and PR body from the commits since the last bundle.

Stops before `git commit`, `git push` and `gh pr create`. Those stay manual: the push
and the PR are the steps that are expensive to unwind, so a human reads the summary
first. Pass --commit to have the commit made for you; the push is never automatic.

Usage:
    uv run --env-file .env python scripts/prepare_release.py
    uv run --env-file .env python scripts/prepare_release.py --dry-run
    uv run --env-file .env python scripts/prepare_release.py --version 2.54.35
    uv run --env-file .env python scripts/prepare_release.py --rebuild --commit

The `uv run --env-file .env` prefix matters: a bare `dbt` picks up an unpinned version
and never sees the env file, so it behaves differently from CI.

Why the database check (--no-db-check to skip):
    The bundle is built by running dbt against a database. Building against the wrong
    one -- a stale .env still pointing at another version's release database, or the
    demo database -- produces artefacts that look completely valid and are wrong for
    the branch. That is the one silent-corruption path in the release process, so the
    resolved host is checked against the version being released before anything is
    built. When the release environment is unreachable, --no-db-check lets you proceed
    against an already-built bundle, at the cost of that guarantee.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

from utils import cprint, execute_command, execute_command_with_output

BASE_DIR = Path(os.getcwd())
DBT_PROJECT = BASE_DIR / "dbt_project.yml"
PYPROJECT = BASE_DIR / "pyproject.toml"
COMPILED_DIR = BASE_DIR / "compiled"

# The three aggregate artefacts that are committed. Everything else the build emits
# (the per-report JSONs) is gitignored via `compiled/*/*.json` and stays untracked.
AGGREGATES = (
    ("analytics-metadata", "yml"),
    ("reporting-schema", "sql"),
    ("reporting-docs", "html"),
)

# reporting-docs is deliberately not diffed. dbt's docs bundle embeds the manifest,
# which lists `sources` and `depends_on.nodes` in a non-deterministic order, so two
# builds of identical code never match byte for byte. Comparing it would report a
# change on every release and teach everyone to ignore the comparison. The schema and
# metadata artefacts are deterministic, and they are the ones that describe behaviour.
COMPARABLE = frozenset({"analytics-metadata", "reporting-schema"})

PROTECTED_BRANCH = re.compile(r"^(main|\d+\.\d+)$")
VERSION_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


# --------------------------------------------------------------------------------
# Version handling
# --------------------------------------------------------------------------------


def parse_version(version):
    """Parse 'X.Y.Z' into an (major, minor, patch) int tuple."""
    match = VERSION_RE.match(version.strip())
    if not match:
        raise ValueError(f"Not a semver version: {version!r}")
    return tuple(int(part) for part in match.groups())


def bump_patch(version):
    """Return the next patch version after `version`."""
    major, minor, patch = parse_version(version)
    return f"{major}.{minor}.{patch + 1}"


def minor_series(version):
    """Return the 'major.minor' series a version belongs to."""
    major, minor, _ = parse_version(version)
    return f"{major}.{minor}"


def read_dbt_project_version(text):
    """Read the top-level `version:` key out of dbt_project.yml text.

    Keyed on the pattern rather than a line number -- the key does not sit at a
    consistent position across version branches.
    """
    match = re.search(r"^version:\s*(\S+)\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError("No top-level `version:` key found in dbt_project.yml")
    return match.group(1)


def replace_dbt_project_version(text, new_version):
    """Rewrite the top-level `version:` key, leaving the rest of the file untouched."""
    updated, count = re.subn(
        r"^version:\s*\S+\s*$",
        f"version: {new_version}",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise ValueError("Could not rewrite `version:` in dbt_project.yml")
    return updated


def replace_pyproject_version(text, new_version):
    """Rewrite the [project] `version = "..."` key in pyproject.toml."""
    updated, count = re.subn(
        r'^version\s*=\s*"[^"]+"\s*$',
        f'version = "{new_version}"',
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count != 1:
        raise ValueError("Could not rewrite `version` in pyproject.toml")
    return updated


# --------------------------------------------------------------------------------
# Git helpers
# --------------------------------------------------------------------------------


def git(*args, check=True):
    """Run a git command and return its stripped stdout."""
    # encoding is explicit: git emits UTF-8, but `text=True` decodes with the locale
    # encoding, which mangles non-ASCII commit subjects on Windows.
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=BASE_DIR,
        check=False,
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout.strip()


def current_branch():
    return git("rev-parse", "--abbrev-ref", "HEAD")


def working_tree_is_clean():
    return git("status", "--porcelain") == ""


def assert_up_to_date_with_origin(branch):
    """Warn if the branch has diverged from its remote counterpart."""
    remote = f"origin/{branch}"
    if git("ls-remote", "--exit-code", "--heads", "origin", branch, check=False) == "":
        cprint(f"No remote branch {remote}; skipping the up-to-date check.", "warning")
        return

    git("fetch", "origin", branch)
    counts = git("rev-list", "--left-right", "--count", f"{branch}...{remote}")
    ahead, behind = (int(part) for part in counts.split())
    if behind:
        raise RuntimeError(
            f"{branch} is {behind} commit(s) behind {remote}. Rebase before releasing."
        )
    if ahead:
        cprint(f"{branch} is {ahead} commit(s) ahead of {remote}.", "warning")


def bundle_versions_from_paths(paths, series):
    """Pick the bundle versions in `series` out of a list of paths, newest first."""
    versions = set()
    for path in paths:
        match = re.match(rf"compiled/v({re.escape(series)}\.\d+)/", path.strip())
        if match:
            versions.add(match.group(1))
    # Sort numerically -- lexical order puts v2.54.7 above v2.54.32.
    return sorted(versions, key=parse_version, reverse=True)


def tracked_bundle_versions(series):
    """Return released bundle versions in `series`, newest first.

    Reads tracked files rather than the compiled/ directory: a local build leaves
    directories behind that were never released, and those must not be treated as
    the baseline to diff against.
    """
    listing = git("ls-files", f"compiled/v{series}.*")
    return bundle_versions_from_paths(listing.splitlines(), series)


def determine_base(branch, series, branch_exists):
    """Work out which branch the release PR should target.

    The current branch is only the answer when it is the version branch itself. When
    the script is resumed on an already-cut `release/vX.Y.Z` branch -- or run from a
    work branch -- the base is the version branch for the series, falling back to main.
    """
    if PROTECTED_BRANCH.match(branch):
        return branch
    return series if branch_exists(series) else "main"


def remote_branch_exists(name):
    return git("ls-remote", "--exit-code", "--heads", "origin", name, check=False) != ""


RELEASE_COMMIT = re.compile(r"^release: bump version", re.IGNORECASE)


def parse_commit_log(log):
    """Turn `%h %s` log lines into `(sha, subject)` pairs, dropping release bumps.

    A previous release commit is not part of what a release ships, and re-running the
    script on an already-committed branch would otherwise list the bump itself.
    """
    entries = []
    for line in log.splitlines():
        sha, _, subject = line.partition(" ")
        if sha and not RELEASE_COMMIT.match(subject):
            entries.append((sha, subject))
    return entries


def commits_since(ref):
    """Return `(sha, subject)` pairs for commits after `ref`, oldest first."""
    return parse_commit_log(git("log", "--reverse", "--format=%h %s", f"{ref}..HEAD"))


def commit_that_added(path):
    """Return the SHA of the commit that last touched `path`, or None."""
    return git("log", "--format=%H", "-1", "--", path) or None


# --------------------------------------------------------------------------------
# Database guard
# --------------------------------------------------------------------------------


ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")


def parse_dbt_host(output):
    """Pull the resolved host out of `dbt debug` output.

    dbt prefixes every line with ANSI colour codes and a timestamp, so the host line
    cannot be anchored to the start of the line.
    """
    match = re.search(r"\bhost:\s*(\S+)", ANSI_ESCAPE.sub("", output or ""))
    return match.group(1) if match else None


def resolve_dbt_host():
    """Return the host dbt resolves for the current profile, or None if unreachable."""
    result = execute_command_with_output("dbt debug --profiles-dir config")
    return parse_dbt_host(result.stdout)


def host_matches_series(host, series):
    """True when `host` looks like the release database for `series`.

    Hosts are named `k8s-pg-release-2-57`, so the series is compared with its dot
    replaced by a hyphen. The digit boundaries stop 2.5 matching a 2.57 host, while
    still allowing the hyphen that always precedes the token in that naming scheme.
    """
    token = series.replace(".", "-")
    return re.search(rf"(?<!\d){re.escape(token)}(?!\d)", host) is not None


def check_database(series, allow_mismatch=False):
    """Verify the resolved database matches the version being released."""
    cprint("Checking the target database matches the release series...", "info")
    host = resolve_dbt_host()

    if host is None:
        message = (
            "Could not resolve the dbt target host -- the release environment may be "
            "unreachable."
        )
        if allow_mismatch:
            cprint(message + " Continuing (--no-db-check).", "warning")
            return None
        raise RuntimeError(
            message + "\nBuild against a reachable database, or pass --no-db-check to "
            "prepare a release from an already-built bundle."
        )

    if not host_matches_series(host, series):
        message = (
            f"dbt resolves to host {host!r}, which does not look like the release "
            f"database for {series}. Building here would produce a bundle that is "
            f"valid-looking and wrong for this branch."
        )
        if allow_mismatch:
            cprint(message + " Continuing (--no-db-check).", "warning")
            return host
        raise RuntimeError(message + "\nFix .env, or pass --no-db-check if deliberate.")

    cprint(f"  Target host {host} matches {series}.", "success")
    return host


# --------------------------------------------------------------------------------
# Bundle verification
# --------------------------------------------------------------------------------


def bundle_paths(version):
    """Return the expected paths of the three committed aggregates for `version`."""
    return [
        COMPILED_DIR / f"v{version}" / f"{name}-v{version}-standard.{ext}"
        for name, ext in AGGREGATES
    ]


def bundle_is_built(version):
    return all(path.exists() for path in bundle_paths(version))


# dbt stamps every build with fresh timestamps and an invocation id. They say nothing
# about what the release contains, so they are normalised out alongside the version --
# otherwise every rebuild looks like it changed something.
BUILD_METADATA = re.compile(
    r'"(generated_at|invocation_id|invocation_started_at|run_started_at)":\s*"[^"]*"'
)


def normalise(text, version):
    """Blank out the version stamp and build metadata, to compare on content alone."""
    return BUILD_METADATA.sub(r'"\1": "NORMALISED"', text.replace(version, "VERSION"))


def compare_bundles(new_version, old_version):
    """Diff each aggregate against the previous release, ignoring the version stamp.

    Returns a {artefact: changed_line_count} map. A zero means that artefact changed
    only in its version stamp -- which is the expected result for a release that
    carries no model changes, and a red flag for one that should.
    """
    import difflib

    summary = {}
    for (name, ext), new_path in zip(AGGREGATES, bundle_paths(new_version)):
        if name not in COMPARABLE:
            continue
        old_path = COMPILED_DIR / f"v{old_version}" / f"{name}-v{old_version}-standard.{ext}"
        if not old_path.exists():
            summary[name] = None
            continue

        new_lines = normalise(new_path.read_text(encoding="utf-8"), new_version).splitlines()
        old_lines = normalise(old_path.read_text(encoding="utf-8"), old_version).splitlines()
        changed = sum(
            1
            for line in difflib.unified_diff(old_lines, new_lines, n=0)
            if line.startswith(("+", "-")) and not line.startswith(("+++", "---"))
        )
        summary[name] = changed
    return summary


# --------------------------------------------------------------------------------
# Message drafting
# --------------------------------------------------------------------------------


def render_commit_message(new_version, old_version, commits, diff_summary):
    """Draft the release commit message."""
    lines = [
        f"release: bump version to {new_version} and rebuild the reporting bundle",
        "",
        f"Bumps {old_version} -> {new_version} and commits the compiled reporting",
        "bundle for that version.",
        "",
        "Per .gitignore (compiled/*/*.json) only the three aggregate artefacts are",
        "committed -- reporting-schema, reporting-docs, analytics-metadata. The",
        "per-report JSONs are build output and stay untracked.",
        "",
        "## What's in this release",
        "",
        f"Everything merged since the last bundle (v{old_version}):",
        "",
    ]
    if commits:
        lines += [f"- {sha} {subject}" for sha, subject in commits]
    else:
        lines.append("- no commits since the last bundle")
    lines += ["", _describe_diff(diff_summary), ""]
    return "\n".join(lines)


def render_pr_body(new_version, old_version, commits, diff_summary, base, host, built):
    """Draft the PR body, mirroring the structure of previous release PRs.

    `built` records whether this run actually rebuilt the bundle. When it did not, the
    host check confirms the environment is correct now, but says nothing about what the
    existing artefacts were built against -- and the body must not imply otherwise.
    """
    if host and built:
        provenance = (
            f"- the bundle was built against `{host}`, the matching release database "
            f"for this branch."
        )
    elif host:
        provenance = (
            f"- `dbt debug` resolves to `{host}`, the matching release database for this "
            f"branch. The bundle itself was built beforehand, so this is a consistency "
            f"check rather than proof of the artefacts' provenance."
        )
    else:
        provenance = (
            "- the target database was not verified (`--no-db-check`), so the artefacts' "
            "provenance is unconfirmed."
        )
    build_line = (
        "- rebuilt the bundle via `scripts/build_reporting_assets.py`.\n"
        if built
        else "- reused the bundle already on disk; it was not rebuilt by this run.\n"
    )
    commit_lines = (
        "\n".join(f"- {sha} {subject}" for sha, subject in commits)
        or "- no commits since the last bundle"
    )
    return f"""## Summary

Bumps `{old_version}` → `{new_version}` and commits the compiled reporting bundle for
that version.

Per `.gitignore` (`compiled/*/*.json`) only the three aggregate artefacts are committed —
`reporting-schema`, `reporting-docs`, `analytics-metadata`. The per-report JSONs are
build output and stay untracked.

## What's in this release

Everything merged since the last bundle (`v{old_version}`):

{commit_lines}

{_describe_diff(diff_summary)}

## Base

Targets `{base}`. Version-branch release, so this merges with a merge commit rather
than a squash.

## Testing

Prepared with `scripts/prepare_release.py`:

{provenance}
{build_line}- diffed each deterministic aggregate against `v{old_version}` with the version stamp
  normalised. `reporting-docs` is not compared: dbt embeds build timestamps in it and
  orders its dependency lists non-deterministically.

Those commits carried their own tests when they landed, and CI runs the full
`dbt-tests` suite on this PR.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
"""


def _describe_diff(diff_summary):
    """One paragraph describing how the regenerated artefacts differ."""
    known = {name: count for name, count in diff_summary.items() if count is not None}
    if not known:
        return "No previous bundle was available to compare against."

    footnote = (
        " reporting-docs is not compared: dbt's docs bundle embeds build timestamps and "
        "orders its dependency lists non-deterministically, so it never matches byte for "
        "byte even when nothing changed."
    )

    changed = {name: count for name, count in known.items() if count}
    if not changed:
        return (
            "The regenerated reporting-schema and analytics-metadata are byte-identical "
            "to the previous bundle once the version stamp is normalised: no report or "
            "model behaviour changes in this release." + footnote
        )

    detail = ", ".join(f"{name} ({count} lines)" for name, count in sorted(changed.items()))
    return (
        f"The regenerated artefacts differ beyond the version stamp in {detail}, "
        f"reflecting the commits listed above rather than being a version-only rebuild."
        + footnote
    )


# --------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Prepare a release: bump the version, build and verify the bundle.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--version",
        help="Release this version instead of bumping the patch number.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would happen without writing, branching or building.",
    )
    parser.add_argument(
        "--rebuild",
        action="store_true",
        help="Rebuild even when the bundle for the target version already exists.",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="Never build; verify and draft from the bundle already on disk.",
    )
    parser.add_argument(
        "--no-db-check",
        action="store_true",
        help="Proceed even if the target database is unreachable or mismatched.",
    )
    parser.add_argument(
        "--no-branch",
        action="store_true",
        help="Stay on the current branch instead of cutting release/vX.Y.Z.",
    )
    parser.add_argument(
        "--commit",
        action="store_true",
        help="Stage the version files and bundle and make the release commit.",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    # ---- Establish where we are ------------------------------------------------
    branch = current_branch()
    dbt_text = DBT_PROJECT.read_text(encoding="utf-8")
    old_version = read_dbt_project_version(dbt_text)
    new_version = args.version or bump_patch(old_version)
    parse_version(new_version)
    series = minor_series(new_version)

    cprint(f"\nPreparing release {new_version} (from {old_version}) on {branch}", "info")

    if PROTECTED_BRANCH.match(branch) and args.no_branch and not args.dry_run:
        raise RuntimeError(
            f"{branch} is protected and --no-branch was passed; there is nowhere to "
            f"commit. Drop --no-branch to cut release/v{new_version}."
        )

    if not PROTECTED_BRANCH.match(branch) and not branch.startswith("release/"):
        cprint(f"Releasing from {branch}, which is not a version branch.", "warning")

    if PROTECTED_BRANCH.match(branch):
        assert_up_to_date_with_origin(branch)

    if minor_series(old_version) != series:
        cprint(
            f"Target {new_version} is not in the {minor_series(old_version)} series "
            f"this branch carries.",
            "warning",
        )

    # ---- Guard the database before anything is built ---------------------------
    building = not args.skip_build and (args.rebuild or not bundle_is_built(new_version))
    host = None
    if building or not args.no_db_check:
        try:
            host = check_database(series, allow_mismatch=args.no_db_check)
        except RuntimeError as err:
            if building:
                raise
            cprint(str(err), "warning")

    # ---- Cut the release branch ------------------------------------------------
    release_branch = f"release/v{new_version}"
    if args.no_branch or branch == release_branch:
        release_branch = branch
    elif args.dry_run:
        cprint(f"Would cut {release_branch} off {branch}.", "info")
    else:
        git("checkout", "-b", release_branch)
        cprint(f"Cut {release_branch} off {branch}.", "success")

    # ---- Write the version stamps ----------------------------------------------
    if args.dry_run:
        cprint(f"Would stamp {old_version} -> {new_version} in both version files.", "info")
    elif old_version != new_version:
        DBT_PROJECT.write_text(
            replace_dbt_project_version(dbt_text, new_version), encoding="utf-8"
        )
        PYPROJECT.write_text(
            replace_pyproject_version(PYPROJECT.read_text(encoding="utf-8"), new_version),
            encoding="utf-8",
        )
        cprint(f"Stamped {new_version} in dbt_project.yml and pyproject.toml.", "success")

    # ---- Build -----------------------------------------------------------------
    if args.dry_run:
        cprint("Would build the reporting assets.", "info")
    elif building:
        execute_command(f"python {Path('scripts') / 'build_reporting_assets.py'}")
    elif args.skip_build:
        cprint("Skipping the build (--skip-build).", "warning")
    else:
        cprint(f"Bundle for {new_version} already built; reusing it.", "warning")

    # ---- Verify ----------------------------------------------------------------
    previous = [v for v in tracked_bundle_versions(series) if v != new_version]
    old_bundle = previous[0] if previous else None

    if args.dry_run:
        cprint(
            f"Would verify the bundle against "
            f"{'v' + old_bundle if old_bundle else 'no previous release'}.",
            "info",
        )
        return 0

    missing = [str(path) for path in bundle_paths(new_version) if not path.exists()]
    if missing:
        raise RuntimeError("Bundle is incomplete; missing:\n  " + "\n  ".join(missing))

    diff_summary = compare_bundles(new_version, old_bundle) if old_bundle else {}
    if old_bundle:
        cprint(f"\nCompared against the last released bundle v{old_bundle}:", "info")
        for name, count in diff_summary.items():
            if count is None:
                cprint(f"  {name}: no counterpart in v{old_bundle}", "warning")
            elif count:
                cprint(f"  {name}: {count} changed line(s) beyond the version stamp", "info")
            else:
                cprint(f"  {name}: identical once the version stamp is normalised", "info")
    else:
        cprint(f"No previous released bundle in the {series} series to compare.", "warning")

    # ---- Draft the messages ----------------------------------------------------
    baseline = commit_that_added(f"compiled/v{old_bundle}") if old_bundle else None
    commits = commits_since(baseline) if baseline else []

    base = determine_base(branch, series, remote_branch_exists)
    commit_message = render_commit_message(new_version, old_bundle or old_version, commits, diff_summary)
    pr_body = render_pr_body(
        new_version, old_bundle or old_version, commits, diff_summary, base, host, building
    )

    out_dir = BASE_DIR / "target"
    out_dir.mkdir(exist_ok=True)
    message_path = out_dir / f"release-v{new_version}-commit-message.txt"
    body_path = out_dir / f"release-v{new_version}-pr-body.md"
    message_path.write_text(commit_message, encoding="utf-8")
    body_path.write_text(pr_body, encoding="utf-8")

    # ---- Stage, and commit only if asked ---------------------------------------
    paths = ["dbt_project.yml", "pyproject.toml", f"compiled/v{new_version}"]
    git("add", *paths)
    cprint(f"\nStaged: {', '.join(paths)}", "success")

    if args.commit:
        git("commit", "-F", str(message_path))
        cprint(f"Committed: {git('log', '--format=%h %s', '-1')}", "success")

    # ---- Hand back to the human ------------------------------------------------
    cprint("\nPrepared. Review, then push and open the PR yourself:", "info")
    if not args.commit:
        print(f"  git commit -F {message_path.relative_to(BASE_DIR)}")
    print(f"  git push -u origin {release_branch}")
    print(
        f'  gh pr create --base {base} '
        f'--title "release: bump version to {new_version} and rebuild the reporting bundle" '
        f"--body-file {body_path.relative_to(BASE_DIR)}"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as err:  # noqa: BLE001 -- surface any failure as a clean exit
        cprint(f"Error: {err}", "error")
        sys.exit(1)

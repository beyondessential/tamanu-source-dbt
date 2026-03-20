#!/usr/bin/env python3
"""Forward-port a patch release to all higher-minor branches in this repo.

When v2.49.9 is released and main is at v2.51, this script:
  - Finds the commits introduced between v2.49.8 and v2.49.9
  - Cherry-picks them onto branch "2.50" and onto "main"
  - Bumps the version in dbt_project.yml and pyproject.toml to the next patch
  - Opens a PR for each target branch

Only acts when the new tag is a patch on a *lower* minor than at least one
other branch. Tags on the current highest minor are ignored.

Usage (called by GHA on release: published):
    NEW_TAG=v2.49.9 REPO=beyondessential/tamanu-source-dbt python scripts/forwardport_patch.py

Requires GH_TOKEN with repo write access. Must run in a full git clone
(fetch-depth: 0, fetch-tags: true).
"""

import json
import os
import re
import subprocess
import sys

import yaml


# ---------------------------------------------------------------------------
# Pure helpers (no I/O — easily unit-tested)
# ---------------------------------------------------------------------------

def get_major_minor_patch(version: str) -> tuple[int, int, int]:
    """Parse 'v2.49.9' or '2.49.9' → (2, 49, 9)."""
    v = version.lstrip("v")
    parts = v.split(".")
    return int(parts[0]), int(parts[1]), int(parts[2])


def get_version_tags_for_minor_from_list(all_tags: list[str], major_minor: str) -> list[str]:
    """Filter *all_tags* to vMAJ.MIN.* tags and return them sorted by patch ascending."""
    pattern = re.compile(rf"^v{re.escape(major_minor)}\.(\d+)$")
    matching = [t for t in all_tags if pattern.match(t)]
    matching.sort(key=lambda t: int(t.split(".")[-1]))
    return matching


def get_previous_tag(new_tag: str, tags: list[str]) -> str | None:
    """Given a sorted list of tags for the same major.minor, return the one before *new_tag*."""
    if new_tag not in tags:
        return None
    idx = tags.index(new_tag)
    if idx == 0:
        return None
    return tags[idx - 1]


def get_higher_minor_branches_from_list(
    branch_names: list[str], major: int, minor: int
) -> list[str]:
    """Return branch names of the form MAJ.MIN where (MAJ, MIN) > (major, minor)."""
    pattern = re.compile(r"^(\d+)\.(\d+)$")
    result = []
    for b in branch_names:
        m = pattern.match(b)
        if m:
            bmaj, bmin = int(m.group(1)), int(m.group(2))
            if (bmaj, bmin) > (major, minor):
                result.append(b)
    return result


# ---------------------------------------------------------------------------
# Version file helpers
# ---------------------------------------------------------------------------

def update_version_in_files(new_version: str) -> None:
    """Update version in dbt_project.yml and pyproject.toml."""
    with open("dbt_project.yml") as f:
        content = f.read()
    content = re.sub(
        r"^version:\s*['\"]?[\d.]+['\"]?",
        f"version: '{new_version}'",
        content,
        flags=re.MULTILINE,
    )
    with open("dbt_project.yml", "w") as f:
        f.write(content)

    with open("pyproject.toml") as f:
        content = f.read()
    content = re.sub(
        r'^version\s*=\s*"[\d.]+"',
        f'version = "{new_version}"',
        content,
        flags=re.MULTILINE,
    )
    with open("pyproject.toml", "w") as f:
        f.write(content)


def _read_version_from_yaml(text: str) -> str:
    config = yaml.safe_load(text)
    return str(config["version"])


def get_branch_version(branch: str) -> str:
    result = subprocess.run(
        ["git", "show", f"origin/{branch}:dbt_project.yml"],
        capture_output=True, text=True, check=True,
    )
    return _read_version_from_yaml(result.stdout)


def next_patch_version(version: str) -> str:
    major, minor, patch = get_major_minor_patch(version)
    return f"{major}.{minor}.{patch + 1}"


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------

def get_all_tags() -> list[str]:
    result = subprocess.run(
        ["git", "tag", "--list"], capture_output=True, text=True, check=True,
    )
    return result.stdout.strip().splitlines()


def get_all_remote_branches() -> list[str]:
    result = subprocess.run(
        ["git", "branch", "-r", "--list", "origin/*"],
        capture_output=True, text=True, check=True,
    )
    branches = []
    for line in result.stdout.strip().splitlines():
        b = line.strip().removeprefix("origin/")
        if b and b != "HEAD" and not b.startswith("HEAD ->"):
            branches.append(b)
    return branches


def get_patch_commits(prev_tag: str, new_tag: str) -> list[str]:
    """Return commit SHAs introduced between prev_tag and new_tag, oldest first."""
    result = subprocess.run(
        ["git", "log", "--pretty=%H", f"{prev_tag}..{new_tag}"],
        capture_output=True, text=True, check=True,
    )
    commits = result.stdout.strip().splitlines()
    return list(reversed(commits))  # chronological order


# ---------------------------------------------------------------------------
# GitHub API helper
# ---------------------------------------------------------------------------

def gh_api(path: str, method: str = "GET", data: dict = None):
    cmd = ["gh", "api", path]
    if method != "GET":
        cmd += ["--method", method]
    input_json = None
    if data is not None:
        input_json = json.dumps(data)
        cmd += ["--input", "-"]

    result = subprocess.run(cmd, capture_output=True, text=True, input=input_json, check=False)

    if result.returncode != 0:
        raise RuntimeError(f"gh api {path} failed:\n{result.stderr.strip()}")

    if result.stdout.strip():
        return json.loads(result.stdout)
    return {}


# ---------------------------------------------------------------------------
# Core forward-port logic
# ---------------------------------------------------------------------------

def forwardport_to_branch(
    target_branch: str,
    commits: list[str],
    new_tag: str,
    repo: str,
) -> None:
    """Cherry-pick *commits* onto *target_branch*, bump version, open a PR."""
    current_version = get_branch_version(target_branch)
    bump_version = next_patch_version(current_version)
    pr_branch = f"chore/forwardport-{new_tag}-to-{target_branch}"

    print(f"\n→ Forward-porting {new_tag} onto {target_branch} (will bump to {bump_version})")

    subprocess.run(
        ["git", "checkout", "-b", pr_branch, f"origin/{target_branch}"],
        check=True,
    )

    for sha in commits:
        result = subprocess.run(
            ["git", "cherry-pick", "--allow-empty", sha],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            # Try skipping an already-applied (empty) commit first
            skip_result = subprocess.run(
                ["git", "cherry-pick", "--skip"],
                capture_output=True, text=True,
            )
            if skip_result.returncode != 0:
                # Real conflict — abort and skip this branch
                subprocess.run(["git", "cherry-pick", "--abort"], capture_output=True)
                subprocess.run(["git", "checkout", "main"], capture_output=True)
                subprocess.run(["git", "branch", "-D", pr_branch], capture_output=True)
                print(f"  CONFLICT cherry-picking {sha[:8]} onto {target_branch}, skipping branch")
                return

    # Force the correct target-branch version regardless of what cherry-picks set
    update_version_in_files(bump_version)
    subprocess.run(["git", "add", "dbt_project.yml", "pyproject.toml"], check=True)

    # Only commit if there are staged changes
    diff_result = subprocess.run(["git", "diff", "--cached", "--quiet"], capture_output=True)
    if diff_result.returncode != 0:
        subprocess.run(
            ["git", "commit", "-m", f"chore: bump version to {bump_version}"],
            check=True,
        )

    subprocess.run(["git", "push", "origin", pr_branch], check=True)

    gh_api(f"repos/{repo}/pulls", method="POST", data={
        "title": f"chore: forward-port {new_tag} to {target_branch} (→ {bump_version})",
        "head": pr_branch,
        "base": target_branch,
        "body": (
            f"Automatically forward-ported from `{new_tag}`.\n\n"
            f"Bumps version to `{bump_version}`."
        ),
    })

    subprocess.run(["git", "checkout", "main"], check=True)
    print(f"  PR opened for {target_branch}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    new_tag = os.environ.get("NEW_TAG", "").strip()
    repo = os.environ.get("REPO", "").strip()

    if not new_tag or not repo:
        print("ERROR: NEW_TAG and REPO must be set", file=sys.stderr)
        sys.exit(1)

    if not new_tag.startswith("v"):
        new_tag = f"v{new_tag}"

    try:
        major, minor, patch = get_major_minor_patch(new_tag)
    except (ValueError, IndexError):
        print(f"Skipping: {new_tag} is not semver vX.Y.Z")
        sys.exit(0)

    all_tags = get_all_tags()
    major_minor = f"{major}.{minor}"
    sorted_tags = get_version_tags_for_minor_from_list(all_tags, major_minor)

    if len(sorted_tags) < 2:
        print(f"Only one tag for v{major_minor}.*, nothing to cherry-pick from")
        sys.exit(0)

    prev_tag = get_previous_tag(new_tag, sorted_tags)
    if prev_tag is None:
        print(f"Could not find previous tag before {new_tag}")
        sys.exit(0)

    commits = get_patch_commits(prev_tag, new_tag)
    if not commits:
        print(f"No commits between {prev_tag} and {new_tag}")
        sys.exit(0)

    print(f"Cherry-picking {len(commits)} commit(s) from {prev_tag}..{new_tag}")

    all_remote_branches = get_all_remote_branches()
    higher_branches = get_higher_minor_branches_from_list(all_remote_branches, major, minor)

    # Include main if its version is a higher minor
    main_version = get_branch_version("main")
    mmaj, mmin, _ = get_major_minor_patch(main_version)
    include_main = (mmaj, mmin) > (major, minor)

    targets = list(higher_branches)
    if include_main:
        targets.append("main")

    if not targets:
        print(f"No higher-minor branches for v{major}.{minor}, nothing to forward-port")
        sys.exit(0)

    print(f"Target branches: {', '.join(targets)}")

    subprocess.run(
        ["git", "config", "user.email", "github-actions[bot]@users.noreply.github.com"],
        check=True,
    )
    subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=True)

    for branch in targets:
        forwardport_to_branch(branch, commits, new_tag, repo)

    print("\nDone.")


if __name__ == "__main__":
    main()

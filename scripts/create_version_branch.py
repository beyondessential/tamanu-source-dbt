#!/usr/bin/env python3
"""Create a maintenance branch for the previous minor version when a new minor/major is released.

When v2.51.0 is released, creates branch "2.50" pointing at the latest v2.50.* tag.
When v3.0.0 is released, creates branch "2.X" pointing at the latest v2.*.* tag.

Only acts when the tag is vX.Y.0. All other tags are ignored.

Usage (called by GHA on release: published):
    NEW_TAG=v2.51.0 REPO=beyondessential/tamanu-source-dbt python scripts/create_version_branch.py
"""

import json
import os
import re
import subprocess
import sys


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


def get_all_tag_refs(repo: str) -> list[dict]:
    """Return all tag refs from the repository."""
    return gh_api(f"repos/{repo}/git/refs/tags")


def find_latest_tag_for_minor(refs: list[dict], major: int, minor: int) -> str | None:
    """Find the latest vMAJOR.MINOR.* tag from a list of git refs.

    Returns the tag name (e.g. 'v2.50.4') or None if no matching tags exist.
    """
    pattern = re.compile(rf"^refs/tags/v{major}\.{minor}\.(\d+)$")
    best_tag = None
    best_patch = -1
    for ref in refs:
        m = pattern.match(ref["ref"])
        if m:
            patch = int(m.group(1))
            if patch > best_patch:
                best_patch = patch
                best_tag = ref["ref"].removeprefix("refs/tags/")
    return best_tag


def find_latest_tag_for_major(refs: list[dict], major: int) -> str | None:
    """Find the latest vMAJOR.*.* tag from a list of git refs.

    Returns the tag name (e.g. 'v2.51.3') or None if no matching tags exist.
    Sorts by (minor, patch) numerically to avoid lexicographic issues.
    """
    pattern = re.compile(rf"^refs/tags/v{major}\.(\d+)\.(\d+)$")
    best_tag = None
    best_key = (-1, -1)
    for ref in refs:
        m = pattern.match(ref["ref"])
        if m:
            key = (int(m.group(1)), int(m.group(2)))
            if key > best_key:
                best_key = key
                best_tag = ref["ref"].removeprefix("refs/tags/")
    return best_tag


def get_commit_sha_for_tag(repo: str, tag: str) -> str:
    """Resolve a tag name to the underlying commit SHA (derefs annotated tags)."""
    data = gh_api(f"repos/{repo}/git/refs/tags/{tag}")
    obj = data["object"]
    if obj["type"] == "commit":
        return obj["sha"]
    # Annotated tag — follow the tag object to the commit
    tag_obj = gh_api(f"repos/{repo}/git/tags/{obj['sha']}")
    return tag_obj["object"]["sha"]


def branch_exists(repo: str, branch: str) -> bool:
    cmd = ["gh", "api", f"repos/{repo}/git/refs/heads/{branch}"]
    result = subprocess.run(cmd, capture_output=True)
    return result.returncode == 0


def create_branch(repo: str, branch: str, sha: str) -> None:
    gh_api(f"repos/{repo}/git/refs", method="POST", data={
        "ref": f"refs/heads/{branch}",
        "sha": sha,
    })


def main():
    new_tag = os.environ.get("NEW_TAG", "").strip().lstrip("v")
    repo = os.environ.get("REPO", "").strip()

    if not new_tag or not repo:
        print("ERROR: NEW_TAG and REPO must be set", file=sys.stderr)
        sys.exit(1)

    parts = new_tag.split(".")
    if len(parts) != 3:
        print(f"Skipping: tag v{new_tag} is not semver X.Y.Z")
        sys.exit(0)

    try:
        major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])
    except ValueError:
        print(f"Skipping: tag v{new_tag} has non-integer version components")
        sys.exit(0)

    if patch != 0:
        print(f"Skipping: v{new_tag} is a patch release, not a new minor/major")
        sys.exit(0)

    refs = get_all_tag_refs(repo)

    if minor == 0:
        # Major bump (e.g. v3.0.0) — create a branch for the last minor of the previous major
        prev_major = major - 1
        source_tag = find_latest_tag_for_major(refs, prev_major)
        if source_tag is None:
            print(f"No tags found for major {prev_major}, nothing to branch from")
            sys.exit(0)
        source_parts = source_tag.lstrip("v").split(".")
        branch_name = f"{source_parts[0]}.{source_parts[1]}"
    else:
        # Minor bump (e.g. v2.51.0) — create a branch for the previous minor
        prev_minor = minor - 1
        source_tag = find_latest_tag_for_minor(refs, major, prev_minor)
        if source_tag is None:
            print(f"No tags found for v{major}.{prev_minor}.*, nothing to branch from")
            sys.exit(0)
        branch_name = f"{major}.{prev_minor}"

    print(f"New release: v{new_tag}")
    print(f"Source tag:  {source_tag}")
    print(f"Branch name: {branch_name}")

    if branch_exists(repo, branch_name):
        print(f"Branch {branch_name} already exists, skipping")
        sys.exit(0)

    sha = get_commit_sha_for_tag(repo, source_tag)
    print(f"Commit SHA:  {sha}")

    create_branch(repo, branch_name, sha)
    print(f"Created branch {branch_name} at {sha}")


if __name__ == "__main__":
    main()

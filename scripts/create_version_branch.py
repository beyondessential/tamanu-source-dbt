#!/usr/bin/env python3
"""Create a maintenance branch for the previous minor version when a new minor release is published.

When v2.51.0 is released, creates a '2.50' branch pointing to the latest v2.50.* tag.

Usage:
    NEW_TAG=v2.51.0 REPO=beyondessential/tamanu-source-dbt python scripts/create_version_branch.py
    python scripts/create_version_branch.py v2.51.0

Requires GH_TOKEN with contents:write on this repo.
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
    input_json = json.dumps(data) if data is not None else None
    if data is not None:
        cmd += ["--input", "-"]

    result = subprocess.run(cmd, capture_output=True, text=True, input=input_json, check=False)

    if result.returncode != 0:
        if "404" in result.stderr or "Not Found" in result.stderr:
            return None
        raise RuntimeError(f"gh api {path} failed:\n{result.stderr.strip()}")

    return json.loads(result.stdout) if result.stdout.strip() else {}


def find_latest_tag_for_minor(refs: list[dict], major: int, minor: int) -> str | None:
    """Given a list of git ref objects, return the latest vX.Y.Z tag for the given major.minor.

    Sorts by patch number numerically (not lexicographically) so v2.49.10 > v2.49.9.
    """
    prefix = f"refs/tags/v{major}.{minor}."
    matching = [
        r["ref"].removeprefix("refs/tags/")
        for r in refs
        if r["ref"].startswith(prefix)
    ]
    if not matching:
        return None

    def patch_num(tag: str) -> int:
        try:
            return int(tag.split(".")[-1])
        except ValueError:
            return -1

    matching.sort(key=patch_num)
    return matching[-1]


def get_commit_sha_for_tag(repo: str, tag: str) -> str:
    """Return the commit SHA for a tag, dereferencing annotated tags."""
    ref_info = gh_api(f"repos/{repo}/git/ref/tags/{tag}")
    if ref_info is None:
        raise ValueError(f"Tag '{tag}' not found in {repo}")

    sha = ref_info["object"]["sha"]
    if ref_info["object"]["type"] == "tag":
        tag_obj = gh_api(f"repos/{repo}/git/tags/{sha}")
        sha = tag_obj["object"]["sha"]
    return sha


def branch_exists(repo: str, branch: str) -> bool:
    return gh_api(f"repos/{repo}/git/ref/heads/{branch}") is not None


def main():
    new_tag = os.environ.get("NEW_TAG") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not new_tag:
        print("Error: provide NEW_TAG env var or pass tag as argument", file=sys.stderr)
        sys.exit(1)

    repo = os.environ.get("REPO") or os.environ.get("GITHUB_REPOSITORY")
    if not repo:
        print("Error: provide REPO env var (e.g. org/repo)", file=sys.stderr)
        sys.exit(1)

    if not new_tag.startswith("v"):
        new_tag = f"v{new_tag}"

    m = re.match(r"^v(\d+)\.(\d+)\.0$", new_tag)
    if not m:
        print(f"Not a minor release ({new_tag}), skipping")
        sys.exit(0)

    major = int(m.group(1))
    minor = int(m.group(2))
    prev_minor = minor - 1
    branch_name = f"{major}.{prev_minor}"

    print(f"Release {new_tag}: creating maintenance branch '{branch_name}'")

    if branch_exists(repo, branch_name):
        print(f"Branch '{branch_name}' already exists, skipping")
        sys.exit(0)

    all_refs = gh_api(f"repos/{repo}/git/refs/tags") or []
    latest_tag = find_latest_tag_for_minor(all_refs, major, prev_minor)
    if not latest_tag:
        print(f"No tags found for v{major}.{prev_minor}.*, skipping")
        sys.exit(0)

    print(f"Latest tag for v{major}.{prev_minor}: {latest_tag}")

    sha = get_commit_sha_for_tag(repo, latest_tag)

    gh_api(f"repos/{repo}/git/refs", method="POST", data={
        "ref": f"refs/heads/{branch_name}",
        "sha": sha,
    })

    print(f"✅ Created branch '{branch_name}' at {latest_tag} ({sha})")


if __name__ == "__main__":
    main()

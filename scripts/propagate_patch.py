#!/usr/bin/env python3
"""Propagate a new patch release of tamanu-source-dbt to deployment repos
that are pinned to the same major.minor version.

Usage:
    NEW_TAG=v2.50.2 python scripts/propagate_patch.py
    python scripts/propagate_patch.py v2.50.2

Requires:
    - GH_TOKEN env var with repo write access to all deployment repos
    - gh CLI installed and authenticated
"""

import base64
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml


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


def get_major_minor(version: str) -> str:
    v = version.lstrip("v")
    parts = v.split(".")
    if len(parts) < 2:
        raise ValueError(f"Cannot parse major.minor from version: {version}")
    return f"{parts[0]}.{parts[1]}"


def get_packages_yml(repo: str, ref: str = None) -> tuple[str, str]:
    """Returns (decoded_content, sha)."""
    path = f"repos/{repo}/contents/packages.yml"
    if ref:
        path += f"?ref={ref}"
    info = gh_api(path)
    content = base64.b64decode(info["content"]).decode("utf-8")
    return content, info["sha"]


def find_revision(packages_content: str) -> str | None:
    data = yaml.safe_load(packages_content)
    for pkg in data.get("packages", []):
        if "tamanu-source-dbt" in pkg.get("git", ""):
            return pkg.get("revision")
    return None


def replace_revision(packages_content: str, new_revision: str) -> str:
    """Replace the revision value, preserving surrounding quote style."""
    return re.sub(
        r"(revision:\s*)([\"']?)(v[\d.]+)([\"']?)",
        lambda m: m.group(1) + m.group(2) + new_revision + m.group(4),
        packages_content,
    )


def branch_exists(repo: str, branch: str) -> bool:
    try:
        gh_api(f"repos/{repo}/git/ref/heads/{branch}")
        return True
    except RuntimeError:
        return False


def propagate(repo: str, new_tag: str, new_major_minor: str) -> None:
    print(f"\n{'='*60}")
    print(f"Checking {repo}...")

    content, _ = get_packages_yml(repo)
    current_revision = find_revision(content)

    if not current_revision:
        print("  ⏭️  No tamanu-source-dbt package found, skipping")
        return

    try:
        current_major_minor = get_major_minor(current_revision)
    except ValueError:
        print(f"  ⏭️  Cannot parse version from '{current_revision}', skipping")
        return

    if current_major_minor != new_major_minor:
        print(
            f"  ⏭️  Pinned to {current_revision} ({current_major_minor}),"
            f" target major.minor is {new_major_minor} — skipping"
        )
        return

    if current_revision == new_tag:
        print(f"  ✅ Already on {new_tag}, skipping")
        return

    print(f"  🔄 Bumping {current_revision} → {new_tag}")

    branch = f"chore/bump-tamanu-source-dbt-{new_tag}"

    # Get default branch head SHA
    repo_info = gh_api(f"repos/{repo}")
    default_branch = repo_info["default_branch"]
    ref_info = gh_api(f"repos/{repo}/git/ref/heads/{default_branch}")
    head_sha = ref_info["object"]["sha"]

    # Create or reset branch
    if branch_exists(repo, branch):
        gh_api(
            f"repos/{repo}/git/refs/heads/{branch}",
            method="PATCH",
            data={"sha": head_sha, "force": True},
        )
        print(f"  ♻️  Reset existing branch {branch}")
    else:
        gh_api(
            f"repos/{repo}/git/refs",
            method="POST",
            data={"ref": f"refs/heads/{branch}", "sha": head_sha},
        )
        print(f"  🌿 Created branch {branch}")

    # Get file SHA on the new branch (may differ from default branch if branch was reset)
    _, file_sha = get_packages_yml(repo, ref=branch)

    # Commit updated packages.yml
    updated_content = replace_revision(content, new_tag)
    updated_b64 = base64.b64encode(updated_content.encode()).decode()
    gh_api(
        f"repos/{repo}/contents/packages.yml",
        method="PUT",
        data={
            "message": f"chore: bump tamanu-source-dbt to {new_tag}",
            "content": updated_b64,
            "sha": file_sha,
            "branch": branch,
        },
    )
    print("  📝 Committed packages.yml update")

    # Check for existing open PR on this branch
    org = repo.split("/")[0]
    prs = gh_api(f"repos/{repo}/pulls?head={org}:{branch}&state=open")
    if prs:
        print(f"  PR already open: {prs[0]['html_url']}")
        return

    # Open PR
    pr = gh_api(
        f"repos/{repo}/pulls",
        method="POST",
        data={
            "title": f"chore: bump tamanu-source-dbt to {new_tag}",
            "body": (
                f"## Summary\n\n"
                f"Bumps `tamanu-source-dbt` from `{current_revision}` to `{new_tag}`.\n\n"
                f"This is a patch update within the `{current_major_minor}` minor version"
                f" — no schema changes are expected.\n\n"
                f"---\n"
                f"🤖 _Automated by the "
                f"[patch propagation workflow]"
                f"(https://github.com/beyondessential/tamanu-source-dbt/actions)_"
            ),
            "head": branch,
            "base": default_branch,
        },
    )
    print(f"  ✅ PR created: {pr['html_url']}")


def main():
    new_tag = os.environ.get("NEW_TAG") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not new_tag:
        print("Error: provide NEW_TAG env var or pass tag as argument", file=sys.stderr)
        sys.exit(1)

    if not new_tag.startswith("v"):
        new_tag = f"v{new_tag}"

    try:
        new_major_minor = get_major_minor(new_tag)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"🚀 Propagating {new_tag} (major.minor: {new_major_minor}) to deployment repos...")

    config_path = Path(__file__).parent.parent / ".github" / "deployment-repos.yml"
    with open(config_path) as f:
        config = yaml.safe_load(f)

    repos = config.get("repos", [])
    if not repos:
        print("No repos configured in .github/deployment-repos.yml")
        return

    errors = []
    for repo in repos:
        try:
            propagate(repo, new_tag, new_major_minor)
        except Exception as e:
            print(f"  ❌ Error: {e}")
            errors.append(repo)

    print(f"\n{'='*60}")
    if errors:
        print(f"❌ Failed for: {', '.join(errors)}")
        sys.exit(1)
    else:
        print("✅ Done")


if __name__ == "__main__":
    main()

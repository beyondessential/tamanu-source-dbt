#!/usr/bin/env python3
"""Propagate a new patch release of tamanu-source-dbt to deployment repos
pinned to the same major.minor version.

Usage:
    NEW_TAG=v2.50.2 python scripts/propagate_patch.py
    python scripts/propagate_patch.py v2.50.2

Requires GH_TOKEN with repo write access to all repos in .github/deployment-repos.yml.
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


def get_file(repo: str, filepath: str, ref: str = None) -> tuple[str, str]:
    """Returns (decoded_content, sha)."""
    path = f"repos/{repo}/contents/{filepath}"
    if ref:
        path += f"?ref={ref}"
    info = gh_api(path)
    return base64.b64decode(info["content"]).decode("utf-8"), info["sha"]


def get_packages_yml(repo: str, ref: str = None) -> tuple[str, str]:
    return get_file(repo, "packages.yml", ref)


def bump_patch(version: str) -> str:
    """Increment the patch component of a version string (e.g. '2.50.1' -> '2.50.2')."""
    v = version.strip("\"'").lstrip("v")
    parts = v.split(".")
    if len(parts) < 3:
        raise ValueError(f"Cannot parse patch from version: {version}")
    parts[2] = str(int(parts[2]) + 1)
    return "v" + ".".join(parts)


def find_revision(packages_content: str) -> str | None:
    data = yaml.safe_load(packages_content)
    for pkg in data.get("packages", []):
        if "tamanu-source-dbt" in pkg.get("git", ""):
            return pkg.get("revision")
    return None


def replace_revision(packages_content: str, new_revision: str) -> str:
    """Replace the revision for the tamanu-source-dbt package only.

    Parses YAML to find the current revision value, then substitutes it
    in-place to preserve the original file formatting and quote style.
    """
    old_revision = find_revision(packages_content)
    if not old_revision:
        return packages_content
    return re.sub(
        r"(revision:\s*)([\"']?)" + re.escape(str(old_revision)) + r"([\"']?)",
        lambda m: m.group(1) + m.group(2) + new_revision + m.group(3),
        packages_content,
        count=1,
    )


def branch_exists(repo: str, branch: str) -> bool:
    try:
        gh_api(f"repos/{repo}/git/ref/heads/{branch}")
        return True
    except RuntimeError as e:
        if "404" in str(e):
            return False
        raise


def propagate(repo: str, new_tag: str, new_major_minor: str) -> None:
    print(f"\n{repo}")

    default_content, _ = get_packages_yml(repo)
    current_revision = find_revision(default_content)

    if not current_revision:
        print("  ⏭️  no tamanu-source-dbt package, skipping")
        return

    try:
        current_major_minor = get_major_minor(current_revision)
    except ValueError:
        print(f"  ⏭️  unrecognised revision '{current_revision}', skipping")
        return

    if current_major_minor != new_major_minor:
        print(f"  ⏭️  on {current_revision}, skipping")
        return

    if current_revision == new_tag:
        print(f"  ✅ already on {new_tag}")
        return

    branch = f"chore/bump-tamanu-source-dbt-{new_tag}"

    org = repo.split("/")[0]
    prs = gh_api(f"repos/{repo}/pulls?head={org}:{branch}&state=open")
    if prs:
        print(f"  ⏭️  PR already open: {prs[0]['html_url']}")
        return

    repo_info = gh_api(f"repos/{repo}")
    default_branch = repo_info["default_branch"]
    head_sha = gh_api(f"repos/{repo}/git/ref/heads/{default_branch}")["object"]["sha"]

    if branch_exists(repo, branch):
        branch_content, file_sha = get_packages_yml(repo, ref=branch)
        print("  ♻️  reusing existing branch")
    else:
        gh_api(f"repos/{repo}/git/refs", method="POST",
               data={"ref": f"refs/heads/{branch}", "sha": head_sha})
        branch_content, file_sha = default_content, get_packages_yml(repo, ref=branch)[1]

    updated_content = replace_revision(branch_content, new_tag)
    if updated_content == branch_content:
        raise RuntimeError(
            "replace_revision made no change — revision may be a branch name, "
            "commit SHA, or revision: appears before git: in the entry"
        )

    gh_api(f"repos/{repo}/contents/packages.yml", method="PUT", data={
        "message": f"chore: bump tamanu-source-dbt to {new_tag}",
        "content": base64.b64encode(updated_content.encode()).decode(),
        "sha": file_sha,
        "branch": branch,
    })

    try:
        dbt_proj_content, dbt_proj_sha = get_file(repo, "dbt_project.yml", ref=branch)
    except RuntimeError as e:
        if "404" not in str(e):
            raise
    else:
        m = re.search(r"^version:\s*(\S+)", dbt_proj_content, flags=re.MULTILINE)
        if m:
            current_proj_version = m.group(1)
            new_proj_version = bump_patch(current_proj_version)
            updated_dbt_proj = (
                dbt_proj_content[: m.start(1)] + new_proj_version.lstrip("v") + dbt_proj_content[m.end(1) :]
            )
            gh_api(f"repos/{repo}/contents/dbt_project.yml", method="PUT", data={
                "message": f"chore: bump version to {new_proj_version}",
                "content": base64.b64encode(updated_dbt_proj.encode()).decode(),
                "sha": dbt_proj_sha,
                "branch": branch,
            })

    pr = gh_api(f"repos/{repo}/pulls", method="POST", data={
        "title": f"chore: bump tamanu-source-dbt to {new_tag}",
        "body": (
            f"Bumps `tamanu-source-dbt` from `{current_revision}` to `{new_tag}`."
            f" Patch update within `{current_major_minor}` — no schema changes expected.\n\n"
            f"---\n"
            f"🤖 _[patch propagation workflow](https://github.com/beyondessential/tamanu-source-dbt/actions)_"
        ),
        "head": branch,
        "base": default_branch,
    })
    print(f"  ✅ PR: {pr['html_url']}")


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

    print(f"Propagating {new_tag} ({new_major_minor}) to deployment repos...")

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
            print(f"  ❌ {e}")
            errors.append(repo)

    if errors:
        print(f"\nFailed: {', '.join(errors)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

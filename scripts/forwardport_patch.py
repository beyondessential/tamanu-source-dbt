#!/usr/bin/env python3
"""Forward-port a patch release to higher-minor branches within tamanu-source-dbt.

When a patch is released for an older minor version (e.g. v2.49.9), this script:
  1. Identifies all branches for higher minor versions (e.g. '2.50', 'main').
  2. Cherry-picks the patch commits onto each target branch.
  3. Bumps the version in dbt_project.yml and pyproject.toml.
  4. Opens a PR for each target branch.

Usage:
    NEW_TAG=v2.49.9 python scripts/forwardport_patch.py
    python scripts/forwardport_patch.py v2.49.9

Requires:
  - GH_TOKEN with contents:write and pull-requests:write on this repo.
  - Full git history (use fetch-depth: 0 in GHA checkout).
"""

import os
import re
import subprocess
import sys
from pathlib import Path

VERSION_FILES = ["dbt_project.yml", "pyproject.toml"]


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------


def git(*args, check=True) -> subprocess.CompletedProcess:
    return subprocess.run(["git"] + list(args), capture_output=True, text=True, check=check)


def git_out(*args) -> str:
    return git(*args).stdout.strip()


def gh_out(*args, check=True) -> str:
    result = subprocess.run(["gh"] + list(args), capture_output=True, text=True, check=check)
    if check and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout.strip()


# ---------------------------------------------------------------------------
# Version helpers
# ---------------------------------------------------------------------------


def get_major_minor_patch(version: str) -> tuple[int, int, int]:
    """Parse a version string into (major, minor, patch) integers."""
    v = version.lstrip("v").strip("\"'")
    parts = v.split(".")
    if len(parts) < 3:
        raise ValueError(f"Cannot parse version: {version!r}")
    try:
        return int(parts[0]), int(parts[1]), int(parts[2])
    except ValueError:
        raise ValueError(f"Non-numeric version component in: {version!r}")


def update_version_in_files(new_version: str) -> list[str]:
    """Set version to new_version in dbt_project.yml and pyproject.toml.

    Returns list of files actually modified.
    """
    changed = []
    for filepath in VERSION_FILES:
        path = Path(filepath)
        if not path.exists():
            continue
        original = path.read_text()
        updated = original
        # dbt_project.yml:  version: 2.50.4
        updated = re.sub(
            r"^(version:\s*)\d+\.\d+\.\d+",
            lambda m: m.group(1) + new_version,
            updated,
            flags=re.MULTILINE,
        )
        # pyproject.toml:  version = "2.50.4"
        updated = re.sub(
            r'^(version\s*=\s*")\d+\.\d+\.\d+(")',
            lambda m: m.group(1) + new_version + m.group(2),
            updated,
            flags=re.MULTILINE,
        )
        if updated != original:
            path.write_text(updated)
            changed.append(filepath)
    return changed


# ---------------------------------------------------------------------------
# Tag helpers
# ---------------------------------------------------------------------------


def _sort_tags_by_patch(tags: list[str]) -> list[str]:
    def patch_num(tag: str) -> int:
        try:
            return int(tag.split(".")[-1])
        except ValueError:
            return -1

    return sorted(tags, key=patch_num)


def get_version_tags_for_minor_from_list(all_tags: list[str], major_minor: str) -> list[str]:
    """Return tags matching vX.Y.* from all_tags, sorted by patch number numerically."""
    prefix = f"v{major_minor}."
    matching = [t for t in all_tags if t.startswith(prefix)]
    return _sort_tags_by_patch(matching)


def get_version_tags_for_minor(major_minor: str) -> list[str]:
    """Return all vX.Y.Z tags for the given major.minor, sorted by patch number."""
    raw = git_out("tag", "-l", f"v{major_minor}.*")
    all_tags = [t for t in raw.splitlines() if t.strip()]
    return get_version_tags_for_minor_from_list(all_tags, major_minor)


def get_previous_tag(new_tag: str, tags: list[str]) -> str | None:
    """Return the tag immediately before new_tag in an already-sorted tag list."""
    vtag = new_tag if new_tag.startswith("v") else f"v{new_tag}"
    try:
        idx = tags.index(vtag)
        return tags[idx - 1] if idx > 0 else None
    except ValueError:
        return None


def get_patch_commits(prev_tag: str, new_tag: str) -> list[str]:
    """Return commit SHAs introduced in new_tag relative to prev_tag, oldest first."""
    raw = git_out("log", f"{prev_tag}..{new_tag}", "--no-merges", "--format=%H", "--reverse")
    return [c for c in raw.splitlines() if c.strip()]


# ---------------------------------------------------------------------------
# Branch helpers
# ---------------------------------------------------------------------------


def get_higher_minor_branches_from_list(branch_names: list[str], major: int, minor: int) -> list[str]:
    """Return branches matching 'major.Y' where Y > minor, sorted ascending by Y."""
    result = []
    for branch in branch_names:
        m = re.match(r"^(\d+)\.(\d+)$", branch)
        if m and int(m.group(1)) == major and int(m.group(2)) > minor:
            result.append((int(m.group(2)), branch))
    result.sort()
    return [b for _, b in result]


def get_higher_minor_branches(major: int, minor: int) -> list[str]:
    """Return all remote 'major.Y' branches where Y > minor, sorted ascending."""
    raw = git_out("branch", "-r", "--format=%(refname:short)")
    names = [re.sub(r"^origin/", "", line.strip()) for line in raw.splitlines()]
    return get_higher_minor_branches_from_list(names, major, minor)


def get_branch_version(branch: str) -> str | None:
    """Read the version field from dbt_project.yml on the given remote branch."""
    result = git("show", f"origin/{branch}:dbt_project.yml", check=False)
    if result.returncode != 0:
        return None
    m = re.search(r"^version:\s*(\S+)", result.stdout, re.MULTILINE)
    return m.group(1).strip() if m else None


# ---------------------------------------------------------------------------
# Forward-porting
# ---------------------------------------------------------------------------


def configure_git() -> None:
    git("config", "user.email", "github-actions[bot]@users.noreply.github.com")
    git("config", "user.name", "github-actions[bot]")


def forwardport_to_branch(
    target_branch: str,
    patch_commits: list[str],
    new_patch_tag: str,
    source_major_minor: str,
    repo: str,
) -> None:
    print(f"\n  Target: {target_branch}")

    pr_branch = f"chore/forwardport-{new_patch_tag}-to-{target_branch.replace('/', '-')}"

    # Skip if PR already open
    existing = gh_out(
        "pr", "list",
        "--repo", repo,
        "--head", pr_branch,
        "--state", "open",
        "--json", "url",
        check=False,
    )
    if existing and existing.strip() not in ("", "[]"):
        print(f"    ⏭️  PR already open for branch '{pr_branch}'")
        return

    # Fetch before reading version so we compute against the latest state
    git("fetch", "origin", target_branch)

    target_version = get_branch_version(target_branch)
    if not target_version:
        print(f"    ⏭️  Cannot read version from '{target_branch}', skipping")
        return

    tmaj, tmin, tpatch = get_major_minor_patch(target_version)
    new_target_version = f"{tmaj}.{tmin}.{tpatch + 1}"

    # Checkout PR branch from the target
    git("checkout", "-B", pr_branch, f"origin/{target_branch}")

    # Cherry-pick patch commits
    applied_commits = 0
    already_applied_commits = 0
    conflict_commit = None
    for commit in patch_commits:
        result = git("cherry-pick", commit, check=False)
        if result.returncode != 0:
            stderr = result.stderr + result.stdout
            if "nothing to commit" in stderr or "allow-empty" in stderr or "cherry-pick is now empty" in stderr:
                # Commit already applied on this branch — skip it
                git("cherry-pick", "--skip", check=False)
                print(f"    ℹ️  Skipped already-applied commit {commit[:8]}")
                already_applied_commits += 1
                continue
            # Real conflict — abort and open a draft PR with what we have so far
            git("cherry-pick", "--abort", check=False)
            conflict_commit = commit
            print(f"    ⚠️  Cherry-pick conflict at {commit[:8]}, will open draft PR")
            break
        applied_commits += 1
    applicable_commits = len(patch_commits) - already_applied_commits

    # Override version to the correct next patch for this branch
    changed = update_version_in_files(new_target_version)
    if changed:
        git("add", *changed)
        result = git("diff", "--cached", "--name-only", check=False)
        if result.stdout.strip():
            git("commit", "-m", f"chore: bump version to {new_target_version}")

    # Skip if nothing was actually committed
    ahead = git_out("rev-list", "--count", f"origin/{target_branch}..HEAD")
    if int(ahead) == 0:
        if conflict_commit:
            print(f"    ⏭️  Conflict on first commit {conflict_commit[:8]} — nothing to push, skipping")
        else:
            print(f"    ⏭️  No changes to forward-port to '{target_branch}', skipping")
        git("checkout", "-")
        return

    # Push
    git("push", "origin", pr_branch, "--force-with-lease")

    # Build PR title and body
    if conflict_commit:
        title = f"chore: forwardport {new_patch_tag} to {target_branch} (→ {new_target_version}) [CONFLICT]"
        remaining_commits = patch_commits[patch_commits.index(conflict_commit) + 1:]
        remaining_step = (
            f"3. Cherry-pick the remaining commit(s):\n"
            + "".join(f"   - `git cherry-pick {sha}`\n" for sha in remaining_commits)
        ) if remaining_commits else ""
        body = (
            f"Forward-ports patch `{new_patch_tag}` (from `{source_major_minor}`) to `{target_branch}`.\n\n"
            f"⚠️ **Cherry-pick conflict on `{conflict_commit[:8]}`** — manual resolution required before merging.\n\n"
            f"The following commit(s) were not applied. To complete the forward-port:\n"
            f"1. Check out this branch\n"
            f"2. `git cherry-pick {conflict_commit}` — resolve the conflict, then `git add <files> && git cherry-pick --continue`\n"
            + remaining_step + "\n"
            f"- Bumps version `{target_version}` → `{new_target_version}`\n"
            f"- Cherry-picked {applied_commits} of {applicable_commits} commit(s) from `{new_patch_tag}` (stopped at conflict on `{conflict_commit[:8]}`)\n\n"
            f"---\n"
            f"🤖 _[forwardport patch workflow](https://github.com/{repo}/actions)_"
        )
        draft_args = ["--draft"]
    else:
        title = f"chore: forwardport {new_patch_tag} to {target_branch} (→ {new_target_version})"
        body = (
            f"Forward-ports patch `{new_patch_tag}` (from `{source_major_minor}`) to `{target_branch}`.\n\n"
            f"- Bumps version `{target_version}` → `{new_target_version}`\n"
            f"- Cherry-picks {applied_commits} commit(s) from `{new_patch_tag}`\n\n"
            f"---\n"
            f"🤖 _[forwardport patch workflow](https://github.com/{repo}/actions)_"
        )
        draft_args = []

    # Create PR
    pr_url = gh_out(
        "pr", "create",
        "--repo", repo,
        "--title", title,
        "--body", body,
        "--head", pr_branch,
        "--base", target_branch,
        *draft_args,
    )
    print(f"    {'⚠️  Draft' if conflict_commit else '✅'} PR: {pr_url}")

    # Return to detached HEAD / previous branch
    git("checkout", "-")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main():
    new_tag = os.environ.get("NEW_TAG") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not new_tag:
        print("Error: provide NEW_TAG env var or pass tag as argument", file=sys.stderr)
        sys.exit(1)

    repo = os.environ.get("REPO") or os.environ.get("GITHUB_REPOSITORY")
    if not repo:
        print("Error: provide REPO or GITHUB_REPOSITORY env var", file=sys.stderr)
        sys.exit(1)

    if not new_tag.startswith("v"):
        new_tag = f"v{new_tag}"

    try:
        major, minor, patch = get_major_minor_patch(new_tag)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if patch == 0:
        print(f"{new_tag} is a minor release — forward-porting not needed")
        sys.exit(0)

    major_minor = f"{major}.{minor}"

    # Determine current minor from main
    main_version = get_branch_version("main")
    if not main_version:
        print("Error: cannot read version from main branch", file=sys.stderr)
        sys.exit(1)

    mmaj, mmin, _ = get_major_minor_patch(main_version)

    if (major, minor) >= (mmaj, mmin):
        print(
            f"{new_tag} is at or above the current minor ({mmaj}.{mmin} on main) — nothing to forward-port"
        )
        sys.exit(0)

    print(f"Forward-porting {new_tag} ({major_minor}) to branches above minor {minor}...")
    print(f"Current minor on main: {mmaj}.{mmin} ({main_version})")

    # Find previous tag to determine commit range
    sorted_tags = get_version_tags_for_minor(major_minor)
    prev_tag = get_previous_tag(new_tag, sorted_tags)
    if not prev_tag:
        print(f"Error: no previous tag found for {new_tag} in {major_minor}.*", file=sys.stderr)
        sys.exit(1)

    patch_commits = get_patch_commits(prev_tag, new_tag)
    if not patch_commits:
        print(f"No commits found between {prev_tag} and {new_tag} — nothing to forward-port")
        sys.exit(0)

    print(f"Commits to cherry-pick ({prev_tag}..{new_tag}): {len(patch_commits)}")

    # Collect target branches: all major.Y (Y > minor) + main
    target_branches = get_higher_minor_branches(major, minor)
    if not target_branches:
        print("No higher-minor branches found — only forward-porting to main")
    target_branches.append("main")

    print(f"Target branches: {', '.join(target_branches)}")

    configure_git()

    errors = []
    for branch in target_branches:
        try:
            forwardport_to_branch(branch, patch_commits, new_tag, major_minor, repo)
        except Exception as e:
            print(f"    ❌ {e}")
            errors.append(branch)

    if errors:
        print(f"\nFailed for: {', '.join(errors)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

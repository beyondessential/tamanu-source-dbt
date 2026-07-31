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

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

VERSION_FILES = ["dbt_project.yml", "pyproject.toml"]


@dataclass
class Change:
    """The substantive change being forward-ported, for PR titling/attribution.

    `commit`/`subject` describe the primary (first non-version-bump) commit;
    `extra` counts any additional substantive commits so the title can note
    them; `author_login` is the original author's GitHub handle (used to request
    their review). All fields optional — a release with only a version bump
    leaves them empty and the caller falls back to a generic title.
    """

    subject: str | None = None
    commit: str | None = None
    extra: int = 0
    author_login: str | None = None


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------


def git(*args, check=True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git"] + list(args), capture_output=True, text=True, check=check
    )


def git_out(*args) -> str:
    return git(*args).stdout.strip()


def gh_out(*args, check=True) -> str:
    result = subprocess.run(
        ["gh"] + list(args), capture_output=True, text=True, check=check
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout.strip()


def get_commit_author_login(repo: str, commit: str) -> str | None:
    """Return the GitHub login of a commit's author, or None if unresolvable.

    Uses the commits API, which maps a commit to its GitHub account (the git
    author email alone can't do this — releases are often authored by bots or
    noreply addresses). Best-effort: any failure yields None.
    """
    out = gh_out(
        "api", f"repos/{repo}/commits/{commit}", "--jq", ".author.login", check=False
    )
    login = out.strip()
    return login if login and login != "null" else None


def request_review(pr_ref: str, change: Change | None) -> None:
    """Request the original author's review on the PR (best-effort).

    Runs after the PR exists so a non-collaborator author (or a bot) never
    blocks PR creation — failures are ignored.
    """
    if change and change.author_login:
        gh_out("pr", "edit", pr_ref, "--add-reviewer", change.author_login, check=False)


def build_pr_title(
    change: Change | None,
    new_patch_tag: str,
    new_target_version: str,
    target_branch: str,
    conflict: bool = False,
) -> str:
    """Title a forward-port PR after the change, annotated with the version span.

    Falls back to generic wording (built from the same version span) when no
    substantive commit was identified. Appends a [CONFLICT] marker when the
    cherry-pick needs manual resolution.
    """
    version_span = f"forwardport {new_patch_tag} → {new_target_version}"
    if change and change.subject:
        subject_part = change.subject + (
            f" (+{change.extra} more)" if change.extra else ""
        )
        title = f"{subject_part} ({version_span})"
    else:
        title = f"chore: {version_span} (onto {target_branch})"
    return f"{title} [CONFLICT]" if conflict else title


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


def get_version_tags_for_minor_from_list(
    all_tags: list[str], major_minor: str
) -> list[str]:
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
    raw = git_out(
        "log", f"{prev_tag}..{new_tag}", "--no-merges", "--format=%H", "--reverse"
    )
    return [c for c in raw.splitlines() if c.strip()]


def get_commit_subject(commit: str) -> str:
    """Return the first line (subject) of a commit's message."""
    return git_out("show", "-s", "--format=%s", commit)


VERSION_LINE_RE = re.compile(
    # dbt_project.yml: version: 2.50.4 or version: "2.50.4" (quotes optional in yaml)
    # pyproject.toml: version = "2.50.4" (toml strings are always quoted)
    r'^[+-](\s*version:\s*"?\d+\.\d+\.\d+"?\s*|\s*version\s*=\s*"\d+\.\d+\.\d+"\s*)$'
)


def is_version_only_diff(commit: str, filepath: str) -> bool:
    """True if commit's diff for filepath touches only the version line."""
    diff = git_out("show", commit, "--", filepath)
    changed = [
        line
        for line in diff.splitlines()
        if line[:1] in ("+", "-") and not line.startswith(("+++", "---"))
    ]
    return bool(changed) and all(VERSION_LINE_RE.match(line) for line in changed)


def is_version_bump_commit(commit: str) -> bool:
    """True if a commit touches nothing but version lines in VERSION_FILES.

    Used to skip pure `chore: bump version` commits when choosing which commit
    subject best describes the change being forward-ported.
    """
    raw = git_out("show", "--name-only", "--format=", commit)
    files = [f for f in raw.splitlines() if f.strip()]
    if not files or any(f not in VERSION_FILES for f in files):
        return False
    return all(is_version_only_diff(commit, f) for f in files)


def get_change_commits(patch_commits: list[str]) -> list[str]:
    """Return the substantive (non version-bump) commits being forward-ported.

    A patch release usually bundles the actual fix(es) plus a `chore: bump
    version` commit. The version bumps are noise for describing the change, so
    drop them. The first entry is the best single descriptor for a PR title; the
    count tells the caller whether to note additional commits.
    """
    return [c for c in patch_commits if not is_version_bump_commit(c)]


def get_unmerged_files() -> list[str]:
    raw = git_out("diff", "--name-only", "--diff-filter=U")
    return [f for f in raw.splitlines() if f.strip()]


def try_autoresolve_version_conflict(commit: str) -> bool:
    """Auto-resolve a cherry-pick conflict that is purely a version-line clash.

    dbt_project.yml/pyproject.toml always conflict when cherry-picking a version
    bump onto a branch already at a different version — the forward-port re-bumps
    both files to the correct target version afterward regardless, so the incoming
    change is always going to be overwritten. If every unmerged file is one of
    VERSION_FILES and the commit's diff for it is only the version line, keep the
    target branch's current content (git's "ours") and continue the cherry-pick.
    Anything broader (other unmerged files, or extra changes bundled into a
    version-file diff) is left for a human to resolve.
    """
    unmerged = get_unmerged_files()
    if not unmerged or any(f not in VERSION_FILES for f in unmerged):
        return False
    if not all(is_version_only_diff(commit, f) for f in unmerged):
        return False
    for f in unmerged:
        git("checkout", "--ours", f)
        git("add", f)
    result = git("-c", "core.editor=true", "cherry-pick", "--continue", check=False)
    if result.returncode == 0:
        return True
    # Keeping "ours" for every changed file can leave nothing to commit (e.g. a
    # pure version-bump commit with no other content) — the version re-bump right
    # after the cherry-pick loop covers this anyway, so treat it as resolved.
    if "cherry-pick is now empty" in result.stdout + result.stderr:
        skip_result = git("cherry-pick", "--skip", check=False)
        return skip_result.returncode == 0
    return False


COMPILED_DIR = "compiled/"


def strip_compiled_output_from_head() -> str:
    """Drop any compiled/ changes the current HEAD commit carries, amending it.

    compiled/ is version-stamped build output regenerated per release (e.g.
    compiled/v2.54.17/...); forward-porting another branch's compiled artifacts
    onto a different version line is never meaningful, so any compiled/ changes a
    cherry-picked commit carries are dropped, keeping the rest of the commit intact.

    Returns "stripped" if the commit still has other changes and was amended,
    "dropped" if removing compiled/ left it empty and it was undone entirely, or
    "" if the commit didn't touch compiled/ at all.
    """
    diff = git_out("diff", "--name-status", "HEAD~1", "HEAD", "--", COMPILED_DIR)
    lines = [line for line in diff.splitlines() if line.strip()]
    if not lines:
        return ""
    for line in lines:
        status, path = line.split("\t", 1)
        if status.startswith("A"):
            git("rm", "-f", "--", path)
        else:
            git("checkout", "HEAD~1", "--", path)
    remaining = git_out("diff", "--cached", "--name-only", "HEAD~1")
    if remaining.strip():
        git("commit", "--amend", "--no-edit")
        return "stripped"
    git("reset", "--hard", "HEAD~1")
    return "dropped"


# ---------------------------------------------------------------------------
# Branch helpers
# ---------------------------------------------------------------------------


def get_higher_minor_branches_from_list(
    branch_names: list[str], major: int, minor: int
) -> list[str]:
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


def get_target_major_minor(target_branch: str) -> tuple[int, int] | None:
    """Determine the major.minor line a target branch releases on.

    Maintenance branches are named 'X.Y' so the minor is in the branch name.
    'main' (or any other named branch) has no version in its name, so read it
    from the branch's dbt_project.yml.
    """
    m = re.match(r"^(\d+)\.(\d+)$", target_branch)
    if m:
        return int(m.group(1)), int(m.group(2))
    version = get_branch_version(target_branch)
    if not version:
        return None
    maj, minor, _ = get_major_minor_patch(version)
    return maj, minor


def compute_next_version(target_branch: str) -> tuple[str | None, str | None]:
    """Return (from_version, new_version) for a target branch.

    The next patch is derived from what has actually been *released* — the
    highest existing vX.Y.* tag for the branch's minor — not from the version
    currently in the branch's dbt_project.yml. The codebase version can be ahead
    of the last release (a prior forward-port already bumped it but it hasn't
    shipped yet); bumping from the codebase would skip a patch number. When no
    release tag exists for the minor yet, fall back to the codebase version.
    """
    mm = get_target_major_minor(target_branch)
    if not mm:
        return None, None
    maj, minor = mm
    tags = get_version_tags_for_minor(f"{maj}.{minor}")
    if tags:
        from_version = tags[-1].lstrip("v")
        _, _, last_patch = get_major_minor_patch(tags[-1])
        return from_version, f"{maj}.{minor}.{last_patch + 1}"
    codebase = get_branch_version(target_branch)
    if not codebase:
        return None, None
    cmaj, cmin, cpatch = get_major_minor_patch(codebase)
    return codebase.lstrip("v").strip("\"'"), f"{cmaj}.{cmin}.{cpatch + 1}"


# ---------------------------------------------------------------------------
# Forward-porting
# ---------------------------------------------------------------------------


def configure_git() -> None:
    git("config", "user.email", "github-actions[bot]@users.noreply.github.com")
    git("config", "user.name", "github-actions[bot]")


def get_open_pr(repo: str, pr_branch: str) -> dict | None:
    """Return {url, isDraft} for an already-open PR on pr_branch, or None."""
    raw = gh_out(
        "pr",
        "list",
        "--repo",
        repo,
        "--head",
        pr_branch,
        "--state",
        "open",
        "--json",
        "url,isDraft",
        check=False,
    )
    try:
        data = json.loads(raw) if raw.strip() else []
    except json.JSONDecodeError:
        return None
    return data[0] if data else None


def forwardport_to_branch(
    target_branch: str,
    patch_commits: list[str],
    new_patch_tag: str,
    source_major_minor: str,
    repo: str,
    change: Change | None = None,
) -> None:
    print(f"\n  Target: {target_branch}")

    pr_branch = (
        f"chore/forwardport-{new_patch_tag}-to-{target_branch.replace('/', '-')}"
    )

    # Fetch before reading version so we compute against the latest state
    git("fetch", "origin", target_branch)

    # Bump from the latest *released* patch for this minor, not the version
    # currently in the codebase (which may already be ahead of the last release).
    from_version, new_target_version = compute_next_version(target_branch)
    if not new_target_version:
        print(f"    ⏭️  Cannot determine next version for '{target_branch}', skipping")
        return

    # If a PR is already open, don't re-run the port — a force-push could clobber
    # commits a human pushed. Leave draft (conflict) PRs entirely alone; for a
    # ready PR, just refresh the title so an improved format or a superseded
    # version bump doesn't leave it stale.
    existing_pr = get_open_pr(repo, pr_branch)
    if existing_pr:
        if existing_pr.get("isDraft"):
            print(
                f"    ⏭️  Draft PR already open for '{pr_branch}' — leaving for manual resolution"
            )
            return
        title = build_pr_title(change, new_patch_tag, new_target_version, target_branch)
        gh_out("pr", "edit", existing_pr["url"], "--title", title, check=False)
        request_review(existing_pr["url"], change)
        print(f"    🔄 Refreshed existing PR title: {existing_pr['url']}")
        return

    # Checkout PR branch from the target
    git("checkout", "-B", pr_branch, f"origin/{target_branch}")

    # Cherry-pick patch commits
    applied_commits = 0
    already_applied_commits = 0
    compiled_only_commits = 0
    conflict_commit = None
    conflict_index = None

    def _handle_compiled_output(commit: str) -> None:
        nonlocal compiled_only_commits
        outcome = strip_compiled_output_from_head()
        if outcome == "dropped":
            print(
                f"    🧹 {commit[:8]} was compiled-output-only — dropped, nothing to forward-port"
            )
            compiled_only_commits += 1
        elif outcome == "stripped":
            print(f"    🧹 Dropped compiled/ output from {commit[:8]}")

    for i, commit in enumerate(patch_commits):
        result = git("cherry-pick", commit, check=False)
        if result.returncode != 0:
            combined_output = result.stderr + result.stdout
            if (
                "nothing to commit" in combined_output
                or "allow-empty" in combined_output
                or "cherry-pick is now empty" in combined_output
            ):
                # Commit already applied on this branch — skip it
                git("cherry-pick", "--skip", check=False)
                print(f"    ℹ️  Skipped already-applied commit {commit[:8]}")
                already_applied_commits += 1
                continue
            if try_autoresolve_version_conflict(commit):
                # Version-line-only clash in dbt_project.yml/pyproject.toml — the
                # per-branch version bump below overwrites it correctly anyway.
                print(f"    🔧 Auto-resolved version-file conflict in {commit[:8]}")
                _handle_compiled_output(commit)
                applied_commits += 1
                continue
            # Real conflict — abort and open a draft PR with what we have so far
            git("cherry-pick", "--abort", check=False)
            conflict_commit = commit
            conflict_index = i
            print(f"    ⚠️  Cherry-pick conflict at {commit[:8]}, will open draft PR")
            break
        _handle_compiled_output(commit)
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
            print(
                f"    ⏭️  Conflict at {conflict_commit[:8]} with nothing committed ahead — skipping"
            )
        else:
            print(f"    ⏭️  No changes to forward-port to '{target_branch}', skipping")
        git("checkout", "-")
        return

    # Push
    git("push", "origin", pr_branch, "--force-with-lease")

    # Build PR title and body.
    title = build_pr_title(
        change,
        new_patch_tag,
        new_target_version,
        target_branch,
        conflict=bool(conflict_commit),
    )

    # Link back to the original change so reviewers can reach its context. A
    # `(#NNN)` in the subject auto-links to the source PR within the same repo.
    if change and change.commit:
        source_note = (
            f"- Source: [`{change.commit[:8]}`](https://github.com/{repo}/commit/{change.commit})"
            f" — {change.subject}\n"
        )
    else:
        source_note = ""

    if conflict_commit:
        remaining_commits = patch_commits[conflict_index + 1 :]
        remaining_step = (
            (
                "3. Cherry-pick the remaining commit(s) (skip any that git reports as empty with `git cherry-pick --skip`):\n"
                + "".join(
                    f"   - `git cherry-pick {sha}`\n" for sha in remaining_commits
                )
            )
            if remaining_commits
            else ""
        )
        body = (
            f"Forward-ports patch `{new_patch_tag}` (from `{source_major_minor}`) to `{target_branch}`.\n\n"
            f"{source_note}"
            f"⚠️ **Cherry-pick conflict on `{conflict_commit[:8]}`** — manual resolution required before merging.\n\n"
            f"To complete the forward-port:\n"
            f"1. Check out this branch\n"
            f"2. `git cherry-pick {conflict_commit}` — resolve the conflict, then `git add <files> && git cherry-pick --continue`\n"
            + remaining_step
            + "\n"
            f"- Bumps version `{from_version}` → `{new_target_version}`\n"
            f"- Cherry-picked {applied_commits} of {applicable_commits} commit(s) from `{new_patch_tag}` (stopped at conflict on `{conflict_commit[:8]}`)\n\n"
            f"---\n"
            f"🤖 _[forwardport patch workflow](https://github.com/{repo}/actions)_"
        )
        draft_args = ["--draft"]
    else:
        skip_reasons = []
        if already_applied_commits:
            skip_reasons.append(
                f"{already_applied_commits} already applied on this branch"
            )
        if compiled_only_commits:
            skip_reasons.append(f"{compiled_only_commits} were compiled-output-only")
        skipped_note = f" ({', '.join(skip_reasons)})" if skip_reasons else ""
        body = (
            f"Forward-ports patch `{new_patch_tag}` (from `{source_major_minor}`) to `{target_branch}`.\n\n"
            f"{source_note}"
            f"- Bumps version `{from_version}` → `{new_target_version}`\n"
            f"- Cherry-picks {applied_commits} commit(s) from `{new_patch_tag}`{skipped_note}\n\n"
            f"---\n"
            f"🤖 _[forwardport patch workflow](https://github.com/{repo}/actions)_"
        )
        draft_args = []

    # Create PR (the existing-PR case returned earlier).
    pr_url = gh_out(
        "pr",
        "create",
        "--repo",
        repo,
        "--title",
        title,
        "--body",
        body,
        "--head",
        pr_branch,
        "--base",
        target_branch,
        *draft_args,
    )
    print(f"    {'⚠️  Draft' if conflict_commit else '✅'} PR: {pr_url}")

    request_review(pr_url, change)

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

    print(
        f"Forward-porting {new_tag} ({major_minor}) to branches above minor {minor}..."
    )
    print(f"Current minor on main: {mmaj}.{mmin} ({main_version})")

    # Everything below relies on the full tag history. A shallow checkout (no
    # fetch-depth: 0 / fetch-tags: true) silently yields zero tags, which would
    # otherwise surface as a confusing "no previous tag" error.
    if not git_out("tag", "-l").strip():
        print(
            "Error: no git tags found — ensure the checkout used fetch-depth: 0 and fetch-tags: true",
            file=sys.stderr,
        )
        sys.exit(1)

    # Find previous tag to determine commit range
    sorted_tags = get_version_tags_for_minor(major_minor)
    prev_tag = get_previous_tag(new_tag, sorted_tags)
    if not prev_tag:
        print(
            f"Error: no previous tag found for {new_tag} in {major_minor}.*",
            file=sys.stderr,
        )
        sys.exit(1)

    patch_commits = get_patch_commits(prev_tag, new_tag)
    if not patch_commits:
        print(
            f"No commits found between {prev_tag} and {new_tag} — nothing to forward-port"
        )
        sys.exit(0)

    print(f"Commits to cherry-pick ({prev_tag}..{new_tag}): {len(patch_commits)}")

    # Describe the change so each PR is titled after it (not a generic label),
    # links back to its source commit, and requests the original author's review.
    change_commits = get_change_commits(patch_commits)
    change = Change()
    if change_commits:
        primary = change_commits[0]
        change = Change(
            subject=get_commit_subject(primary),
            commit=primary,
            extra=len(change_commits) - 1,
            author_login=get_commit_author_login(repo, primary),
        )
        print(
            f"Change: {change.subject}"
            + (f" (+{change.extra} more)" if change.extra else "")
        )

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
            forwardport_to_branch(
                branch, patch_commits, new_tag, major_minor, repo, change
            )
        except Exception as e:
            print(f"    ❌ {e}")
            errors.append(branch)

    if errors:
        print(f"\nFailed for: {', '.join(errors)}")
        sys.exit(1)


if __name__ == "__main__":
    main()

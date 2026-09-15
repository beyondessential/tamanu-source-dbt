"""CI guard: every BL-XXX code anchor must reference a real spec clause.

Runs the vendored scripts/check_spec_anchors.py logic under `pytest scripts/tests`
(the checks.yml gate), so a `-- BL-XXX:` / `# BL-XXX:` comment pointing at a clause
that does not exist in any spec fails CI. This is the code->spec pass (pass 1);
spec clauses with no code anchor stay advisory and are not asserted here.
"""

from pathlib import Path

from check_spec_anchors import collect_code_anchors, collect_spec_ids

REPO_ROOT = Path(__file__).resolve().parents[2]


def test_every_code_bl_anchor_resolves_to_a_spec_clause():
    spec_ids = collect_spec_ids(REPO_ROOT / "specs")
    anchors = collect_code_anchors(REPO_ROOT)

    dangling = {bl_id: sites for bl_id, sites in anchors.items() if bl_id not in spec_ids}

    assert not dangling, "BL anchors with no matching spec clause:\n" + "\n".join(
        f"  {bl_id}: {site.relative_to(REPO_ROOT)}:{lineno}"
        for bl_id, sites in sorted(dangling.items())
        for site, lineno in sites
    )

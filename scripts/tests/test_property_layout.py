"""Guards where `meta` and `tags` sit in property files.

dbt 2.0 reads a resource's or a column's `meta` and `tags` only from its `config:` block. dbt 1.x
also accepts them as top-level properties, without a deprecation warning, so `dbt parse` cannot
catch one placed there. Every model, seed, snapshot, source, source table and column keeps them
under `config:`.
"""

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
MOVED = ("meta", "tags")
RESOURCES = ("models", "seeds", "snapshots")


def _property_paths():
    project = yaml.safe_load((ROOT / "dbt_project.yml").read_text(encoding="utf-8"))
    for key in ("model-paths", "seed-paths", "snapshot-paths"):
        for folder in project.get(key, []):
            yield from sorted((ROOT / folder).rglob("*.yml"))


def _entries(document):
    """(label, mapping) for each resource, source table and column a property file declares."""
    for resource in RESOURCES:
        for node in document.get(resource) or []:
            yield f"{resource}: {node.get('name', '?')}", node
            for column in node.get("columns") or []:
                yield f"{resource}: {node.get('name', '?')}.{column.get('name', '?')}", column
    for source in document.get("sources") or []:
        yield f"sources: {source.get('name', '?')}", source
        for table in source.get("tables") or []:
            yield f"sources: {source.get('name', '?')}.{table.get('name', '?')}", table
            for column in table.get("columns") or []:
                yield f"sources: {source.get('name', '?')}.{table.get('name', '?')}.{column.get('name', '?')}", column


def test_property_files_are_found():
    assert any(True for _ in _property_paths()), "no property files under the model, seed or snapshot paths"


def test_meta_and_tags_sit_under_config():
    misplaced = [
        f"{path.relative_to(ROOT).as_posix()} -- {label}: {key}"
        for path in _property_paths()
        for label, entry in _entries(yaml.safe_load(path.read_text(encoding="utf-8")) or {})
        for key in MOVED
        if key in entry
    ]

    assert not misplaced, "`meta` / `tags` outside `config:` (move them under it):\n" + "\n".join(misplaced)

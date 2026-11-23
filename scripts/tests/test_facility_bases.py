"""Guards that the two facility bases document the same columns.

`facilities` and `sensitive_facilities` share one body, `facilities_base()`, so they always select
the same columns. Their property files cannot share a column list, so a column added to one file
and not the other is caught here.
"""

from pathlib import Path

import yaml

BASES = Path(__file__).resolve().parents[2] / "models" / "bases"


def _columns(model):
    document = yaml.safe_load((BASES / f"{model}.yml").read_text(encoding="utf-8"))
    (node,) = [n for n in document["models"] if n["name"] == model]
    return [
        (column["name"], column.get("data_type"), column.get("description"))
        for column in node.get("columns") or []
    ]


def test_facility_bases_document_the_same_columns():
    standard = _columns("facilities")
    sensitive = _columns("sensitive_facilities")

    assert standard, "facilities.yml lists no columns"
    assert standard == sensitive, (
        "facilities.yml and sensitive_facilities.yml must list the same columns, in the same "
        "order, with the same type and description"
    )

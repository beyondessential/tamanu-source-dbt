"""Print DDL for an empty copy of the Tamanu source schema.

Reads the table and column definitions in models/sources/ and models/logs/ and prints one
`create schema` per schema and one `create table` per source table, with the declared column
types and no rows. CI loads it into a disposable Postgres so `dbt run` can create every model
as a view on the lowest supported Postgres version (see
specs/testing/model-postgres-compatibility.md).

Usage:
    python scripts/generate_source_schema.py > schema.sql
"""

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRS = ("models/sources", "models/logs")

# information_schema reports these two types without the detail a column needs. The element
# type of an array and the labels of an enum are not declared, so text stands in for them.
TYPE_SUBSTITUTES = {"array": "text[]", "user-defined": "text"}
DEFAULT_TYPE = "text"


def _quote(identifier):
    return '"' + identifier.replace('"', '""') + '"'


def _column_type(column):
    declared = column.get("data_type") or DEFAULT_TYPE
    return TYPE_SUBSTITUTES.get(declared.lower(), declared)


def build_ddl(root=ROOT):
    """Return the DDL for every source table that declares columns."""
    # BL-001: one empty table per source table, with the declared column types.
    statements = []
    schemas = set()
    for directory in SOURCE_DIRS:
        for path in sorted((Path(root) / directory).glob("*.yml")):
            document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            for source in document.get("sources", []):
                schema = source.get("schema") or source["name"]
                for table in source.get("tables", []):
                    columns = table.get("columns") or []
                    # BL-002: a table with no declared columns has no shape to create.
                    if not columns:
                        continue
                    if schema not in schemas:
                        schemas.add(schema)
                        statements.append(f"create schema if not exists {_quote(schema)};")
                    definition = ", ".join(
                        f"{_quote(column['name'])} {_column_type(column)}" for column in columns
                    )
                    statements.append(
                        f"create table {_quote(schema)}.{_quote(table['name'])} ({definition});"
                    )
    return "\n".join(statements) + "\n"


if __name__ == "__main__":
    sys.stdout.write(build_ddl())

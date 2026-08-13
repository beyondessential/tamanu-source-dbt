"""Validate the data table configurations in data_tables/.

A data table names columns of a dbt model and bands continuous ones for display. Nothing here
materialises it -- tupaia-data-product compiles each file into a Tupaia data table -- so a
column renamed in a model would otherwise surface as an empty dashboard. These checks catch it
in CI instead.

Runs in this repo over the standard data tables, and in a tamanu-dbt-* repo over that
deployment's custom ones, whose models arrive as an installed package.

Run: python scripts/validate_data_tables.py
"""

import os
import sys

import yaml


BASE_DIR = os.getcwd()

DATA_TABLES_DIR = "data_tables"

# A deployment's own data tables live in its repo, where the standard models arrive as an
# installed package -- so both roots are searched and the same script runs in either repo.
MODELS_DIRS = [
    "models",
    os.path.join("dbt_packages", "tamanu_source_dbt", "models"),
]

FILTER_TYPES = {"array", "date", "yearmonth"}


def read_model_columns(model_name, models_dirs=None):
    """Return the column names a model declares in its .yml, or None if it has none.

    None distinguishes "no schema file for this model" -- which the caller reports as a
    missing model -- from a schema file that declares an empty column list.
    """
    for models_dir in models_dirs or MODELS_DIRS:
        root = os.path.join(BASE_DIR, models_dir)
        if not os.path.isdir(root):
            continue
        for dirpath, _dirnames, filenames in os.walk(root):
            for filename in filenames:
                if not filename.endswith((".yml", ".yaml")):
                    continue
                with open(os.path.join(dirpath, filename), encoding="utf-8") as f:
                    loaded = yaml.safe_load(f) or {}
                for model in loaded.get("models") or []:
                    if model.get("name") != model_name:
                        continue
                    return [c.get("name") for c in (model.get("columns") or [])]
    return None


def validate_bands(bands, where):
    """Check a band list is ordered, non-overlapping and bounded consistently.

    Bounds are half-open -- gte inclusive, lt exclusive -- so a whole-number band and a
    fractional one are written the same way. Both are optional; a band with neither matches
    everything, which is only meaningful as the last one. A gap between bands is allowed and
    falls to unmatched_label.
    """
    errors = []

    if not bands:
        errors.append(f"{where}: bands is empty")
        return errors

    previous_lt = None
    for index, band in enumerate(bands):
        at = f"{where}: band {index}"

        if not band.get("label"):
            errors.append(f"{at} has no label")

        gte = band.get("gte")
        lt = band.get("lt")

        if gte is not None and lt is not None and gte >= lt:
            errors.append(f"{at} has gte {gte} at or above lt {lt}, so it matches nothing")

        if gte is not None and previous_lt is not None and gte < previous_lt:
            errors.append(
                f"{at} starts at {gte}, below the previous band's lt {previous_lt} -- "
                "bands overlap, and the earlier one wins"
            )

        if lt is None and index != len(bands) - 1:
            errors.append(f"{at} has no lt, so it swallows every band after it")

        if lt is not None:
            if previous_lt is not None and lt <= previous_lt:
                errors.append(f"{at} has lt {lt}, at or below the previous band's {previous_lt}")
            previous_lt = lt

    labels = [b.get("label") for b in bands if b.get("label")]
    duplicates = sorted({label for label in labels if labels.count(label) > 1})
    for label in duplicates:
        errors.append(f"{where}: band label {label!r} is used more than once")

    return errors


def validate_config(config, filename, model_columns):
    """Check one data table config against its model's columns."""
    errors = []
    where = filename

    name = config.get("data_table")
    expected = os.path.splitext(filename)[0]
    if not name:
        errors.append(f"{where}: no data_table name")
    elif name != expected:
        errors.append(f"{where}: data_table is {name!r} but the filename says {expected!r}")

    if not config.get("description"):
        errors.append(f"{where}: no description")

    model = config.get("model")
    if not model:
        errors.append(f"{where}: no model")
        return errors
    if model_columns is None:
        searched = " or ".join(f"{d}/" for d in MODELS_DIRS)
        errors.append(f"{where}: model {model!r} has no schema .yml under {searched}")
        return errors

    known = set(model_columns)

    metrics = config.get("metrics") or []
    if not metrics:
        errors.append(f"{where}: no metrics -- a data table with nothing to aggregate")
    for metric in metrics:
        column = metric.get("column")
        if column not in known:
            errors.append(f"{where}: metric column {column!r} is not a column of {model}")
        if not metric.get("aggregation"):
            errors.append(f"{where}: metric {column!r} has no aggregation")

    seen = set()
    for column in config.get("columns") or []:
        name = column.get("name")
        if not name:
            errors.append(f"{where}: a column entry has no name")
            continue
        if name in seen:
            errors.append(f"{where}: column {name!r} is listed twice")
        seen.add(name)

        at = f"{where}: column {name}"

        filter_type = column.get("filter")
        if filter_type is not None and filter_type not in FILTER_TYPES:
            errors.append(
                f"{at} has filter {filter_type!r}, not one of {sorted(FILTER_TYPES)}"
            )

        derived = column.get("derived_from")
        if derived is None:
            if name not in known:
                errors.append(f"{at} is not a column of {model} and is not derived")
            continue

        if name in known:
            errors.append(
                f"{at} is derived but {model} already emits a column of that name"
            )

        source = derived.get("column")
        if source not in known:
            errors.append(f"{at} derives from {source!r}, not a column of {model}")

        # An array filter drops NULL rows, so a value in no band has to land on a label.
        if not derived.get("unmatched_label"):
            errors.append(f"{at} has no unmatched_label, so a NULL value would be dropped")

        errors.extend(validate_bands(derived.get("bands") or [], at))

    return errors


def read_configs(data_tables_dir=DATA_TABLES_DIR):
    """Read every data table config, returning (filename, config) pairs."""
    directory = os.path.join(BASE_DIR, data_tables_dir)
    if not os.path.isdir(directory):
        return []
    configs = []
    for filename in sorted(os.listdir(directory)):
        if not filename.endswith((".yml", ".yaml")):
            continue
        with open(os.path.join(directory, filename), encoding="utf-8") as f:
            configs.append((filename, yaml.safe_load(f) or {}))
    return configs


def validate_data_tables():
    configs = read_configs()

    errors = []
    names = {}
    for filename, config in configs:
        name = config.get("data_table")
        if name in names:
            errors.append(f"data_table {name!r} is defined in both {names[name]} and {filename}")
        names[name] = filename

        errors.extend(
            validate_config(config, filename, read_model_columns(config.get("model")))
        )

    for error in errors:
        print(error)

    print(f"Checked {len(configs)} data table configurations, {len(errors)} problems")
    return errors


if __name__ == "__main__":
    sys.exit(1 if validate_data_tables() else 0)

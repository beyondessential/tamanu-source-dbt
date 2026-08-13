# Data table configuration

A data table is one Tupaia-facing presentation of a dbt model: which columns are query
parameters, which are grouped, which is aggregated, and how a continuous value is banded for
display. One file here is one data table.

A metric may have several. The metric is the measurement and is defined once in
`documentations/metrics/*.yml`; how it is sliced and banded for a viewer is a presentation
choice, and a deployment that bands age differently adds its own file rather than forking the
metric.

Read by `tupaia-data-product`, which compiles each file into a Tupaia data table definition.
Nothing in this repo materialises a data table.

## Standard here, custom in the deployment repo

This folder holds the **standard** data tables, the set BES ships with the standard metrics.
A **custom** one — a deployment's own banding, or a slice only it needs — lives in that
deployment's `tamanu-dbt-*` repo under the same `documentations/data_tables/` path, the same
split as every other custom model, seed and report.

A custom file may name a standard model: the metrics arrive there as the
`tamanu_source_dbt` package, and `validate_data_tables.py` resolves a model from either root.
It takes a `data_table` name of its own rather than reusing a standard one, so adding a
deployment's banding leaves the standard data table in place beside it.

## Where a setting belongs

| Setting | Home | Why |
|---|---|---|
| What is measured, and the disaggregations the model emits | `documentations/metrics/*.yml` | one definition, every deployment |
| Which columns are filters, which is the metric, how a value is banded | here | a presentation choice, and a metric may have more than one |
| A deployment's own banding or slice | its `tamanu-dbt-*` repo, same path | custom content lives with the deployment |
| Permission groups, database connection, which data tables a deployment enables | `tupaia-data-product`, per consumer | names one deployment's groups and infrastructure |

## Schema

```yaml
data_table: emergency_visit__standard   # unique; must match the filename
model: metric__emergency_visit          # the dbt model this selects from
description: >-
  One sentence naming what a row is and what makes this presentation distinct.

metrics:
  - column: value_numeric
    aggregation: sum

columns:
  - name: facility_id
    filter: array
  - name: age_group__who_primary_classification
    filter: array
    derived_from:
      column: age_years
      unmatched_label: Unknown age
      bands:
        - { label: '0-14 years', gte: 0, lt: 15 }
        - { label: '15+ years', gte: 15 }
```

### `metrics`

Columns aggregated in the select. `aggregation` is the SQL function applied, `sum` for an
additive count. A list, so a data table may carry more than one.

### `columns`

Every entry is selectable and groupable. `filter` additionally exposes it as a query
parameter:

| `filter` | Parameter shape |
|---|---|
| `array` | a multi-select of the column's values |
| `date` | a start/end range over a date or timestamp |
| `yearmonth` | a start/end range over a `YYYYMM` column |
| *omitted* | groupable, but not filterable |

An `array` filter drops rows where the column is NULL, so a column exposed that way is
coalesced to an explicit label in the model.

A column with no `derived_from` must exist in the model. Continuous measures are usually left
out entirely: grouping by an exact minute count produces one row per value.

### `derived_from`

Bands a continuous model column into labelled categories. The band is computed by the
consumer at data table level, so the model keeps emitting the number and each data table
chooses its own classification.

- `column` — the model column to band. Must exist in the model.
- `bands` — evaluated in order, first match wins. `gte` is inclusive, `lt` exclusive, and both
  are optional: a band with neither is a catch-all. Bounds must ascend and must not overlap; a
  gap is allowed and falls to `unmatched_label`.
- `unmatched_label` — the label for a value in no band, and for NULL. Required, because the
  `array` filter would otherwise drop the row.

Half-open bounds so a whole-number band and a fractional one are written the same way:
`lt: 240` is under four hours whether the value is `239` or `239.98`.

## Validation

`python scripts/validate_data_tables.py` checks every file here, and
`scripts/tests/test_validate_data_tables.py` covers the checks. It runs against the model
`.yml` files, so a renamed or dropped column fails here rather than in a Tupaia dashboard. Run
it in a `tamanu-dbt-*` repo too: it validates that deployment's own files against the models it
has installed.

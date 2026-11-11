# Testing Spec: model Postgres compatibility

## Purpose

The models support Postgres 12 and later. A model that calls a function or uses syntax newer than
12 fails to create there, and a dbt unit test only exercises the models that have one. CI creates
every model as a view on Postgres 12 against an empty copy of the Tamanu schema, so such a model
fails the pull request instead of a deployment.

## Identity

| Field | Value |
|---|---|
| **Name** | `model-postgres-compatibility` |
| **Type** | testing architecture (no model of its own) |
| **Layer** | `tamanu-source-dbt` CI |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-11 |
| **Last updated** | 2026-11-11 |

## Business logic

- **BL-001:** `scripts/generate_source_schema.py` prints an empty table for every source table in `models/sources/` and `models/logs/`, with the column types the source declares.
- **BL-002:** A source table that declares no columns is not created.
- **BL-003:** The `dbt-unit-tests` job loads that schema into a `postgres:12` service, then runs `dbt seed` and `dbt run`, so every model is created as a view.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | The generated schema creates each declared table with its declared column types, and skips a table with no columns | BL-001, BL-002 | `scripts/tests/test_generate_source_schema.py` |
| AC-002 | A model using a function newer than Postgres 12 fails the `dbt run` step | BL-003 | CI job `dbt unit tests` |

## Limits

The check covers what Postgres resolves when it creates a view: syntax, functions, operators and
column types. The tables are empty and the target builds views, so it does not exercise runtime
behaviour on real rows, nor the table and incremental materialisations used on `analytics_*`
targets.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-11 | Maui team | Initial spec |

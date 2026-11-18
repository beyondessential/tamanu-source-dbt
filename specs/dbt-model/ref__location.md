# dbt Model Spec: `ref__location` (canonical definition)

## Purpose

OMOP `LOCATION` for the places patients are grouped under. Each row is one location, with the
names and ids of the village, subdivision, division and country it covers written onto the row,
so a consumer groups patients by area without walking a hierarchy. `clinical__person.location_id`
points here. By default a location is a village. A deployment whose villages do not describe
where patients live replaces `int__patient_address` to group patients by other places.

## Identity

| Field | Value |
|---|---|
| **Name** | `ref__location` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `ref` |
| **Materialisation** | `view` (always — OMOP health-system wrapper) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear** | [MAUI-7190](https://linear.app/bes/issue/MAUI-7190) |
| **Created** | 2026-06-28 |
| **Last updated** | 2026-11-18 |

Layer rules: [D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (ref__
layer), [D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources
from `bases/`).

## Grain

**One row per:** distinct `location_id` among patients. A location no patient is grouped
under is not emitted.

The ephemeral `int__patient_address` gives each patient their location (one row per
patient). `clinical__person` reads `location_id` from it, and this model collapses it to one
row per location, so the two always agree.

## `int__patient_address` contract

A deployment that replaces `int__patient_address` disables the package's model and keeps
these columns, one row per patient:

| Column | Notes |
|---|---|
| `patient_id` | The patient |
| `location_id` | The location's key. NULL for a patient with no location |
| `location_source_value` | The location's code |
| `village_id`, `subdivision_id`, `division_id`, `country_id` | Reference-data ids of the places the location covers, NULL where it covers none at that level |

Every column after `patient_id` is a function of `location_id`, so patients sharing a
location carry the same values (AC-002).

## Output schema

| Column | Type | Notes |
|---|---|---|
| `location_id` | text | The location's key. By default the village's `reference_data.id`. OMOP `LOCATION.location_id` |
| `location_source_value` | text | The location's code. By default the village's `reference_data.code`. OMOP `LOCATION.location_source_value` |
| `city` | text | The village's name. OMOP `LOCATION.city`. NULL when the location is not a single village |
| `county` | text | The subdivision's name. OMOP `LOCATION.county` |
| `state` | text | The division's name. OMOP `LOCATION.state` |
| `country_source_value` | text | The country's name. OMOP `LOCATION.country_source_value` |
| `village_id` | text | Extension: the village's `reference_data.id` |
| `subdivision_id` | text | Extension: the subdivision's `reference_data.id` |
| `division_id` | text | Extension: the division's `reference_data.id` |
| `country_id` | text | Extension: the country's `reference_data.id` |

The remaining OMOP `LOCATION` columns (`address_1`, `address_2`, `zip`, `country_concept_id`,
`latitude`, `longitude`) are not emitted.

## Business logic

- **BL-001:** The default `int__patient_address` reads the `reference_data`,
  `reference_data_relations` and `patients` base models only.
- **BL-002:** By default a patient's location is their village, with `location_id` the
  village's id and `location_source_value` its code, and NULL for a patient with no village.
- **BL-003:** A village's ancestors are found by walking `reference_data_relations` upward
  through places of type `village`, `settlement`, `subdivision`, `division` and `country`,
  following only links whose both ends are such places.
- **BL-004:** A village's subdivision, division and country are its ancestors at those
  levels, NULL where it has none.
- **BL-005:** Each distinct `location_id` in `int__patient_address` is one row carrying the
  names and ids of the places it covers.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `location_id` is `not_null` | BL-005 | dbt `not_null` |
| AC-002 | `location_id` is `unique` | BL-005 | dbt `unique` |
| AC-003 | A village whose hierarchy runs village → subdivision → division → country resolves every level | BL-002–BL-004 | unit test `ac_003_int__patient_address_village_hierarchy` |
| AC-004 | A settlement between a village and its subdivision is walked through | BL-003 | unit test `ac_003_int__patient_address_village_hierarchy` |
| AC-005 | A level absent from a village's hierarchy is NULL | BL-004 | unit test `ac_003_int__patient_address_village_hierarchy` |
| AC-006 | A patient with no village has a NULL `location_id` | BL-002 | unit test `ac_003_int__patient_address_village_hierarchy` |
| AC-007 | Patients sharing a location collapse to one row carrying the names and ids of its places | BL-005 | unit test `ac_007_ref__location_one_row_per_location` |

## Registry entry

None. `ref__` models are OMOP health-system wrappers.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__patient_address` | `intermediate/omop` | Each patient's location (BL-001–BL-004). Replaceable by a deployment |
| `reference_data` | `bases/` | Places, their codes and names |
| `reference_data_relations` | `bases/` | Parent links between places |
| `patients` | `bases/` | The patient's village |

## Consumers

| Model | Use |
|---|---|
| `clinical__person` | `location_id`, from `int__patient_address` |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-18 | Maui team | One row per location patients are grouped under, from the new `int__patient_address`, which a deployment may replace. The place ids ride along as extension columns (MAUI-7190) |

# dbt Model Spec: `ref__location` (canonical definition)

## Purpose

OMOP `LOCATION` for patient addresses. Each row is one address patients live at: the
combination of village, subdivision and division a patient's record resolves to, with the
names written onto the row so a consumer groups by area without walking a hierarchy.
`clinical__person.location_id` points here. A level the patient's registration details
record is taken as recorded; a level they leave blank is filled from the village's place in
Tamanu's reference-data hierarchy.

## Identity

| Field | Value |
|---|---|
| **Name** | `ref__location` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `ref` |
| **Materialisation** | `view` (always — OMOP health-system wrapper) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear** | [MAUI-7190](https://linear.app/bes/issue/MAUI-7190) |
| **Created** | 2026-06-28 |
| **Last updated** | 2026-11-18 |

Layer rules: [D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (ref__
layer), [D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources
from `bases/`).

## Grain

**One row per:** distinct address among patients, keyed by `location_id`. An address no
patient resolves to is not emitted.

Per-patient resolution sits in the ephemeral `int__patient_address` (one row per patient),
which `clinical__person` reads for `location_id` and this model collapses to one row per
address.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `location_id` | text | `<village id>_<subdivision id>_<division id>`, `unknown` for an unresolved level (BL-007). OMOP `LOCATION.location_id` |
| `location_source_value` | text | Equal to `location_id`: the key is built from source ids (BL-008). OMOP `LOCATION.location_source_value` |
| `city` | text | The village's name. OMOP `LOCATION.city`. NULL when no village is recorded |
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

- **BL-001:** Sources are the `reference_data`, `reference_data_relations`, `patients` and
  `patient_additional_data` base models only.
- **BL-002:** Each place's subdivision, division and country are found by walking
  `reference_data_relations` upward through places of type `village`, `settlement`,
  `subdivision`, `division` and `country`, following only links whose both ends are such
  places, with a place counting as its own ancestor.
- **BL-003:** A patient's village is `patients.village_id`.
- **BL-004:** A patient's subdivision is the one recorded in `patient_additional_data`, else
  the village's subdivision.
- **BL-005:** A patient's division is the one recorded in `patient_additional_data`, else the
  division of the patient's subdivision, else the village's division.
- **BL-006:** A patient's country is the country of their division, else of their
  subdivision, else of their village.
- **BL-007:** A patient's `location_id` is `<village id>_<subdivision id>_<division id>` with
  `unknown` in place of an unresolved level, and NULL when all three are unresolved.
- **BL-008:** Each distinct `location_id` is one row carrying the ids and names of its
  village, subdivision, division and country, with `location_source_value` equal to
  `location_id`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `location_id` is `not_null` | BL-007 | dbt `not_null` |
| AC-002 | `location_id` is `unique` | BL-008 | dbt `unique` |
| AC-003 | A patient with only a village whose hierarchy runs village → subdivision → division → country resolves every level from the hierarchy | BL-002–BL-007 | unit test `ac_003_int__patient_address_resolution` |
| AC-004 | A recorded subdivision and division are kept where the village's hierarchy names different ones | BL-004, BL-005 | unit test `ac_003_int__patient_address_resolution` |
| AC-005 | A patient with a recorded subdivision and no village takes the subdivision's division and gets `unknown_<subdivision>_<division>` | BL-005, BL-007 | unit test `ac_003_int__patient_address_resolution` |
| AC-006 | A settlement between a village and its subdivision is walked through | BL-002 | unit test `ac_003_int__patient_address_resolution` |
| AC-007 | A patient with no village, subdivision or division gets a NULL `location_id` | BL-007 | unit test `ac_003_int__patient_address_resolution` |
| AC-008 | Patients sharing an address collapse to one row carrying the names and ids of its levels | BL-008 | unit test `ac_008_ref__location_one_row_per_address` |

## Registry entry

None. `ref__` models are OMOP health-system wrappers.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__patient_address` | `intermediate/omop` | Per-patient address resolution (BL-002–BL-007) |
| `reference_data` | `bases/` | Places, and their names |
| `reference_data_relations` | `bases/` | Parent links between places |
| `patients` | `bases/` | The patient's village |
| `patient_additional_data` | `bases/` | The recorded subdivision and division |

## Consumers

| Model | Use |
|---|---|
| `clinical__person` | `location_id`, from `int__patient_address` |
| `int__vaccine_administration_attributes`, `metric__birth`, `metric__outpatient_visit`, `metric__patient_condition` | `village_id` as `patient_location_id` |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-18 | Maui team | One row per patient address rather than per village: recorded subdivision and division win over the village's hierarchy, `location_id` becomes the address key, and the level ids ride along as extension columns (MAUI-7190) |

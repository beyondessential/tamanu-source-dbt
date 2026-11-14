# dbt Model Spec: `map__omop_ethnicity`

## Purpose

Maps each Tamanu ethnicity to an OMOP custom concept. Ethnicity lists are set up by each
deployment and have no standard OMOP concept, so each deployment codes its own list from a
block of concept IDs assigned to it. `clinical__person` joins this map to give every patient an
ethnicity concept, and consumers read the ethnicity's name here rather than from reference data.

The package ships the map empty. A deployment that codes its ethnicity list disables the package
model and supplies its own of the same name.

**Who consumes it?** `clinical__person` (`ethnicity_source_concept_id`), and `metric__` /
`dataset__` models that disaggregate by ethnicity.

## Identity

| Field | Value |
|---|---|
| **Name** | `map__omop_ethnicity` |
| **Type** | dbt model (extension point) |
| **Layer** | `map` |
| **Materialisation** | `view` (always) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7184](https://linear.app/bes/issue/MAUI-7184) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-14 |
| **Last updated** | 2026-11-14 |

## Grain

**One row per:** ethnicity a deployment has coded. The package model has no rows.

## Inputs

None in the package model. A deployment's model holds its coded list as a values list, so it
ships in the compiled bundle, and may read `reference_data` for current names.

## Output schema

| Column | Type | Description | Tests |
|---|---|---|---|
| `local_code` | text | The ethnicity's reference-data ID, as recorded in `patient_additional_data.ethnicity_id` | `not_null`, `unique` |
| `local_name` | text | The ethnicity's name in Tamanu | `not_null` |
| `concept_id` | integer | The custom concept ID | `not_null`, `unique`, between 2,000,000,000 and 2,147,483,647 |
| `concept_name` | text | The custom concept's name | `not_null` |
| `vocabulary_id` | text | The deployment's local vocabulary | `not_null` |

## Business logic

- **BL-001:** Each ethnicity a deployment codes has exactly one custom concept, and
  `clinical__person` takes `ethnicity_source_concept_id` from the row whose `local_code` equals
  the patient's `ethnicity_id`.
- **BL-002:** A concept ID falls within the deployment's block in
  `documentations/omop-custom-concepts.md` and is never reissued to another ethnicity.
- **BL-003:** The package model returns no rows, so a deployment that has not supplied its own
  map gives every patient concept `0`.
- **BL-004:** A deployment's model replaces the package model by the same name, with the package
  model disabled in the deployment's `dbt_project.yml`. The tests declared here apply to it.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `local_code` is never NULL | BL-001 | dbt `not_null` |
| AC-002 | `local_code` is unique, so the join in `clinical__person` never fans out | BL-001 | dbt `unique` |
| AC-003 | `local_name` is never NULL | grain | dbt `not_null` |
| AC-004 | `concept_id` is never NULL | BL-001 | dbt `not_null` |
| AC-005 | `concept_id` is unique | BL-002 | dbt `unique` |
| AC-006 | `concept_id` is between 2,000,000,000 and 2,147,483,647 | BL-002 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-007 | `concept_name` is never NULL | grain | dbt `not_null` |
| AC-008 | `vocabulary_id` is never NULL | grain | dbt `not_null` |

BL-003 is covered by `clinical__person` AC-012, and the range within a deployment's own block
(BL-002) by a test in the deployment's repo.

## Lineage

```
deployment map__omop_ethnicity ──► clinical__person ──► metric__ / dataset__ disaggregations
          (package: empty)    └──────────────────────► ethnicity names for consumers
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-14 | @julianam-w | Initial version (MAUI-7184) |

# dbt Model Spec: `metric__medication_administration` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__medication_administration` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-7029 |

Canonical definition for `medication_administration`: Medication doses recorded as given on the medication administration record (MAR), one row per given dose, dated to the day it was given.

## Purpose

| `metric_id` | Unit | Measures |
|---|---|---|
| `medication_administration` | count | Medication doses given (always 1 per row) |

**Who reads it.** The Tupaia Pharmacy dashboard, via data tables in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of medication doses given -- no external body registers this indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the `medication_administration_dose` id. Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `medication_administration` |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The medication administration dose id |
| `period_start` | date | the date the dose was given (`given_time`). (BL-002) |
| `period_end` | date | NULL -- unused |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-008) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The segment's location's facility (BL-004) |
| `encounter_type` | varchar(255) | The segment's encounter type (BL-005) |
| `visit_detail_concept_id` | integer | The segment's OMOP Visit concept: 9201, 9202, 9203 or 0 (BL-005) |
| `visit_detail_concept_name` | text | Its OMOP concept name (BL-005) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `drug_source_value` | text | The medication code (BL-006) |
| `drug_source_name` | text | The medication name (BL-006) |
| `age_years` | integer | Age in whole years on the day of the event, unbanded |
| `department` | text | The segment's department, resolved to a name (BL-007) |

## Data tables

The Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** see the `events` CTE in the model.
- **BL-002 (period):** the date the dose was given (`given_time`).
- **BL-003 (segment):** each event resolves to the `clinical__visit_detail` segment active at its own timestamp, clamped to the encounter's first segment where it predates every segment, by `visit_detail__active_segment`. An event whose encounter has no segment is excluded.
- **BL-004 (facility):** `facility_id` is the facility of the segment's `care_site_id`; an event whose patient or segment location does not resolve is excluded.
- **BL-005 (setting):** `visit_detail_concept_id` and `visit_detail_concept_name` are the segment's OMOP Visit concept as `clinical__visit_detail` carries it; `encounter_type` is the segment's own encounter type.
- **BL-006 (medication):** `drug_source_value` and `drug_source_name` are the code and name of the prescribed medication, `'Not recorded'` where it does not resolve.
- **BL-007 (department):** `department` is the segment's department name, `'Not recorded'` where it does not resolve.
- **BL-008 (registration, count and indexes):** `metric_id` is the constant `'medication_administration'` and `value_numeric` the constant `1`. Where the model is a table it carries a btree index on `(visit_detail_concept_id, period_start)` and one on `period_start`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-008 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `medication_administration` and registered in `metric_definitions` | BL-008 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `period_start`, `facility_id`, `encounter_type`, `visit_detail_concept_id`, `visit_detail_concept_name`, `drug_source_value`, `drug_source_name` and `department` are `not_null` | BL-002, BL-004 -- BL-007 | `not_null` |
| AC-004 | `visit_detail_concept_id` is one of 9201, 9202, 9203, 0 | BL-005 | `accepted_values` |

## Registry entry

Registered in `documentations/metrics/pharmacy.yml` as `medication_administration`, `kind: metric`, `unit: count`,
`subject_grain: medication_administration_dose`, with disaggregations `facility_id`, `encounter_type`, `visit_detail_concept_id`, `visit_detail_concept_name`, `sex`, `drug_source_value`, `drug_source_name`, `department`.

## Dependencies

| Model | Why |
|---|---|
| `clinical__visit_detail` | The segment and its OMOP Visit concept (BL-003, BL-005) |
| `clinical__person` | Sex and birth date |
| `locations`, `departments`, `reference_data` | Facility, department and medication resolution |
| `metric_definitions` | The canonical registry |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-20 | Maui team | Initial draft (MAUI-7029) |

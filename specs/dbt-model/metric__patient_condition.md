# dbt Model Spec: `metric__patient_condition` (canonical definition)

## Purpose

A count of the ongoing conditions recorded on Tamanu patients (the patient's "ongoing conditions"
list), so a dashboard can show patients newly registered with a condition each month and how many
patients live with a condition at a date. One row per condition record, dated by when it was
recorded and ended by its resolution, with the patient carried for a distinct count.

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__patient_condition` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `draft` |
| **Owner** | Maui team (`bes-maui`) |
| **Linear issue** | [MAUI-7122](https://linear.app/bes/issue/MAUI-7122) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-13 |

## Definition sources

| Element | `definition_source` | Concept |
|---|---|---|
| `patient_condition` | `BES` | A recorded ongoing condition (Tamanu `patient_conditions`), with its condition coded from the ICD-10 diagnosis reference list |

## Grain

**One row per `(metric_id, subject_id)`**, asserted by AC-001 at `error` severity. `subject_id`
is the `patient_conditions` id, so a patient with two conditions, or the same condition recorded
twice, yields two rows; a count of patients is a distinct count over `person_id` (BL-007).

## Output schema

D5 wide format, plus disaggregations and measures.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `patient_condition`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — the standard definition |
| `subject_id` | varchar(255) | The condition record id (grain). `not_null` (AC-008) |
| `period_start` | date | Recorded date (BL-002) |
| `period_end` | date | Resolution date, NULL while ongoing (BL-002) |
| `period_granularity` | text | Constant `'day'` (AC-005) |
| `value_numeric` | numeric | Always `1` (BL-003, AC-006) |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar(255) | Always NULL (BL-004) |
| `sex` | varchar(255) | Patient's `clinical__person.gender_source_value` |
| `age_years` | integer | Age at the recorded date in whole completed years, a measure (BL-005) |
| `patient_location_id` | varchar(255) | Patient's home village, nullable (BL-006) |
| `person_id` | varchar(255) | Patient's Tamanu id (BL-007). `not_null` (AC-010) |
| `condition_id` | varchar(255) | The condition's reference data id (BL-008) |
| `condition_code` | varchar(255) | ICD-10 code of a diagnosis-list condition, else NULL (BL-008) |
| `condition_name` | varchar(255) | The condition's name, `'Not recorded'` when it does not resolve (BL-008, AC-011) |
| `is_resolved` | boolean | Resolved flag, false when unset (BL-009, AC-012) |
| `resolved_date` | date | Resolution date of a resolved condition (BL-009) |

## Business logic

- **BL-001 (inclusion):** one row per `patient_conditions` record that is not deleted, whose
  patient resolves in `clinical__person` and is not the test patient.
- **BL-002 (reporting period):** `period_start` is the recorded date and `period_end` the
  resolution date of a resolved condition, NULL while the condition is ongoing, at `'day'`
  granularity.
- **BL-003 (count):** `value_numeric` is `1` per row, so a sum is a count of condition records at
  every grain.
- **BL-004 (facility):** `facility_id` is always NULL, because Tamanu records an ongoing
  condition against the patient, not against an encounter or facility.
- **BL-005 (age):** `age_years` is the patient's age at the recorded date in whole completed
  years, unbanded and NULL with no date of birth.
- **BL-006 (patient village):** `patient_location_id` is the patient's own
  `clinical__person.location_id`, NULL when the record carries none.
- **BL-007 (patient):** `person_id` is the condition's patient, never NULL, so a consumer counts
  patients with a distinct count over it.
- **BL-008 (condition):** `condition_id` is the condition's reference data id, `condition_code`
  its code where the reference data is a `diagnosis` (the ICD-10 list) and NULL otherwise, and
  `condition_name` its name, `'Not recorded'` where the reference data does not resolve.
- **BL-009 (resolution):** `is_resolved` is the record's resolved flag, false when unset, and
  `resolved_date` its resolution date where `is_resolved` is true, NULL otherwise.
- **BL-010 (classification):** the model is `classification: restricted` and `pii: false`,
  because `person_id` beside a condition, age and village can identify a patient in a small
  deployment.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and `patient_condition` | registry | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions` | registry | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and `1` | BL-003 | `not_null` + `accepted_values` |
| AC-007 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` (`warn`) |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | The projection resolves as specified: inclusion, period, ICD-10 code only for a diagnosis-list condition, name fallback, resolution only when resolved, age and village pass-through | BL-001, BL-002, BL-004–BL-009 | unit test `ac_009_metric__patient_condition_projection` |
| AC-010 | `person_id` is `not_null` | BL-007 | `not_null` |
| AC-011 | `condition_name` is `not_null` | BL-008 | `not_null` |
| AC-012 | `is_resolved` is `not_null` | BL-009 | `not_null` |

## Registry entry

`patient_condition` in `documentations/metrics/morbidity.yml`: `kind: metric`, `unit: count`,
`subject_grain: patient_condition`, `spec_path` pointing here. `disaggregations: sex,
patient_location_id, condition_id, condition_code, condition_name, is_resolved`. `person_id` is
not a disaggregation: a consumer only takes a distinct count over it.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `patient_conditions` | `bases/` | The condition records, deleted and test-patient rows already removed (BL-001) |
| `clinical__person` | `clinical/` | Sex, date of birth and village (BL-001, BL-005, BL-006) |
| `reference_data` | `bases/` | Condition code and name (BL-008) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Reads |
|---|---|
| Tupaia condition cards, through a data table in `tupaia-data-product` | Patients newly registered with a condition per month (a distinct count of `person_id` grouped on `period_start`), and prevalence at a date (rows with `period_start` on or before it and `period_end` NULL or after it) |

## Related

| Artefact | Relationship |
|---|---|
| `derived__cohort_ncd` | Registry membership built from program registry conditions, a different Tamanu record from the ongoing conditions list; the two are not reconciled |
| `metric__encounter_diagnosis` | Diagnoses recorded against an encounter; an ongoing condition is recorded against the patient |
| `ds__ongoing_conditions` | The Tamanu-report-layer line list over the same records |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Should `facility_id` be derived (for example the facility of the patient's latest encounter on or before the recorded date) for a card that needs a facility breakdown? | bes-maui | TBD |

## Change log

| Date | Change |
|---|---|
| 2026-11-13 | Created: one row per patient ongoing condition, for condition registration and prevalence cards (MAUI-7122). |

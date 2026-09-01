# dbt Model Spec: `metric__opd_diagnosis` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__opd_diagnosis` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `opd_diagnosis`: one row per diagnosis whose window overlaps an
outpatient segment, at day resolution.

## Purpose

| `metric_id` | Unit | Measures |
|---|---|---|
| `opd_diagnosis` | count | Diagnoses whose window overlaps an outpatient encounter segment (always 1 per row) |

A separate metric from `metric__encounter_diagnosis`, which carries `encounter_type` as a
disaggregation instead.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | No external body registers a diagnosis-count indicator scoped to outpatient care |

`status: draft`, `spec_path` pointing here.

## Grain

**One row per `(metric_id, subject_id)`.** `subject_id` is
`clinical__condition_occurrence.condition_occurrence_id`.

A diagnosis can also appear in an inpatient-scoped diagnosis metric, if one exists -- BL-003
allows a diagnosis to overlap both.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `opd_diagnosis`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL |
| `subject_id` | varchar(255) | The Tamanu diagnosis id. `not_null` |
| `period_start` | date | The date the diagnosis was recorded |
| `period_end` | date | NULL |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar(255) | The earliest qualifying outpatient segment's facility (BL-004). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `diagnosis` | text | The diagnosis as recorded, ungrouped. Never NULL |
| `diagnosis_code` | text | The diagnosis's reference-data code. Never NULL |
| `diagnosis_certainty` | text | The diagnosis's certainty as recorded. Never NULL |
| `is_primary` | boolean | Whether this is the encounter's principal diagnosis. NULL where unranked |
| `age_years` | integer | Age in whole years at the diagnosis, unbanded |

## Data tables

Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`.
This model carries no `data_table_*` meta. Not yet built as of this spec.

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`.
- **BL-002 (reporting period):** `period_start` is
  `clinical__condition_occurrence.condition_start_date`; `period_end` is hardcoded NULL.
- **BL-003 (outpatient scope, by window overlap):** `condition_start_datetime` carries no
  time of day -- it is always midnight. A diagnosis's window is
  `[greatest(condition_start_datetime, visit_start_datetime), visit_end_datetime]`
  (open-ended if the encounter has not closed). A diagnosis is included when any
  `clinical__visit_detail` segment for its encounter has `visit_detail_concept_id = 9202`
  and overlaps that window:

  ```
  visit_detail_end_datetime >= window_start
  and (window_end is null or visit_detail_start_datetime <= window_end)
  ```

  A diagnosis whose window overlaps segments of more than one type is included in every
  metric whose concept it overlaps -- this metric only tests for 9202; it does not exclude a
  diagnosis for also overlapping a non-9202 segment.
- **BL-004 (facility attribution):** `facility_id` is the earliest qualifying segment's own
  `care_site_id`, resolved through `bases/locations`. The join is inner: a diagnosis whose
  qualifying segment's location does not resolve is excluded.
- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml`.
- **BL-006 (diagnosis identity is emitted raw):** `diagnosis`, `diagnosis_code` and
  `diagnosis_certainty` are coalesced so none is ever NULL. `is_primary` is exempt: NULL
  means the encounter did not rank its diagnoses.
- **BL-007 (age is the consumer's to band):** `age_years` is unbanded, absent from the
  registry's disaggregations.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` | BL-001 | `not_null` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `metric_id` is always `opd_diagnosis` | BL-001 | `accepted_values` |
| AC-005 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | `period_end` is always NULL | BL-002 | `dbt_expectations.expect_column_values_to_be_null` |
| AC-010 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-011 | `diagnosis` is `not_null` | BL-006 | `not_null` |
| AC-012 | `diagnosis_code` is `not_null` | BL-006 | `not_null` |
| AC-013 | `diagnosis_certainty` is `not_null` | BL-006 | `not_null` |

## Registry entry

`opd_diagnosis`, `kind: metric`, `subject_grain: diagnosis`, `status: draft`,
`disaggregations: facility_id,sex,diagnosis,diagnosis_code,diagnosis_certainty,is_primary`.
No vocabulary change needed -- all admitted via `metric__encounter_diagnosis`'s own
registration.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__condition_occurrence` | `clinical/` | Diagnosis date/time, code, certainty, primary flag, person and visit FKs |
| `clinical__visit_occurrence` | `clinical/` | Encounter start/end for the diagnosis's window (BL-003) |
| `clinical__visit_detail` | `clinical/` | Outpatient scope and facility (BL-003, BL-004) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-007) |
| `locations` | `bases/` | Facility id of the qualifying segment's care site (BL-004) |
| `metric_definitions` | root | Registry; `metric_id` FK target |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Not yet built as of this spec |

**What a consumer must do:**

1. Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. Bucket the time grain and exclude the incomplete current period.
3. Group `diagnosis_code` itself if a classification is wanted.
4. Band `age_years` itself.
5. A diagnosis may also appear in an inpatient-scoped diagnosis metric (BL-003) -- summing
   both is not the same as the total diagnosis count.

## Related

| Artefact | Relationship |
|---|---|
| `metric__encounter_diagnosis` | Same clinical source; carries `encounter_type` instead of an OPD/IPD split |
| `metric__opd_procedure` | Sibling OPD metric; uses single-segment attribution instead of window overlap, since procedure timestamps are usually precise |
| `metric__outpatient_visit` | Sibling metric in the outpatient product; first-segment grain |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

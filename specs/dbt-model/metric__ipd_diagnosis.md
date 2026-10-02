# dbt Model Spec: `metric__ipd_diagnosis` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ipd_diagnosis` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `ipd_diagnosis`: one row per diagnosis whose window overlaps an
inpatient-admission segment, at day resolution.

## Purpose

| `metric_id` | Unit | Measures |
|---|---|---|
| `ipd_diagnosis` | count | Diagnoses whose window overlaps an inpatient (admission) encounter segment (always 1 per row) |

A separate metric from `metric__encounter_diagnosis`, which carries `encounter_type` as a
disaggregation instead, and from `metric__opd_diagnosis`, which scopes to the outpatient
concept (9202) instead of the inpatient one (9201).

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | No external body registers a diagnosis-count indicator scoped to inpatient care |

`status: draft`, `spec_path` pointing here.

## Grain

**One row per `(metric_id, subject_id)`.** `subject_id` is
`clinical__condition_occurrence.condition_occurrence_id`.

A diagnosis can also appear in `metric__opd_diagnosis` -- BL-003 allows a diagnosis to
overlap both an outpatient and an inpatient segment of the same encounter.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ipd_diagnosis`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL |
| `subject_id` | varchar(255) | The Tamanu diagnosis id. `not_null` |
| `period_start` | date | The date the diagnosis was recorded |
| `period_end` | date | NULL |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar(255) | The earliest qualifying inpatient segment's facility (BL-004). `not_null` |
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
- **BL-003 (inpatient scope, by window overlap):** a diagnosis is coded against the
  encounter as a whole, not against whichever phase happened to be active the moment it was
  recorded -- so its window deliberately reaches forward to the encounter's end, not just to
  the segment nearest its own date. A diagnosis made on the day an admission's earlier
  emergency/triage/observation phase closes and the inpatient phase begins is included in
  `ipd_diagnosis` (and may also be in `opd_diagnosis`, if the same encounter later moves to a
  clinic phase) precisely because it is attached to the encounter, not to the segment
  specifically active at the moment it was recorded. `condition_start_datetime` carrying no
  time of day (it is always midnight) only explains why the window cannot be narrowed
  *within* a day -- it is not why the window reaches forward at all; that is BL-003's own
  rule, independent of the timestamp precision available.

  Concretely, a diagnosis's window is
  `[greatest(condition_start_datetime, visit_start_datetime), visit_end_datetime]`
  (open-ended if the encounter has not closed). If `condition_start_datetime` falls after
  `visit_end_datetime`, the lower bound is clamped down to `visit_end_datetime` too, so the
  diagnosis lands in whatever segment the encounter was in right before it closed, rather
  than in an inverted window that overlaps nothing. A diagnosis is included when any
  `clinical__visit_detail` segment for its encounter has `visit_detail_concept_id = 9201`
  and overlaps that window:

  ```
  (visit_detail_end_datetime is null or visit_detail_end_datetime >= window_start)
  and (window_end is null or visit_detail_start_datetime <= window_end)
  ```

  The `visit_detail_end_datetime is null` branch is a cross-model contract, not just a
  NULL-safety guard: `clinical__visit_detail` (its own BL-002/AC-014) leaves the currently
  active segment of an encounter that has not closed with a NULL end, rather than defaulting
  it to the segment's own start -- without that, a diagnosis dated any time after that
  segment began would fail this check and be silently dropped, the same failure mode the
  `window_end`-based clamp above fixes for a *closed* encounter. This model's
  `clinical__visit_detail` dependency on that NULL is guarded upstream by
  `test_clinical__visit_detail_open_encounter_stays_open`.

  A diagnosis whose window overlaps segments of more than one type is included in every
  metric whose concept it overlaps -- this metric only tests for 9201; it does not exclude a
  diagnosis for also overlapping a non-9201 segment. In particular, OMOP concept 262
  (`admission_from_emergency`) is never assigned at the segment level -- `map__omop_visit_type`
  maps a segment's own Tamanu `encounter_type` only to 9201, 9202, 9203 or 0, and 262 is
  applied solely at the whole-encounter level by `clinical__visit_occurrence` (its own
  BL-002) -- so this segment-level 9201 check needs no special case for it: a diagnosis
  recorded during an admission's earlier emergency/triage/observation phase (segment concept
  9203) correctly does not count as `ipd_diagnosis` unless its window also overlaps a
  separate 9201 segment.
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
| AC-004 | `metric_id` is always `ipd_diagnosis` | BL-001 | `accepted_values` |
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

`ipd_diagnosis`, `kind: metric`, `subject_grain: diagnosis`, `status: draft`,
`disaggregations: facility_id,sex,diagnosis,diagnosis_code,diagnosis_certainty,is_primary`.
No vocabulary change needed -- all admitted via `metric__encounter_diagnosis`'s own
registration.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__condition_occurrence` | `clinical/` | Diagnosis date/time, code, certainty, primary flag, person and visit FKs |
| `clinical__visit_occurrence` | `clinical/` | Encounter start/end for the diagnosis's window (BL-003) |
| `clinical__visit_detail` | `clinical/` | Inpatient scope and facility (BL-003, BL-004) |
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
5. A diagnosis may also appear in `opd_diagnosis` (BL-003) -- summing both is not the same
   as the total diagnosis count.
6. `ipd_diagnosis` includes a diagnosis if *any* segment its window overlaps is 9201
   (BL-003), independent of whether that segment was the encounter's first -- so it does
   not correspond one-to-one with "encounters admitted as inpatient".

## Related

| Artefact | Relationship |
|---|---|
| `metric__encounter_diagnosis` | Same clinical source; carries `encounter_type` instead of an OPD/IPD split |
| `metric__opd_diagnosis` | Sibling metric; same window-overlap logic, scoped to OMOP concept 9202 instead of 9201 |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

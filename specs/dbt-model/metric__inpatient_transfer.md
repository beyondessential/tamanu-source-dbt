# dbt Model Spec: `metric__inpatient_transfer` (canonical definition)

## Purpose

A count of inpatient transfers: each time an admitted patient is moved from one location to
another within a hospital stay. One row per move, dated when the patient moved, with the
locations and location groups (wards or areas) moved from and to, so a dashboard can count
transfers per month by ward and tell a ward-to-ward transfer from a bed move within a ward.

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__inpatient_transfer` (1 registered indicator) |
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
| `inpatient_transfer` | `BES` | A change of location recorded in an inpatient encounter's history (Tamanu `encounter_history`) |

## Grain

**One row per `(metric_id, subject_id)`**, asserted by AC-001 at `error` severity. `subject_id`
is the `clinical__visit_detail` id of the segment the patient moved into (an `encounter_history`
id), so an admission with three moves yields three rows.

## Output schema

D5 wide format, plus disaggregations.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `inpatient_transfer`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — the standard definition |
| `subject_id` | varchar(255) | The segment moved into (grain). `not_null` (AC-008) |
| `period_start` | timestamp | When the patient moved (BL-002) |
| `period_end` | timestamp | Equal to `period_start` (BL-002) |
| `period_granularity` | text | Constant `'minute'` (AC-005) |
| `value_numeric` | numeric | Always `1` (BL-003, AC-006) |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar(255) | Facility of the location moved to (BL-004). `not_null` (AC-007) |
| `sex` | varchar(255) | Patient's `clinical__person.gender_source_value` |
| `age_years` | integer | Age at the move in whole completed years, a measure (BL-005) |
| `visit_occurrence_id` | varchar(255) | The encounter, matching `metric__inpatient_admission.subject_id` (BL-006) |
| `from_location_id` / `to_location_id` | varchar(255) | Locations moved from and to (BL-007) |
| `from_location_name` / `to_location_name` | varchar(255) | Their names (BL-007) |
| `from_location_group_name` / `to_location_group_name` | text | Their location groups' names, `'Not recorded'` for a location in no group (BL-007, AC-010) |
| `from_department_id` / `to_department_id` | varchar(255) | Departments of the segments moved from and to, nullable (BL-008) |
| `is_location_group_change` | boolean | The move changed location group (BL-009, AC-011) |
| `is_department_change` | boolean | The move changed department (BL-009, AC-011) |

## Business logic

- **BL-001 (inclusion):** a transfer is a `clinical__visit_detail` segment whose location differs
  from its preceding segment's in the same encounter, where both segments are typed as an
  inpatient visit (concept 9201) and both locations resolve.
- **BL-002 (reporting period):** `period_start` and `period_end` are both the start of the segment
  moved into, at `'minute'` granularity.
- **BL-003 (count):** `value_numeric` is `1` per row, so a sum is a count of transfers at every
  grain.
- **BL-004 (facility):** `facility_id` is the facility of the location moved to.
- **BL-005 (age):** `age_years` is the patient's age at the move in whole completed years,
  unbanded and NULL with no date of birth.
- **BL-006 (encounter):** `visit_occurrence_id` is the encounter the move belongs to, so a
  consumer can count transfers per admission against `metric__inpatient_admission`.
- **BL-007 (locations):** `from_*` and `to_*` are the preceding segment's and the moved-into
  segment's location id, location name and location group name, the group name `'Not recorded'`
  where the location is in no group.
- **BL-008 (department):** `from_department_id` and `to_department_id` are the two segments'
  departments as Tamanu ids, NULL where a segment records none.
- **BL-009 (transfer kind):** `is_location_group_change` is true where the two locations are in
  different location groups, or only one is in a group, and `is_department_change` is true where
  the two departments differ, a NULL department counting as a value.
- **BL-010 (classification):** the model is `classification: internal` and `pii: false`, like
  `metric__inpatient_admission`, with no facility sensitivity filter, and a row carries the
  encounter and segment ids as its only identifiers.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and `inpatient_transfer` | registry | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions` | registry | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and `1` | BL-003 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | A move between inpatient segments is a row; a clinician handover in the same location, the move from an ED segment into the admission, and an encounter's first segment are not; the location, group and department fields and both change flags resolve as specified | BL-001, BL-002, BL-004–BL-009 | unit test `ac_009_metric__inpatient_transfer_projection` |
| AC-010 | `from_location_group_name` and `to_location_group_name` are `not_null` | BL-007 | `not_null` |
| AC-011 | `is_location_group_change` and `is_department_change` are `not_null` | BL-009 | `not_null` |

## Registry entry

`inpatient_transfer` in `documentations/metrics/inpatient.yml`: `kind: metric`, `unit: count`,
`subject_grain: transfer`, `spec_path` pointing here. `disaggregations: facility_id, sex,
from_location_id, to_location_id, from_location_name, to_location_name, from_location_group_name,
to_location_group_name, from_department_id, to_department_id, is_location_group_change,
is_department_change`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Encounter segments from `encounter_history`, their visit concept and preceding segment (BL-001, BL-002, BL-008) |
| `clinical__person` | `clinical/` | Sex and date of birth (BL-005) |
| `locations` | `bases/` | Location name, group and facility (BL-004, BL-007) |
| `location_groups` | `bases/` | Location group name (BL-007) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Reads |
|---|---|
| Tupaia inpatient cards, through a data table in `tupaia-data-product` | Transfers per period by ward, filtered to `is_location_group_change` for ward-to-ward transfers |

## Related

| Artefact | Relationship |
|---|---|
| `metric__inpatient_admission` | The admissions these transfers happen within; its admission is the move into the first inpatient segment, which is not a transfer here |
| `data-staging` `fct_inpatient_transfers` | The predecessor transfer fact, which also counts a department change with no location change |

## Change log

| Date | Change |
|---|---|
| 2026-11-13 | Created: one row per inpatient location change, resolving OQ-001 of `metric__inpatient_admission` (MAUI-7122). |

# dbt Model Spec: `metric__encounter` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__encounter` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6906 |

Canonical definition for `encounter`: one row per encounter of every type, with the attributes
on the encounter record.

## Purpose

Encounters counted once each, however many settings they pass through, attributed the way
Tamanu's own encounter reports attribute them.

| `metric_id` | Unit | Measures |
|---|---|---|
| `encounter` | count | Encounters (always 1 per row) |

**Who reads it.** Tupaia summary cards -- total encounters, encounters by month, by age and sex,
and by clinician -- via a data table in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of every encounter -- no external body registers a whole-facility encounter count |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the encounter id. Asserted by
AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `encounter` (BL-006) |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The encounter id |
| `period_start` | date | The encounter's start date (BL-002) |
| `period_end` | date | NULL |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-006) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The facility of the encounter's location (BL-003) |
| `encounter_type` | varchar(255) | The encounter's type (BL-004) |
| `visit_concept_id` | integer | The encounter's OMOP Visit concept: 9201, 9202, 9203, 262 or 0 (BL-007) |
| `visit_concept_name` | text | Its OMOP name, e.g. Emergency Room and Inpatient Visit (BL-007) |
| `department` | text | The encounter's department, resolved to a name (BL-004) |
| `clinician` | text | The encounter's supervising clinician, resolved to a name (BL-005) |
| `clinician_designation` | text | The clinician's designations, comma-separated (BL-008) |
| `location_group_id` | varchar(255) | The location group of the encounter's location; nullable (BL-009) |
| `location_group_name` | varchar(255) | That location group's name (BL-009) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at the encounter start, unbanded -- a measure, not a dimension |

## Data tables

The Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every encounter in `clinical__visit_occurrence` is counted once, of every encounter type, survey-response encounters included.
- **BL-002 (period):** `period_start` is the encounter's start date.
- **BL-003 (facility):** `facility_id` is the facility of the encounter's location, and an encounter whose location does not resolve is excluded.
- **BL-004 (type and department):** `encounter_type` is the encounter's type and `department` its department name, both as on the encounter record, `'Not recorded'` where the department does not resolve.
- **BL-005 (clinician):** `clinician` is the name of the encounter's supervising clinician, `'Not recorded'` where there is none.
- **BL-006 (registration and count):** `metric_id` is the constant `'encounter'` and `value_numeric` the constant `1`, so a consumer sums it to count encounters at any grain.
- **BL-007 (visit concept):** `visit_concept_id` and `visit_concept_name` are the encounter's OMOP Visit concept and its name, as `clinical__visit_occurrence` carries them.
- **BL-008 (clinician designation):** `clinician_designation` is the names of the supervising clinician's designations (`user_designations`, resolved through `reference_data` of type `designation`), alphabetical and joined with `', '`, `'Not recorded'` where the clinician has none or there is no clinician. Designations are collapsed to one row per user before the join, so a clinician with several cannot fan an encounter out. Tamanu keeps no designation history, so these are the clinician's current designations, not those held at the encounter. Kept apart from `clinician` so a consumer filters by name unchanged and combines the two for display.
- **BL-009 (location group):** `location_group_id` and `location_group_name` are the location group (area) of the encounter's location, the location `facility_id` comes from (BL-003). Where the location has no group, or the group does not resolve, the id is NULL and the name `'Not recorded'`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-001 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `encounter` and registered in `metric_definitions` | BL-006 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `subject_id`, `period_start`, `value_numeric`, `facility_id`, `encounter_type`, `department`, `clinician`, `clinician_designation` and `location_group_name` are populated, and `value_numeric` is 1 | BL-002 -- BL-006, BL-008, BL-009 | `not_null` + `accepted_values` |
| AC-004 | `period_end` is always NULL and `period_granularity` always `'day'` | BL-002 | `expect_column_values_to_be_null` + `accepted_values` |
| AC-005 | Each encounter is one row with the facility, type, department and clinician on its record; a survey-response encounter is counted; an unrecorded department and clinician read `'Not recorded'`; an encounter whose location does not resolve is excluded | BL-001, BL-003 -- BL-005 | unit test `ac_005_metric__encounter_attribution` |
| AC-006 | Every encounter in `clinical__visit_occurrence` has a row, so an encounter dropped for want of a location or patient is surfaced | BL-001, BL-003 | `dbt_utils.equal_rowcount` against `clinical__visit_occurrence` (`warn`) |
| AC-007 | A clinician with two designations reads both, alphabetical and comma-separated, on one row; a clinician with none, and an encounter with no clinician, read `'Not recorded'`; a location with no group reads a NULL id and `'Not recorded'` | BL-008, BL-009 | unit test `ac_007_metric__encounter_designation_location_group` |

## Registry entry

Registered in `documentations/metrics/encounter.yml` as `encounter`, `kind: metric`,
`unit: count`, `subject_grain: encounter`, with disaggregations `facility_id`, `encounter_type`,
`visit_concept_id`, `visit_concept_name`, `department`, `clinician`, `clinician_designation`,
`location_group_id`, `location_group_name` and `sex`.

## Dependencies

| Model | Why |
|---|---|
| `clinical__visit_occurrence` | The population and the encounter's location, type, department and clinician (BL-001 -- BL-005) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-003) |
| `departments` | Department name resolution (BL-004) |
| `ref__provider` | Clinician name resolution (BL-005) |
| `user_designations`, `reference_data` | The clinician's designations (BL-008) |
| `location_groups` | The location's group (BL-009) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia summary dashboard | Total encounters, encounters by month, by age and sex, and by clinician |

## Related

| Artefact | Relationship |
|---|---|
| `encounters_core` and the report-layer dataset macros | The same attribution: the encounter record's own location, department, type and clinician |
| `metric__outpatient_visit`, `metric__emergency_visit`, `metric__inpatient_admission` | The setting-scoped counts, attributed to a segment rather than the encounter record; an encounter that passes through more than one setting appears in more than one of them |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-01 | Maui team | Initial draft (MAUI-6906) |
| 2026-10-08 | Maui team | Add `clinician_designation` (BL-008) and `location_group_id` / `location_group_name` (BL-009), for the Tupaia Summary dashboard's clinician table (MAUI-6906) |

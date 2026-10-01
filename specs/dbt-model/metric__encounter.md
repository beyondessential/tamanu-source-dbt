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

Canonical definition for `encounter`: one row per encounter of every type, attributed to the
encounter's first segment.

## Purpose

Encounters counted once each, however many settings they pass through.

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
| `metric_id` | text | Always `encounter` (BL-007) |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The encounter id |
| `period_start` | date | The encounter's start date (BL-003) |
| `period_end` | date | NULL |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-007) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The facility of the first segment's location (BL-004) |
| `encounter_type` | varchar(255) | The first segment's encounter type (BL-005) |
| `encounter_setting` | text | `Outpatient`, `Inpatient`, `Emergency` or `Other` (BL-005) |
| `department` | text | The first segment's department, resolved to a name (BL-005) |
| `clinician` | text | The first segment's clinician, resolved to a name (BL-006) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at the encounter start, unbanded -- a measure, not a dimension |

## Data tables

The Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every encounter with a resolved segment is counted, of every encounter type, survey-response encounters included.
- **BL-002 (first segment):** each encounter is attributed to its first `clinical__visit_detail` segment, the one with no preceding segment.
- **BL-003 (period):** `period_start` is the first segment's start date.
- **BL-004 (facility):** `facility_id` is the facility of the first segment's location, and an encounter whose location does not resolve is excluded.
- **BL-005 (setting and department):** `encounter_type` is the first segment's encounter type, `encounter_setting` is `Inpatient` for OMOP concept 9201, `Outpatient` for 9202, `Emergency` for 9203 and `Other` for everything else, and `department` is the first segment's department name, `'Not recorded'` where it does not resolve.
- **BL-006 (clinician):** `clinician` is the name of the provider on the first segment, `'Not recorded'` where there is none.
- **BL-007 (registration and count):** `metric_id` is the constant `'encounter'` and `value_numeric` the constant `1`, so a consumer sums it to count encounters at any grain.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-002 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `encounter` and registered in `metric_definitions` | BL-007 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `subject_id`, `period_start`, `value_numeric`, `facility_id`, `encounter_type`, `encounter_setting`, `department` and `clinician` are populated, and `value_numeric` is 1 | BL-003 -- BL-007 | `not_null` + `accepted_values` |
| AC-004 | `period_end` is always NULL and `period_granularity` always `'day'` | BL-003 | `expect_column_values_to_be_null` + `accepted_values` |
| AC-005 | `encounter_setting` is one of `Outpatient`, `Inpatient`, `Emergency`, `Other` | BL-005 | `accepted_values` |
| AC-006 | An encounter that moves from triage to admission is one Emergency row at its triage facility, department and clinician; a clinic encounter is Outpatient; a survey-response encounter is counted as Other; an unrecorded department and clinician read `'Not recorded'` | BL-001, BL-002, BL-004 -- BL-006 | unit test `ac_006_metric__encounter_first_segment` |

## Registry entry

Registered in `documentations/metrics/encounter.yml` as `encounter`, `kind: metric`,
`unit: count`, `subject_grain: encounter`, with disaggregations `facility_id`, `encounter_type`,
`encounter_setting`, `department`, `clinician` and `sex`.

## Dependencies

| Model | Why |
|---|---|
| `clinical__visit_detail` | The first segment and its concept, location, department and provider (BL-002 -- BL-006) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-004) |
| `departments` | Department name resolution (BL-005) |
| `ref__provider` | Clinician name resolution (BL-006) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia summary dashboard | Total encounters, encounters by month, by age and sex, and by clinician |

## Related

| Artefact | Relationship |
|---|---|
| `metric__outpatient_visit`, `metric__emergency_visit` | The setting-scoped visit counts, attributed to the same first segment |
| `metric__inpatient_admission` | Admissions, which also count an encounter admitted from the emergency department -- here that encounter is one Emergency row |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-01 | Maui team | Initial draft (MAUI-6906) |

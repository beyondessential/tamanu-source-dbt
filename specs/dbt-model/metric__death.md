# dbt Model Spec: `metric__death` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__death` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6906 |

Canonical definition for `death`: one row per deceased patient, with the population, death
record and encounter died in of `ds__deaths`, and a facility that falls back to the encounter.

## Purpose

Recorded deaths, one row per deceased patient.

| `metric_id` | Unit | Measures |
|---|---|---|
| `death` | count | Deceased patients (always 1 per row) |

**Who reads it.** Tupaia summary cards via a data table in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of patients recorded as deceased |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the patient id. Asserted by
AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `death` (BL-007) |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The patient id |
| `period_start` | date | The date of death (BL-003) |
| `period_end` | date | NULL |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-007) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The death record's facility, else the encounter died in's; nullable (BL-004) |
| `facility_source` | text | `Death record`, `Encounter` or `Not recorded` (BL-004) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at death, unbanded -- a measure, not a dimension |
| `primary_cause` | text | The death record's primary cause name (BL-005) |
| `primary_cause_code` | text | The primary cause's code (BL-005) |
| `place_of_death` | text | `Health facility`, `Outside health facility` or `Not recorded` (BL-005) |
| `manner_of_death` | text | The death record's manner of death (BL-005) |
| `department` | text | The department of the encounter the patient died in (BL-006) |

## Data tables

The Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every patient with a date of death is counted, whether or not a death record exists.
- **BL-002 (death record):** each patient's death record is the latest current one, preferring a finalised record, the same pick `ds__deaths` makes.
- **BL-003 (period):** `period_start` is the patient's date of death.
- **BL-004 (facility):** `facility_id` is the facility on the death record, and where the record names none, the facility of the final location of the encounter the patient died in (BL-006); NULL where neither names one. `facility_source` records which: `Death record`, `Encounter` or `Not recorded`.
- **BL-005 (death record attributes):** `primary_cause` and `primary_cause_code` are the name and code of the record's primary cause, `manner_of_death` is the record's manner, and `place_of_death` is `Outside health facility` or `Health facility` as the record says, and `Not recorded` where there is no record or the record does not say; every text value falls back to `'Not recorded'`.
- **BL-006 (encounter died in):** the encounter the patient died in is the latest one whose span, start to end, covers the date of death, the match `ds__deaths` makes; an encounter with no end does not match. `department` is that encounter's department, `'Not recorded'` where there is none.
- **BL-007 (registration and count):** `metric_id` is the constant `'death'` and `value_numeric` the constant `1`, so a consumer sums it to count deaths at any grain.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-002 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `death` and registered in `metric_definitions` | BL-007 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `subject_id`, `period_start`, `value_numeric`, `primary_cause`, `primary_cause_code`, `manner_of_death` and `department` are populated, and `value_numeric` is 1 | BL-003, BL-005 -- BL-007 | `not_null` + `accepted_values` |
| AC-004 | `period_end` is always NULL and `period_granularity` always `'day'` | BL-003 | `expect_column_values_to_be_null` + `accepted_values` |
| AC-005 | `place_of_death` is one of `Health facility`, `Outside health facility`, `Not recorded`, and `facility_source` one of `Death record`, `Encounter`, `Not recorded` | BL-004, BL-005 | `accepted_values` |
| AC-006 | A patient with two current death records reads the finalised one and its facility; a record with no facility takes the facility of the encounter spanning the death; a death with neither has a NULL facility; a death during an encounter with no end matches no encounter; a patient with no date of death is not counted | BL-001 -- BL-006 | unit test `ac_006_metric__death_population` |

## Registry entry

Registered in `documentations/metrics/mortality.yml` as `death`, `kind: metric`, `unit: count`,
`subject_grain: patient`, with disaggregations `facility_id`, `facility_source`, `sex`, `primary_cause`,
`primary_cause_code`, `place_of_death`, `manner_of_death` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `patients` | The population and date of death (BL-001, BL-003) |
| `patient_death_data` | The death record (BL-002, BL-004, BL-005) |
| `encounters` | The encounter the patient died in (BL-006) |
| `locations` | The encounter's facility, for the fallback (BL-004) |
| `clinical__person` | Sex and birth date |
| `reference_data` | Primary cause resolution (BL-005) |
| `departments` | Department name resolution (BL-006) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia summary dashboard | Recorded deaths |

## Related

| Artefact | Relationship |
|---|---|
| `ds__deaths` | The report-layer dataset behind the deceased patients line list; this metric shares its population, death record and encounter died in, and adds the encounter's facility where the record names none |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-01 | Maui team | Initial draft (MAUI-6906) |

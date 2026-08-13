# dbt Model Spec: `metric__emergency_stay` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__emergency_stay` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else (BL-008) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.54`) |
| **Linear issue** | [MAUI-6694](https://linear.app/bes/issue/MAUI-6694) |
| **Created** | 2026-08-12 |
| **Last updated** | 2026-08-13 |

Canonical definition for `ed_stay`: one row per ED stay, spanning presentation at the emergency
department to departure from it at minute resolution.

## Purpose

How long patients spend in the emergency department, and how their encounter ended.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_stay` | count | ED stays (always 1 per row; duration is `period_end - period_start`) |

**Relationship to `metric__emergency_visit`.** Both cover the **same rows**, from the same
`int__emergency_visits` base, so a count of `ed_stay` equals a count of `ed_visit` over
the same filter. They differ in the period measured and what they disaggregate by:

| | `metric__emergency_visit` | `metric__emergency_stay` |
|---|---|---|
| `period_end` | Encounter end — hospital discharge | Departure from the ED |
| Duration | Total length of stay | Time in the ED |
| Distinctive disaggregations | Diagnosis chapter, hour of arrival, admission outcome (plus `waiting_time__minutes`) | Time-in-ED band, discharge disposition (plus `ed_time__minutes`) |

Use this model for duration and disposition questions, `metric__emergency_visit` for
arrival, waiting-time, diagnosis and admission questions.

**Who reads it.** The Tupaia "Hospital Administration → Emergency" dashboard for Queen of Sheba
Hospital (MAUI-6694), via a data table over this view.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| The stay period | AIHW | [472757](https://meteor.aihw.gov.au/content/472757) | Emergency department stay — "the period between when a patient presents at an emergency department and when that person is recorded as having physically departed" |
| `period_start` | AIHW | [746091](https://meteor.aihw.gov.au/content/746091) / [746096](https://meteor.aihw.gov.au/content/746096) | ED stay — presentation date / time |
| `period_end` | AIHW | [746076](https://meteor.aihw.gov.au/content/746076) / [746081](https://meteor.aihw.gov.au/content/746081) | ED stay — physical departure date / time |

The AIHW object class defines this model's period exactly; BL-015's four-hour banding is a BES
composition over that concept.

**DV-001 — physical departure vs administrative transition.** AIHW's `period_end` is when the
patient is recorded as having *physically departed*, whereas Tamanu records the administrative
transition out of the ED phase (BL-002) — which for an admitted patient can precede physical
departure, so a patient admitted on paper but still boarding counts as departed. Time in the ED
is therefore understated wherever boarding occurs, which is precisely the delay a four-hour
measure exists to expose. The administrative transition is the only departure signal Tamanu
records.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity — a duplicate
would double-count a stay in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id, matching the registry's `subject_grain: visit`, and
is unique because only the ED intake segment is counted (BL-003). Each of a patient's stays is an
independent row (BL-010).

## Output schema

D5 wide format, plus five disaggregation columns.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_stay`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | Encounter id (BL-011). `not_null` (AC-008) |
| `period_start` | timestamp | Arrival in the ED (BL-002). `data_table_filter: date` |
| `period_end` | timestamp | Departure from the ED. NULL while the patient is in the ED with no transfer planned (BL-002, BL-018) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so `data_table_metric: sum` |
| `value_boolean` | boolean | NULL — this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Intake segment's facility (BL-007). `data_table_filter: array` |
| `sex` | varchar(255) | `clinical__person.gender_source_value`. `data_table_filter: array` |
| `age_group__who_primary_classification` | varchar(255) | Age band at the attendance date (BL-004). `data_table_filter: array` |
| `triage_score` | text | `'1'`–`'5'` or `'Not recorded'` (BL-012). Always populated (AC-011). `data_table_filter: array` |
| `ed_time__minutes` | numeric | Time in the ED in minutes, 2 dp (BL-015). NULL while the patient is in the ED. A measure, so no filter |
| `ed_time__4_hours_band` | text | `'< 4 hours'`, `'4 or more hours'` or `'Unknown'` (BL-015). Always populated (AC-015). `data_table_filter: array` |
| `discharge_disposition` | text | How the encounter ended, or `'Not recorded'` (BL-017). Always populated (AC-017). `data_table_filter: array` |

## Business logic

BL-003, BL-004, BL-007, BL-010, BL-011 and BL-012 are implemented in
`int__emergency_visits` and specified in `metric__emergency_visit.md`. The clauses
below are this model's own.

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (the stay period):** `period_start` is `ed_start__datetime` and `period_end` is
  `ed_end__datetime` from `int__emergency_visits` — the ED intake segment's bounds — at
  `'minute'` granularity.

  Departure is departure from the emergency department, whether an internal transfer to an
  inpatient bed or a discharge straight from the ED. For an admitted patient the encounter runs
  on to hospital discharge, which `metric__emergency_visit` measures.

  Time in the ED is `period_end - period_start`, computed by the consumer at its own grain
  (BL-006). `period_end` is nullable — NULL means the patient is in the ED with no transfer
  planned (BL-018) — so AC-004 covers `period_start` only and AC-012 asserts ordering where
  `period_end` is present.
- **BL-006 (durations are the consumer's):** the model emits counts; any average, median or
  percentile of time in the ED is computed from `period_start` and `period_end` at the consumer's
  grain.
- **BL-008 (materialisation is env-aware):** `table` when `target.name` starts with `analytics`,
  `view` otherwise, set on the `metrics:` block in `dbt_project.yml`.
- **BL-009 (facility identity is Tamanu's):** the model emits `facility_id`, the Tamanu id.
  Consumer-specific identifiers are resolved in the consumer layer.
- **BL-015 (time in the ED):** the duration is reported two ways. `ed_time__minutes` is
  `period_end - period_start` in minutes; `ed_time__4_hours_band` splits it at four
  hours into `'< 4 hours'`, `'4 or more hours'`, or `'Unknown'` where `period_end` is NULL.

  `ed_time__minutes` is a **measure, not a dimension**: continuous, so it carries no
  `data_table_filter` and is absent from the registry's disaggregations. It is held to 2 dp on
  the same basis as `metric__emergency_visit`'s `waiting_time__minutes`, and is NULL on the
  rows the band reports as `'Unknown'` (AC-019 asserts non-negative where present).

  The column names its threshold, so a different split added later reads as a different column;
  `metric__emergency_visit` bands total length of stay as `length_of_stay__4_hours_band`.
  `'Unknown'` marks a patient still in the ED and belongs in a count of current activity.
- **BL-017 (discharge disposition):** `discharge_disposition` is the disposition name on the
  encounter's discharge record, through `bases/discharges` → `bases/reference_data`, or
  `'Not recorded'` where there is no discharge record (AC-017).

  **It is encounter-grained, while this model's period is ED-grained.** For a stay discharged from
  the ED the two coincide; for an admitted stay the disposition describes the later hospital
  discharge, recorded after `period_end`, so read it as the encounter's outcome rather than the
  ED's. `metric__emergency_visit`'s `is_admitted` separates the two cases.

  `'Not recorded'` therefore covers an open encounter as well as a missing record, and is expected
  to be common for recent admitted stays. Values are whatever the deployment's disposition
  reference data holds, so the column is open-vocabulary and its test is `not_null` alone.
  `bases/discharges` is `distinct on (encounter_id)`, so the join yields one row per encounter.
- **BL-018 (planned location as the departure):** where the ED segment carries no end,
  `encounters.planned_location_start_datetime` supplies the departure, because an encounter booked
  to transfer out of the ED is settled at that time even though the next segment is unrecorded. A
  recorded `visit_detail_end_datetime` always takes precedence, and the join to `bases/encounters`
  is on the primary key so it yields one row per attendance.

  **This applies to currently-open segments only, because `encounters` holds current state.** A
  segment ends on any department, location or `encounter_type` change (`clinical__visit_detail`
  BL-001), so an attendance whose transfer has happened has a closed segment and takes its
  departure from there.

  **A planned time in the future produces a planned duration.** The model reads no clock (BL-002),
  so it treats an elapsed plan and a pending one alike — which is what makes a projected four-hour
  breach visible. Without the fallback, every attendance awaiting an unrecorded transfer would band
  as `'Unknown'`.

**OQ-001 — historical planned-location transitions.** `encounters` carries only the *current*
planned location, and `encounter_history` omits the field entirely. An attendance whose transfer
took effect without a history event, and whose plan was then cleared, has no recoverable departure
and bands as `'Unknown'`. Reconstructing when the change occurred needs `logs.changes`, which this
model does not read. If `'Unknown'` proves a large share of closed ED activity in deployment data,
a `logs.changes`-based history model is the fix.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-011 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `ed_stay` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-006, BL-011 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-007 | `not_null` |
| AC-008 | `subject_id` is `not_null` | BL-011 | `not_null` |
| AC-009 | The shared base resolves as specified, including that a segment with no end takes its departure from `planned_location_start_datetime` and that a recorded end takes precedence over the plan | BL-003–BL-005, BL-012–BL-018 | unit test `ac_009_int__emergency_visits_derivations` |
| AC-011 | `triage_score` is `not_null` | BL-012 | `not_null` |
| AC-012 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-015 | `ed_time__4_hours_band` is `not_null` and one of the three labels | BL-015 | `not_null` + `accepted_values` |
| AC-017 | `discharge_disposition` is `not_null` | BL-017 | `not_null` |
| AC-018 | `period_end` is the ED departure rather than the encounter end; the band is time in the ED; disposition passes through; an open stay yields NULL `period_end` and an `'Unknown'` band | BL-002, BL-015, BL-017 | unit test `ac_018_metric__emergency_stay_projection` |
| AC-019 | `ed_time__minutes` is non-negative where present | BL-015 | `dbt_expectations.expect_column_values_to_be_between` |

AC numbers are shared with `metric__emergency_visit` wherever a criterion covers the same
clause, so every criterion is findable by the test name that carries its number. BL-018 is
implemented in the shared base, so AC-009 — the base's own criterion — asserts it for both
models.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__emergency_visits` | `intermediate/omop/` | The whole attendance base: inclusion, span, triage, disposition |
| `age_group__who_primary_classification` | `macros/` | Age banding (BL-004) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table over this view, backing Emergency cards on time in the ED and discharge disposition (MAUI-6694) |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric` for counts and compute durations from the period columns;
   `count(distinct subject_id)` is equally valid for counts.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   minute-resolution timestamps, so a monthly card applies `date_trunc('month', period_start)` and
   filters the current month itself.
3. **Carry the time component across the JSON boundary.** The Tupaia data table renders a Postgres
   `date` as `'YYYY-MM-DD'` text to avoid node-postgres shifting it a day on UTC serialisation.
   That truncates the time and makes duration uncomputable, so both period columns must be
   rendered as `'YYYY-MM-DD HH24:MI'` or an epoch.
4. **Handle a NULL `period_end`.** A duration visual filters those rows out; a count visual must
   keep them.
5. **Count `ed_stay` or `ed_visit`, not both.** They cover the same attendances.

## Related

| Artefact | Relationship |
|---|---|
| `metric__emergency_visit` | Same rows, same base; measures total length of stay and arrival-side attributes |
| `int__emergency_visits` | The shared base both metrics project |
| `ds__emergency_triage` | Report-layer emergency dataset at triage grain, with PII. Source of the waiting-time and disposition logic these metrics reuse |
| MAUI-6694 | Queen of Sheba Hospital, Ghana — Hospital Administration → Emergency |

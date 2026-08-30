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
| **Linear issue** | [MAUI-6787](https://linear.app/bes/issue/MAUI-6787) |
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

**Who reads it.** Tupaia "Hospital Administration → Emergency" dashboard cards, via a data table
over this view.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| The stay period | AIHW | [472757](https://meteor.aihw.gov.au/content/472757) | Emergency department stay — "the period between when a patient presents at an emergency department and when that person is recorded as having physically departed" |
| `period_start` | AIHW | [746091](https://meteor.aihw.gov.au/content/746091) / [746096](https://meteor.aihw.gov.au/content/746096) | ED stay — presentation date / time |
| `period_end` | AIHW | [746076](https://meteor.aihw.gov.au/content/746076) / [746081](https://meteor.aihw.gov.au/content/746081) | ED stay — physical departure date / time |

The AIHW object class defines this model's period exactly. AIHW registers no length-of-stay
element, so the duration is a BES composition over that concept.

**DV-001 — physical departure.** AIHW's `period_end` is when the patient is recorded as having
*physically departed*. BL-018 resolves that from the first segment at a different `care_site_id`,
so boarding time counts toward the stay: an `encounter_type` change to `admission` no longer ends
it. Two residual gaps remain against the AIHW definition. A booked transfer that has not yet
happened stands in for the move, so those rows carry a planned rather than an observed departure.
And a location change is recorded when the patient's location is *updated*, which may lag the
moment they physically left the department.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity — a duplicate
would double-count a stay in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id, matching the registry's `subject_grain: visit`, and
is unique because only the ED intake segment is counted (BL-003). Each of a patient's stays is an
independent row (BL-010).

## Output schema

D5 wide format, plus four disaggregation columns and one measure attribute.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_stay`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | Encounter id (BL-011). `not_null` (AC-008) |
| `period_start` | timestamp | Arrival in the ED (BL-002) |
| `period_end` | timestamp | Departure from the ED, resolved by BL-018. NULL only while the patient is in the ED with nothing booked and the encounter open |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL — this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Intake segment's facility (BL-007) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at arrival (BL-004). A measure, not a dimension |
| `triage_score` | text | `'1'`–`'5'` or `'Not recorded'` (BL-012). Always populated (AC-011) |
| `ed_time__minutes` | numeric | Time in the ED in minutes, 2 dp (BL-015). NULL while the patient is in the ED. A measure, not a dimension |
| `discharge_disposition` | text | How the encounter ended, or `'Not recorded'` (BL-017). Always populated (AC-017) |

## Data tables

The Tupaia data tables over this view are configured in `tupaia-data-product`, at
`tamanu/data_tables/`, one file per data table — see `metric__emergency_visit.md` § Data tables
for why they live there.

`emergency_stay__standard.yml` is the one BES ships. It ranges `period_start` as a date; exposes
`metric_id`, `facility_id`, `sex`, `triage_score` and `discharge_disposition` as array filters;
bands `age_group__who_primary_classification` from `age_years` and `ed_time__4_hours_band` from
`ed_time__minutes`; and sums `value_numeric`. `period_end` is not exposed — a patient still in
the department has none, and an array filter drops a NULL row.

This model therefore carries no `data_table_*` meta.

## Business logic

BL-003, BL-004, BL-007, BL-010, BL-011 and BL-012 are implemented in
`int__emergency_visits` and specified in `metric__emergency_visit.md`. The clauses
below are this model's own.

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (the stay period):** `period_start` is `ed_start__datetime`, the ED intake segment's
  start, and `period_end` is `ed_end__datetime`, the departure resolved by BL-018 — at `'minute'`
  granularity.

  Departure is departure from the emergency department, whether an internal transfer to an
  inpatient bed or a discharge straight from the ED. For an admitted patient the encounter runs
  on to hospital discharge, which `metric__emergency_visit` measures.

  Time in the ED is `period_end - period_start`, computed by the consumer at its own grain
  (BL-006). `period_end` is nullable — NULL means the patient is in the ED with nothing booked
  and the encounter still open — so AC-004 covers `period_start` only and AC-012 asserts ordering
  where `period_end` is present.
- **BL-006 (durations are the consumer's):** the model emits counts; any average, median or
  percentile of time in the ED is computed from `period_start` and `period_end` at the consumer's
  grain.
- **BL-008 (materialisation is env-aware):** `table` when `target.name` starts with `analytics`,
  `view` otherwise, set on the `metrics:` block in `dbt_project.yml`.
- **BL-009 (facility identity is Tamanu's):** the model emits `facility_id`, the Tamanu id.
  Consumer-specific identifiers are resolved in the consumer layer.
- **BL-015 (time in the ED):** `ed_time__minutes` is `period_end - period_start` in minutes,
  held to 2 dp on the same basis as `metric__emergency_visit`'s `waiting_time__minutes`. NULL
  where `period_end` is (AC-019 asserts non-negative where present).

  Unbanded, per `metric__emergency_visit.md` BL-019: a four-hour split is a presentation choice a
  deployment may set differently, so the consumer's data table bands this column.
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
- **BL-018 (resolving the departure):** `period_end` is the **earliest** of two signals that the
  patient left the emergency department, falling through to the encounter end when neither is
  present:

  1. the start of the first later segment at a **different `care_site_id`** — the physical move
  2. `encounters.planned_location_start_datetime` — the time a booked transfer takes effect
  3. `clinical__visit_occurrence.visit_end_datetime` — the encounter ended in the ED

  **A segment boundary is not by itself a departure.** A segment ends on any department, location
  or `encounter_type` change (`clinical__visit_detail` BL-001), so an `encounter_type` change to
  `admission` closes the intake segment while the patient is still physically in the ED. Taking
  that boundary as the departure would end the stay at the admission decision and hide boarding
  time entirely — which is the delay a four-hour measure exists to expose. Only a change of
  `care_site_id` counts.

  `least()` ignores NULLs, so whichever signal exists wins and the earlier wins when both do.
  The physical move is the stronger evidence, but a plan that precedes it is taken as the moment
  ED care concluded. Step 3 covers a discharge straight from the ED and any encounter that never
  moved. `period_end` is NULL only where the patient is in the ED with nothing booked and the
  encounter is still open.

  The location-exit CTE is grouped to one row per encounter and `bases/encounters` is joined on its
  primary key, so neither can fan out.

  **A booked time in the future produces a planned duration.** The model reads no clock (BL-002),
  so it treats an elapsed plan and a pending one alike — which is what makes a projected four-hour
  breach visible.

**OQ-001 — a move recorded without a segment.** `encounters` carries only the *current* planned
location and `encounter_history` omits the field, so no historical plan change is recoverable
without `logs.changes`, which this model does not read. Where a patient left the ED but no
location-change segment was written and any plan was since cleared, BL-018 falls through to the
encounter end and **overstates** time in the ED for that stay. How often that happens is a
question for deployment data; if it is common, a `logs.changes`-based history model is the fix.

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

| AC-017 | `discharge_disposition` is `not_null` | BL-017 | `not_null` |
| AC-018 | `period_end` is the ED departure rather than the encounter end; disposition passes through; an open stay yields a NULL `period_end` | BL-002, BL-015, BL-017 | unit test `ac_018_metric__emergency_stay_projection` |
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
| `tupaia-data-product` `tamanu` source | Data table `emergency_stay__standard`, backing Emergency cards on time in the ED and discharge disposition |

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

# dbt Model Spec: `metric__emergency_visit` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__emergency_visit` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else (BL-008) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.54`) |
| **Linear issue** | [MAUI-6694](https://linear.app/bes/issue/MAUI-6694) / [MAUI-6787](https://linear.app/bes/issue/MAUI-6787) |
| **Created** | 2026-08-11 |
| **Last updated** | 2026-08-19 |

Canonical definition for `ed_visit`: one row per ED attendance, spanning arrival in the ED
to discharge from hospital at minute resolution.

## Purpose

Emergency department activity at a Tamanu facility, one row per attendance.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_visit` | count | ED attendances (always 1 per row; `is_admitted` splits by outcome) |

**Clinical context.** In Tamanu an ED arrival that is later admitted is a single encounter whose
type changes over time. Counting attendances therefore means counting encounters that *started*
in the ED — counting encounters currently typed as emergency would drop every admitted-via-ED
patient at the moment of admission.

**Who reads it.** The Tupaia "Hospital Administration → Emergency" dashboard for Queen of Sheba
Hospital (MAUI-6694), via a data table over this view.

`metric__emergency_stay` covers the same rows over the ED portion of the stay; that spec's
§ Purpose carries the division of labour.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `period_start` | AIHW | [746091](https://meteor.aihw.gov.au/content/746091) / [746096](https://meteor.aihw.gov.au/content/746096) | ED stay — presentation date / time |
| `is_admitted` | AIHW | [746706](https://meteor.aihw.gov.au/content/746706) | Non-admitted patient ED service episode — episode end status |
| `principal_diagnosis_code` / `principal_diagnosis` | AIHW | [746102](https://meteor.aihw.gov.au/content/746102) | ED stay — principal diagnosis, "established at the conclusion of the patient's attendance … mainly responsible for occasioning the attendance". Coded ICD-10-AM in AIHW implementations, whose chapters match WHO ICD-10. Emitted here as the raw code and its reference-data name; grouping into a chapter is a deployment-layer concern (BL-013, BL-019) |
| `waiting_time__minutes` | AIHW | [746117](https://meteor.aihw.gov.au/content/746117) | ED stay — waiting time. Diverges — DV-001 |

AIHW's [Emergency department stay](https://meteor.aihw.gov.au/content/472757) object class runs
from presentation to physical departure from the ED, which is `metric__emergency_stay`'s period;
this model runs its period on to hospital discharge (BL-002). AIHW registers no length-of-stay
element, so `length_of_stay__minutes` and the per-attendance aggregation are BES compositions
over the AIHW concepts.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity — a duplicate
would double-count an attendance in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id, matching the registry's `subject_grain: visit`, and
is unique because only the intake segment is counted (BL-003) — so `count(distinct subject_id)`
and `sum(value_numeric)` agree. It identifies the encounter, so each of a patient's attendances
is an independent row; that is what keeps the model unrestricted (BL-010) and scopes it to
attendance counts rather than distinct patients.

## Output schema

D5 wide format, plus five disaggregation columns and five measure attributes.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_visit`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | Encounter id (BL-011). `not_null` (AC-008) |
| `period_start` | timestamp | Arrival in the ED (BL-002) |
| `period_end` | timestamp | Encounter end — hospital discharge. NULL while the encounter is open (BL-002) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL — this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Intake segment's facility (BL-007). Tamanu ids are varchar, not `uuid` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at arrival (BL-004). A measure, not a dimension |
| `triage_score` | text | `'1'`–`'5'` or `'Not recorded'` (BL-012). Always populated (AC-011) |
| `principal_diagnosis_code` | text | Raw ICD-10 code of the principal diagnosis, ungrouped (BL-013). NULL where none is recorded. A measure, not a dimension |
| `principal_diagnosis` | text | Reference-data name for `principal_diagnosis_code` (BL-013). NULL where none is recorded. A measure, not a dimension |
| `waiting_time__minutes` | numeric | Triage to active care, 2 dp (BL-014). NULL until the patient is seen. A measure, not a dimension |
| `length_of_stay__minutes` | numeric | Arrival to hospital discharge, in minutes (BL-015). NULL while the encounter is open. A measure, not a dimension |
| `ed_start__hour` | integer | Local hour of arrival, 0–23 (BL-016). Always populated (AC-016) |
| `is_admitted` | boolean | Went on to an inpatient admission (BL-005). Always populated (AC-010) |

## Data tables

The Tupaia data tables over this view are configured in `tupaia-data-product`, at
`tamanu/data_tables/`, one file per data table. They live there rather than here because the
filter types, the aggregation and the bands are all the consumer's vocabulary — only the model
name points at dbt — and because it keeps a data table's whole configuration, permission groups
included, in one repo.

`emergency_visit__standard.yml` is the one BES ships. It ranges `period_start` as a date;
exposes `metric_id`, `facility_id`, `sex`, `triage_score`, `ed_start__hour` and `is_admitted`
as array filters; groups `principal_diagnosis__icd10_chapter` from `principal_diagnosis_code`
using the `diagnosis__icd10_chapter` macro (defined here in `macros/` for the deployment layer
to reuse, but invoked only there — the same division of labour as banding age), bands
`age_group__who_primary_classification` from `age_years` and `length_of_stay__4_hours_band`
from `length_of_stay__minutes`; and sums `value_numeric`. `period_end` is not exposed — an
open encounter has none, and an array filter drops a NULL row.

`tupaia-data-product/validate_data_tables.py` checks each file against this project's dbt
manifest, so a column renamed here fails there at generate time rather than emptying a
dashboard. This model therefore carries no `data_table_*` meta.

## Business logic

BL-003, BL-004, BL-005, BL-007 and BL-010 through BL-018 are implemented in
`int__emergency_visits`, shared with `metric__emergency_stay`.

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (reporting period):** `period_start` is arrival in the ED
  (`clinical__visit_detail.visit_detail_start_datetime` for the intake segment) and `period_end`
  is the encounter end (`clinical__visit_occurrence.visit_end__datetime`), at `'minute'`
  granularity.

  Total length of stay is `period_end - period_start`, spanning the inpatient episode for an
  admitted attendance. `metric__emergency_stay` measures the ED portion instead.

  `period_end` is nullable — NULL means the encounter is open — so AC-004 covers `period_start`
  only and AC-012 asserts ordering where `period_end` is present.

  Every attendance is emitted as it happens; the model reads no clock, and a consumer needing
  whole periods applies its own date filter. A period with no attendance emits no row.
- **BL-003 (inclusion + intake attribution):** an attendance is the **first** segment of an
  encounter (`preceding_visit_detail_id is null`) whose `visit_detail_concept_id = 9203`, which
  covers `emergency`, `triage` and `observation` via `map__omop_visit_type`.

  Anchoring on the first segment counts one row per arrival and is complete: Tamanu encounters
  never return from `admission` to an ED phase, so any encounter with an ED segment has one
  first. An encounter that starts elsewhere and passes through an ED phase later is
  intra-hospital movement, out of scope.

  The `clinical__visit_detail` CTE is declared `not materialized`. It is referenced three times,
  so Postgres would otherwise materialise it and plan the rest of the model against an opaque
  scan with no statistics — every row estimate collapses to 1 and the joins below turn into
  nested loops that never finish on a deployment-sized encounter history.
- **BL-004 (sex + age):** `sex` is `clinical__person.gender_source_value`; `age_years` is age in
  whole years at arrival, unbanded (BL-019). The join to `clinical__person` is **inner**, so an
  attendance whose patient `bases/patients` excludes as soft-deleted or merged away is excluded
  rather than counted with blank demographics.
- **BL-005 (admitted outcome):** `is_admitted` is true where the encounter's visit-level OMOP
  concept is **262**, which `clinical__visit_occurrence` BL-002 assigns to an admission whose
  history contains an ED phase. It is coalesced to `false` because a NULL would be dropped by
  Tupaia's array filter (AC-010).

  262 exists only at visit grain, reachable in `map__omop_visit_type` solely through the
  synthetic `admission_from_emergency` code, hence the join to `clinical__visit_occurrence`. That
  join is **inner**, a dormant exclusion where an encounter's current `encounter_type` is
  unmapped — guarded upstream by `data_test__map__omop_visit_type_coverage`.
- **BL-006 (the rate is the consumer's):** the model emits counts; the admission rate is
  `sum(value_numeric) filter (where is_admitted) / sum(value_numeric)` at the consumer's grain.
  Per D5 "Rate scale" a rate is a 0–1 fraction, unrounded — presentation layers scale it.
- **BL-007 (facility attribution):** `facility_id` is the intake segment's location resolved
  through `bases/locations` on `care_site_id`. The join is **inner**, so an encounter whose
  location does not resolve is excluded rather than attributed to a NULL facility.

  Facility is the only place dimension; a consumer needing area joins `bases/location_groups`.
- **BL-008 (materialisation is env-aware):** `table` when `target.name` starts with `analytics`,
  `view` otherwise, set on the `metrics:` block in `dbt_project.yml`. A deployment repo must
  **name** a replica target `analytics*` to get tables; `clone` / `demo` / `replica` resolve to
  views.
- **BL-009 (facility identity is Tamanu's):** the model emits `facility_id`, the Tamanu id.
  Consumer-specific identifiers — a Tupaia entity code, a DHIS2 org unit — are resolved in the
  consumer layer.
- **BL-010 (classification):** `pii: false`, `classification: internal`, with no
  `facilities.is_sensitive` filter, so standard and sensitive facilities alike are covered. A row
  carries an encounter id as its only identifier.

  `triage_score` comes from `bases/triages`, which is `classification: restricted` — but that
  covers the whole triage record including chief-complaint text and practitioner id, whereas an
  acuity category alone identifies nobody.

  **The line this sets.** Adding a column that identifies the *patient* — patient id, birth date,
  diagnosis, exact arrival timestamp — requires revisiting the `is_sensitive` filter and the
  `meta` flags. `ds__encounters_emergency` carries such detail and is classified accordingly.
- **BL-011 (per-attendance grain):** one row per attendance, `subject_id` = the encounter id,
  `value_numeric` = literal `1` because the row *is* the attendance. The visit occurrence id is used
  rather than `visit_detail_id` because the registry's `subject_grain` is `visit` and the two are
  one-to-one here.
- **BL-012 (triage acuity):** `triage_score` is `triages.score` for the encounter, left joined on
  `triages.encounter_id` so an attendance with no triage record still counts.

  `'Not recorded'` collapses two cases — no triage record, and a record whose score is blank
  (`triages.score` is nullable text) — because both mean "no acuity known". It is never NULL
  (AC-011).

  The left join relies on Tamanu recording at most one triage per encounter
  (`emergency-triage-line-list.md` BL-001); nothing in `bases/triages` enforces it, so AC-001 is
  the backstop. Scores pass through as recorded.
- **BL-013 (principal diagnosis, ungrouped):** `principal_diagnosis_code` and
  `principal_diagnosis` are the encounter's principal diagnosis — `clinical__condition_occurrence`
  where `is_primary` — as the raw ICD-10 code (`condition_source_value`) and its reference-data
  name (`condition_source_name`), passed through as recorded.

  Grouping either one into a chapter, block or any other classification is a presentation choice
  a deployment may set differently, so it is not done here — the same division of labour as
  `age_years` (BL-019). The `diagnosis__icd10_chapter` macro that used to run in this model stays
  defined in `macros/` for a deployment's data table to apply over `principal_diagnosis_code`
  itself, exactly as `age_group__who_primary_classification` is applied over `age_years` there.

  Both columns are NULL where the encounter has no principal diagnosis — neither is coalesced to
  a placeholder, since they are measures rather than disaggregations exposed as a Tupaia array
  filter (unlike `triage_score`, which is).

  Tamanu permits a second `is_primary` row, so the CTE takes `distinct on (visit_occurrence_id)`
  ordered by `(condition_start_datetime, condition_occurrence_id)` — without it a second principal
  diagnosis would duplicate the attendance and fail AC-001. It is `distinct on` rather than a rank
  filter on the join because Postgres only removes or hash-joins a left join whose right side it
  can prove unique, and a `row_number() = 1` join condition is not provable — the planner
  nested-looped the diagnosis subplan once per attendance, and no consumer that scanned the model
  in full could finish.
- **BL-014 (waiting time):** `waiting_time__minutes` is the wait to active care —
  `triages.closed_datetime - triages.triage_datetime`, the same rule as `ds__emergency_triage`
  BL-005 — expressed in minutes.

  It is a **measure, not a dimension**: continuous, so it is absent from the registry's
  disaggregations and no data table exposes it as a filter. It is held to 2 dp because minutes from whole
  seconds is a repeating decimal, and is NULL until the patient is seen (AC-019 asserts
  non-negative where present).

  **Compliance against a target is the consumer's.** The model emits the wait, not a verdict on
  it; a consumer compares the column to the deployment's target for the row's `triage_score`,
  which `var('triage_target_minutes')` holds. Emitting the duration rather than a pass/fail keeps
  mean, median and percentile wait available from the same column.

  **Carrying a second measure deviates from D5**, which gives one `value_numeric` slot per row. A
  second `metric_id` holding the wait would split the one-row-per-attendance grain AC-001 rests
  on, so the wait rides alongside as an attribute.

  **DV-001 — waiting time start point.** AIHW [746117](https://meteor.aihw.gov.au/content/746117)
  measures presentation to commencement of clinical care; this measures **triage** to
  commencement, inherited from `ds__emergency_triage`, so the presentation-to-triage interval is
  excluded and the wait is understated against AIHW. Aligning it would move numbers on an existing
  report, so it is recorded rather than changed unilaterally.
- **BL-015 (total length of stay):** `length_of_stay__minutes` is `period_end - period_start`
  in minutes, held to 2 dp on the same basis as `waiting_time__minutes`, and unbanded (BL-019).
  It is NULL while the encounter is open, and `metric__emergency_stay` measures the ED portion
  as `ed_time__minutes`.
- **BL-019 (banding/grouping is the consumer's):** the metrics emit continuous or raw values and
  register no banded or grouped column. An age classification, a four-hour duration split and an
  ICD-10 chapter grouping are all presentation choices a deployment may set differently — WHO
  primary bands against five-year bands, four hours against six, ICD-10 chapter against block or
  a national grouping — so doing any of them in the warehouse would either freeze one choice or
  need a column per variant.

  `age_years`, `waiting_time__minutes`, `ed_time__minutes`, `length_of_stay__minutes`,
  `principal_diagnosis_code` and `principal_diagnosis` are therefore measures rather than
  dimensions, absent from the registry's disaggregations. The data table declares the bands or
  groupings it wants over them, in `tupaia-data-product` — including `diagnosis__icd10_chapter`
  over `principal_diagnosis_code`, which stays defined in this repo's `macros/` purely for that
  reuse.

  This is why a deployment can change its banding or grouping without a change here, and why two
  deployments banding or grouping differently still share one metric definition.
- **BL-016 (hour of arrival):** `ed_start__hour` is the hour of `period_start`, 0–23, as an
  integer so it sorts and buckets naturally. Tamanu stores naive timestamps in the deployment's
  central timezone (`var('timezone')`), so this is already a local hour; a deployment spanning
  timezones gets the central zone's hour.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-011 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `ed_visit` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-006, BL-011 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-007 | `not_null` |
| AC-008 | `subject_id` is `not_null` | BL-011 | `not_null` |
| AC-009 | The shared base resolves as specified: intake segment and concept 9203 only, `is_admitted` on concept 262, triage, diagnosis, disposition and every derived timing, including a second `is_primary` row not duplicating the attendance | BL-003–BL-005, BL-012–BL-018 | unit test `ac_009_int__emergency_visits_derivations` |
| AC-010 | `is_admitted` is `not_null` | BL-005 | `not_null` |
| AC-011 | `triage_score` is `not_null` | BL-012 | `not_null` |
| AC-012 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-013 | *Retired* — was `principal_diagnosis__icd10_chapter` `not_null`; the column no longer exists (BL-013 now emits raw, nullable `principal_diagnosis_code`/`principal_diagnosis`) | BL-013 | — |
| AC-015 | `length_of_stay__minutes` is non-negative where present | BL-015 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-016 | `ed_start__hour` is `not_null` and between 0 and 23 | BL-016 | `not_null` + `dbt_expectations.expect_column_values_to_be_between` |
| AC-018 | The D5 projection: `period_end` is the encounter end, the diagnosis code and name pass through ungrouped, an open encounter yields NULL `period_end` | BL-002, BL-011, BL-013 | unit test `ac_018_metric__emergency_visit_projection` |
| AC-019 | `waiting_time__minutes` is non-negative where present | BL-014 | `dbt_expectations.expect_column_values_to_be_between` |

AC numbers are shared with `metric__emergency_stay` wherever a criterion covers the same clause.

## Registry entry

One active row — `ed_visit`, `kind: metric`, `subject_grain: visit`, `status: approved`,
`spec_path` pointing here, with
`disaggregations: facility_id,sex,triage_score,ed_start__hour,is_admitted`.

Every disaggregation is in the allowlist in `assert__metric_definitions__disaggregations`, which
keeps the registry and the model from drifting.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__emergency_visits` | `intermediate/omop/` | The shared base; every ref below is reached through it |
| `clinical__visit_detail` | `clinical/` | Intake segment: inclusion, arrival, location, encounter id (BL-003, BL-007, BL-011) |
| `clinical__visit_occurrence` | `clinical/` | Encounter end (BL-002) and concept 262 (BL-005) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-004) |
| `clinical__condition_occurrence` | `clinical/` | Principal diagnosis code and reference-data name (BL-013) |
| `locations` | `bases/` | Facility of the intake segment's location (BL-007) |
| `triages` | `bases/` | Acuity, and the wait and target verdict (BL-012, BL-014) |
| `age_group__who_primary_classification` | `macros/` | Age banding — applied at the deployment layer, not by this model (BL-004, BL-019) |
| `diagnosis__icd10_chapter` | `macros/` | ICD-10 chapter grouping over `principal_diagnosis_code` — applied at the deployment layer, not by this model (BL-013, BL-019) |
| `triage_target_minutes_case` | `macros/` | Target minutes per category (BL-014) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table `tamanu_qos__emergency_care`, backing three Emergency cards for Queen of Sheba (MAUI-6694) |

Those cards use metric-agnostic templates (`line__metric_count`, `bar__metric_split`,
`line__metric_ratio`) parameterised by metric id, so any deployment materialising this model gets
them from configuration alone.

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid and safer if
   the consumer's own SQL might fan rows out.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   minute-resolution timestamps, so a monthly card applies `date_trunc('month', period_start)` and
   filters the current month itself.
3. **Compare `waiting_time__minutes` to your own target** for the row's `triage_score` (BL-014),
   and keep `'Unknown'` (BL-015) out of a length-of-stay rate while keeping it in a count of
   attendances.
4. **Carry the time component across the JSON boundary.** The Tupaia data table renders a Postgres
   `date` as `'YYYY-MM-DD'` text to avoid node-postgres shifting it a day on UTC serialisation.
   That truncates the time and makes length of stay uncomputable, so both period columns must be
   rendered as `'YYYY-MM-DD HH24:MI'` or an epoch.
5. **Handle a NULL `period_end`.** A length-of-stay visual filters those rows out; a count visual
   must keep them.
6. **Count `ed_visit` or `ed_stay`, not both.** They cover the same attendances.

## Related

| Artefact | Relationship |
|---|---|
| `metric__emergency_stay` | Same rows, same base; measures time in the ED and carries discharge disposition |
| `int__emergency_visits` | The shared base both metrics project |
| `ds__encounters_emergency` | Report-layer emergency dataset at triage grain, with PII |
| `der__cohort_ncd_6m` | Per-subject derived artefact — the reference for `subject_id` semantics |
| MAUI-6694 | Queen of Sheba Hospital, Ghana — Hospital Administration → Emergency |

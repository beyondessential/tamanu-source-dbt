# dbt Model Spec: `metric__inpatient_admission` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__inpatient_admission` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else (BL-008) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `inpatient_admission`: one row per hospital admission, spanning
becoming an inpatient to discharge from hospital, at minute resolution.

## Purpose

Inpatient (ward) activity at a Tamanu facility, one row per admission.

| `metric_id` | Unit | Measures |
|---|---|---|
| `inpatient_admission` | count | Inpatient admissions (always 1 per row; grouping on `period_start` counts admissions, grouping on `period_end` counts discharges over the same rows — there is no separate discharge `metric_id`) |

**Clinical context.** An admission is counted whether the encounter started that way or became
one later. A direct admission's first segment is already typed as inpatient (concept 9201). An
encounter that arrives via the emergency department and is later admitted is a single encounter
whose type changes over time, so the segment where it becomes an inpatient can be later than the
encounter's first segment. Counting admissions therefore means counting the **earliest segment
of each encounter that is typed as an inpatient visit**, not the encounter's first segment
unconditionally — otherwise an ED-then-admitted encounter would be missed (its first segment is
an ED segment, concept 9203, not 9201).

**Who reads it.** No consumer is registered yet — this is a generic definition, to be wired to
a Tupaia data table (`tupaia-data-product`) or Tamanu report once a deployment requests it, via
a metric-agnostic Tupaia template parameterised by `metric_id`.

This repo already has an unrelated, older "admission" concept at
`models/datasets/standard/ds__admissions.sql` (the Tamanu-report-layer admissions line list,
built from raw `encounters`/`encounter_history`, not OMOP). That model is untouched by this
spec — it serves Tamanu's own admissions report, not the D5 metric layer, and the two are not
expected to reconcile row-for-row.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `period_start` | AIHW | [695137](https://meteor.aihw.gov.au/content/695137) | Episode of admitted patient care — admission date |
| `period_end` | AIHW | [270025](https://meteor.aihw.gov.au/content/270025) | Episode of admitted patient care — separation date |
| `is_admitted_via_emergency` / `admission_source` | AIHW | [269976](https://meteor.aihw.gov.au/content/269976) | Episode of admitted patient care — admission mode. Diverges — DV-001 |
| `discharge_disposition` | AIHW | [722644](https://meteor.aihw.gov.au/content/722644) | Episode of admitted patient care — mode of separation |

AIHW's admission/separation concepts are per-episode-of-care (a stay under one care type);
Tamanu's inpatient encounter is not subdivided by care type, so one encounter is one episode
here. `length_of_stay__minutes` is a BES composition over the admission/separation dates.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity — a duplicate
would double-count an admission in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id (the Tamanu encounter id), matching the registry's
`subject_grain: visit`, and is unique because only the admission segment is counted (BL-003) —
so `count(distinct subject_id)` and `sum(value_numeric)` agree. It identifies the encounter, so
a patient with several admissions has one independent row per admission; that is what keeps the
model unrestricted (BL-010).

## Output schema

D5 wide format, plus seven disaggregation/measure columns.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `inpatient_admission`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | Encounter id (BL-011). `not_null` (AC-008) |
| `period_start` | timestamp | Became an inpatient (BL-002) |
| `period_end` | timestamp | Encounter end — hospital discharge. NULL while the encounter is open (BL-002) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL — this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Admission segment's facility (BL-007). Tamanu ids are varchar, not `uuid` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at admission (BL-004). A measure, not a dimension |
| `admission_ward_id` | varchar(255) | Admission segment's department (BL-007). Tamanu id only, same convention as `facility_id` |
| `admission_source` | text | Referral source, or `'Not recorded'` (BL-012). Always populated (AC-011) |
| `is_admitted_via_emergency` | boolean | Had a prior ED/triage/observation phase (BL-005). Always populated (AC-010) |
| `principal_diagnosis__icd10_chapter` | text | WHO ICD-10 chapter, `'Not recorded'` or `'Unclassified'` (BL-013). Always populated (AC-013) |
| `discharge_disposition` | text | `'Not recorded'` or the disposition name (BL-014). Always populated (AC-014) |
| `length_of_stay__minutes` | numeric | Admission to hospital discharge, in minutes (BL-015). NULL while the encounter is open. A measure, not a dimension |

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/inpatient.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (reporting period):** `period_start` is when the patient became an inpatient (the
  admission segment's start) and `period_end` is the encounter end (hospital discharge), at
  `'minute'` granularity.

  `period_end` is nullable — NULL means the encounter is open — so AC-004 covers `period_start`
  only and AC-012 asserts ordering where `period_end` is present.

  Every admission is emitted as it happens; the model reads no clock, and a consumer needing
  whole periods applies its own date filter. Grouping on `period_start` bucketed to a period
  gives admissions in that period; grouping on `period_end` gives discharges — both are the
  same rows, so there is no separate `metric_id` for discharges.
- **BL-003 (inclusion + admission attribution):** an admission is the **earliest** segment of an
  encounter (by `visit_detail_start_datetime`, `visit_detail_id` breaking a tie) whose
  `visit_detail_concept_id = 9201` (Inpatient Visit).

  For a direct admission this is also the encounter's first segment. For an encounter that
  passed through an ED/triage/observation phase first (visit-level concept 262), it is the
  later segment where the patient actually became an inpatient — anchoring on the first segment
  unconditionally, as `int__emergency_visits` does for 9203, would miss every ED-then-admitted
  encounter, whose first segment is typed 9203 not 9201.

  An encounter with no segment at concept 9201 at all (a pure ED or outpatient encounter) is
  excluded — out of scope for this metric.
- **BL-004 (sex + age):** `sex` is `clinical__person.gender_source_value`; `age_years` is age
  in whole years at admission, unbanded — an age classification is a presentation choice a
  deployment may set differently, so the consumer's data table bands it. The join to
  `clinical__person` is **inner**, so an admission whose patient `bases/patients` excludes
  (soft-deleted or merged away) is excluded rather than counted with blank demographics.
- **BL-005 (admitted via emergency):** `is_admitted_via_emergency` is true where the encounter's
  visit-level OMOP concept is **262** (Emergency Room and Inpatient Visit), which
  `clinical__visit_occurrence` assigns to an admission whose history contains an
  emergency/triage/observation phase. Coalesced to `false` because a NULL would be dropped by
  Tupaia's array filter (AC-010).

  This is the inpatient-side mirror of `metric__emergency_visit.is_admitted` — the two flags
  describe the same admissions from opposite ends of the encounter, and are not expected to sum
  to the same total (an admission with no preceding ED phase never appears in
  `metric__emergency_visit` at all).
- **BL-006 (the rate is the consumer's):** the model emits counts; e.g. the share of admissions
  arriving via the ED is `sum(value_numeric) filter (where is_admitted_via_emergency) /
  sum(value_numeric)` at the consumer's grain. Per D5 "Rate scale" a rate is a 0–1 fraction,
  unrounded — presentation layers scale it.
- **BL-007 (facility + ward attribution):** `facility_id` is the admission segment's location,
  resolved through `bases/locations` on `care_site_id`. The join is **inner**, so an admission
  whose location does not resolve is excluded rather than attributed to a NULL facility.

  `admission_ward_id` is the admission segment's `department_id`, carried as the raw Tamanu id
  with no join to resolve a name — same convention as `facility_id` (BL-009). It is nullable:
  an admission segment recorded with no department stays NULL rather than being excluded.
- **BL-008 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, inherited from the `metrics:` block in `dbt_project.yml` —
  no per-model override needed.
- **BL-009 (facility/ward identity is Tamanu's):** the model emits `facility_id` and
  `admission_ward_id`, the Tamanu ids. Consumer-specific identifiers — a Tupaia entity code, a
  DHIS2 org unit or ward mapping — are resolved in the consumer layer.
- **BL-010 (classification):** `pii: false`, `classification: internal`, with no
  `facilities.is_sensitive` filter, so standard and sensitive facilities alike are covered. A
  row carries an encounter id as its only identifier — no patient id, name, birth date or exact
  diagnosis text.
- **BL-011 (per-admission grain):** one row per admission, `subject_id` = the encounter id,
  `value_numeric` = literal `1` because the row *is* the admission.
- **BL-012 (admission source):** `admission_source` is `encounters.referral_source_id` resolved
  through `bases/reference_data`, left joined so an admission with no referral source still
  counts. `'Not recorded'` covers a missing referral source; never NULL, since the data tables
  expose this as an array filter and Tupaia's array filter drops NULL rows.

  **DV-001 — admission mode vs. referral source.** AIHW's admission mode (269976) is a fixed,
  small vocabulary (e.g. transfer from another hospital, statistical admission); Tamanu's
  referral source is a deployment-configured reference-data list with no guaranteed mapping to
  those categories. `is_admitted_via_emergency` covers the one admission-mode category Tamanu
  can derive unambiguously (an ED-preceded admission); `admission_source` is carried as-recorded
  rather than forced into the AIHW vocabulary. Aligning it is deployment-specific mapping work,
  not something this canonical definition can do generically.
- **BL-013 (principal diagnosis chapter):** `principal_diagnosis__icd10_chapter` groups the
  encounter's principal diagnosis — `clinical__condition_occurrence` where `is_primary` —
  through the `diagnosis__icd10_chapter` macro over `condition_source_value`: the earliest
  `is_primary` row wins a tie, and `'Not recorded'` (no principal diagnosis) vs `'Unclassified'`
  (a code that resolves to no chapter) are kept distinct — neither is ever NULL.
- **BL-014 (discharge disposition):** `discharge_disposition` is `discharges.disposition_id`
  resolved through `bases/reference_data`, left joined so an admission with no discharge record
  still counts. `'Not recorded'` covers a missing disposition; never NULL, for the same reason
  as `admission_source`. Mirrors AIHW mode of separation (722644) as a BES composition, not an
  implementation of its coded vocabulary.
- **BL-015 (length of stay):** `length_of_stay__minutes` is `period_end - period_start` in
  minutes, held to 2 dp. NULL while the encounter is open. Unbanded — a length-of-stay band is
  a presentation choice a deployment may set differently, so the metric emits the duration and
  the consumer's data table bands it.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-011 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `inpatient_admission` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-006, BL-011 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-007 | `not_null` |
| AC-008 | `subject_id` is `not_null` | BL-011 | `not_null` |
| AC-009 | The shared base resolves as specified: admission segment selection (incl. an ED-preceded admission), `is_admitted_via_emergency` on concept 262, admission source and discharge disposition fallbacks, principal diagnosis earliest-wins, length of stay, open-encounter handling | BL-003–BL-005, BL-012–BL-015 | unit test `ac_009_int__inpatient_visits_derivations` |
| AC-010 | `is_admitted_via_emergency` is `not_null` | BL-005 | `not_null` |
| AC-011 | `admission_source` is `not_null` | BL-012 | `not_null` |
| AC-012 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-013 | `principal_diagnosis__icd10_chapter` is `not_null` | BL-013 | `not_null` |
| AC-014 | `discharge_disposition` is `not_null` | BL-014 | `not_null` |
| AC-015 | `length_of_stay__minutes` is non-negative where present | BL-015 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-016 | The D5 projection over the shared base: `period_end` is the encounter end, the diagnosis code is grouped to its chapter here, an open encounter yields NULL `period_end` | BL-002, BL-011, BL-013 | unit test `ac_016_metric__inpatient_admission_projection` |

## Registry entry

One active row — `inpatient_admission`, `kind: metric`, `subject_grain: visit`,
`status: draft`, `spec_path` pointing here, with
`disaggregations: facility_id,sex,admission_ward_id,admission_source,is_admitted_via_emergency,principal_diagnosis__icd10_chapter,discharge_disposition`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__inpatient_visits` | `intermediate/omop/` | The shared base; every ref below is reached through it |
| `clinical__visit_detail` | `clinical/` | Admission segment: inclusion, timing, location, department, encounter id (BL-003, BL-007, BL-011) |
| `clinical__visit_occurrence` | `clinical/` | Encounter end (BL-002) and concept 262 (BL-005) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-004) |
| `clinical__condition_occurrence` | `clinical/` | Principal diagnosis code (BL-013) |
| `locations` | `bases/` | Facility of the admission segment's location (BL-007) |
| `encounters` | `bases/` | Referral source (BL-012) |
| `discharges` | `bases/` | Discharge disposition (BL-014) |
| `reference_data` | `bases/` | Referral source and disposition names (BL-012, BL-014) |
| `diagnosis__icd10_chapter` | `macros/` | ICD-10 chapter grouping (BL-013) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

None registered yet — see § Purpose. Once a Tupaia data table or Tamanu report is built over
this view, add it here, and update `documentations/metrics/inpatient.yml` `status` from
`draft` to `approved` once the model output has been reviewed against the registered shape.

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid and safer
   if the consumer's own SQL might fan rows out.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   minute-resolution timestamps.
3. **Carry the time component across the JSON boundary.** The Tupaia data table renders a
   Postgres `date` as `'YYYY-MM-DD'` text to avoid node-postgres shifting it a day on UTC
   serialisation. That truncates the time and makes length of stay uncomputable, so both period
   columns must be rendered as `'YYYY-MM-DD HH24:MI'` or an epoch.
4. **Handle a NULL `period_end`.** A length-of-stay visual filters those rows out; a count
   visual must keep them.
5. **Decide whether to combine with `ed_visit`.** An admission that had a preceding ED phase
   appears in both `metric__emergency_visit` (as `is_admitted = true`) and here (as
   `is_admitted_via_emergency = true`) — a whole-of-hospital-stay view must not double-count it.

## Related

| Artefact | Relationship |
|---|---|
| `metric__emergency_visit` / `metric__emergency_stay` | Cover the ED side of the encounter; `is_admitted` there and `is_admitted_via_emergency` here describe the same admissions from opposite ends |
| `int__inpatient_visits` | The shared base this metric projects |
| `ds__admissions` / `ds__sensitive_admissions` | Unrelated, pre-existing Tamanu-report-layer admissions dataset (raw `encounters`, not OMOP) — not reconciled with this metric |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Should a follow-up `metric__inpatient_transfer` (ward/department transfers within an admission) be added, mirroring `data-staging`'s `ds__inpatient_transfers`? | bes-maui | TBD |
| OQ-002 | Bed occupancy / census (`data-staging`'s `ds__inpatient_census`, `fct_bed_occupancy`) is a point-in-time snapshot, not a per-event grain — it does not fit the D5 metric shape used here and would need a date-spine model. Deferred out of scope for this spec. | bes-maui | TBD |
| OQ-003 | Which Tupaia dashboard or Tamanu report is the first consumer, and does it need `admission_ward_id` resolved to a name at the data-table layer (as `principal_diagnosis__icd10_chapter` etc. are)? | bes-maui | TBD |

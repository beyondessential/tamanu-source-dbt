# dbt Model Spec: `metric__inpatient_admission` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__inpatient_admission` (2 registered indicators) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else (BL-008) |
| **Status** | `approved` (BL-001–BL-024 implemented and reviewed; registry status `approved`) |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear** | MAUI-7069 (separations and AIHW length of stay) |

Canonical definition for `inpatient_admission` and `inpatient_separation`: one row per hospital
admission, and one per separation (a finished stay), at minute resolution.

## Purpose

Inpatient (ward) activity at a Tamanu facility: admissions, and separations with their length of
stay in AIHW patient days.

| `metric_id` | Unit | Measures |
|---|---|---|
| `inpatient_admission` | count | Inpatient admissions, dated by when the patient became an inpatient (always 1 per row) |
| `inpatient_separation` | count | Separations — AIHW "hospitalisations" — dated by separation, carrying `patient_days` (always 1 per row). Average length of stay is formed from it by the consumer (BL-023) |

`length_of_stay__minutes` (BES, elapsed time) and `patient_days` (AIHW) are alternative
definitions of length of stay. Both are emitted, and each deployment's consumer chooses which
one it presents.

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
| `patient_days` | AIHW | [270045](https://meteor.aihw.gov.au/content/270045) | Number of patient days |
| Average length of stay | AIHW | [Length of stay](https://www.aihw.gov.au/hospitals/topics/admitted-patient-care/length-of-stay) | Total patient days ÷ hospitalisations, for separations in the period |

AIHW's admission/separation concepts are per-episode-of-care (a stay under one care type);
Tamanu's inpatient encounter is not subdivided by care type, so one encounter is one episode
here (DV-004). `length_of_stay__minutes` is a BES composition over the admission/separation
dates; `patient_days` is the AIHW measure.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity — a duplicate
would double-count an admission in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id (the Tamanu encounter id), matching the registry's
`subject_grain: visit`, and is unique because only the admission segment is counted (BL-003) —
so `count(distinct subject_id)` and `sum(value_numeric)` agree. It identifies the encounter, so
a patient with several admissions has one independent row per admission; that is what keeps the
model unrestricted (BL-010).

## Output schema

D5 wide format, plus the disaggregation/measure columns below. Every column is on both
`metric_id`s unless noted.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | `inpatient_admission` or `inpatient_separation`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | Encounter id (BL-011). `not_null` (AC-008) |
| `period_start` | timestamp | `inpatient_admission`: became an inpatient (BL-002). `inpatient_separation`: separation (BL-020) |
| `period_end` | timestamp | Encounter end — hospital discharge. NULL while the encounter is open (BL-002). Never NULL on `inpatient_separation` |
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
| `is_readmission_within_30_days` | boolean | True where the same patient's immediately preceding admission discharged no more than 30 days before this one started (BL-016). Always populated (AC-017) |
| `clinician` | text | The admission segment's own clinician, resolved to a name (BL-017). Never NULL |
| `clinician_designation` | text | That clinician's designations, comma-separated (BL-018). Never NULL |
| `patient_days` | integer | AIHW patient days (BL-021). Populated on every `inpatient_separation` row; NULL on `inpatient_admission` |
| `is_same_day` | boolean | Admitted and separated on the same date (BL-022). Populated on every `inpatient_separation` row; NULL on `inpatient_admission` |

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
  gives admissions in that period. Separations in a period are `inpatient_separation` (BL-019).
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
- **BL-016 (30-day readmission):** `is_readmission_within_30_days` is true where this patient's
  immediately preceding admission (by `admission_start__datetime`) discharged no more than 30
  days before this one started. The patient identifier used to order admissions against each
  other is internal to `int__inpatient_admission` and is never selected into this model's
  output — the same derive-but-don't-expose pattern BL-004's `age_years` already uses against
  the birth date, so this does not change the BL-010 classification. Coalesced to `false` (never
  NULL, for the same reason as BL-005 and BL-012) where there is no previous admission, the
  previous one is still open (no `visit_end__datetime` to measure the gap from), or the two
  overlap (a data-entry anomaly, not a readmission).
- **BL-017 (clinician attribution):** `clinician` is the admission segment's own
  `provider_id`, resolved to a name through `ref__provider` for an "admissions by clinician"
  card. Never NULL -- falls back to `'Not recorded'`, the same convention `admission_source`
  (BL-012) and `discharge_disposition` (BL-014) use (MAUI-6909).
- **BL-018 (clinician designation):** `clinician_designation` is the designations of that same
  clinician -- their `user_designations`, resolved through `reference_data` of type `designation`
  by the shared `user_designation_names()` macro, alphabetical and joined with `', '`. The macro
  collapses designations to one row per user before the join, so a clinician with several cannot
  fan an admission out. These are the clinician's current designations: Tamanu keeps no history.
  Never NULL -- `'Not recorded'` where the clinician has none or there is no clinician. Kept
  apart from `clinician` so a filter by name is unaffected; a consumer combines the two for
  display (MAUI-6906).
- **BL-019 (separations):** the model emits one `inpatient_separation` row for each
  `inpatient_admission` row whose `period_end` is not NULL, with `value_numeric` = `1`.
- **BL-020 (separation reporting period):** on an `inpatient_separation` row, `period_start` and
  `period_end` are both the separation datetime, the admission row's `period_end`.
- **BL-021 (patient days):** `patient_days` is the separation date minus the admission date in
  whole days, with a minimum of `1`, both dates taken from the naive local timestamps -- or `-1`
  where the separation date is earlier than the admission date (a corrupt period, OQ-005).
- **BL-022 (same-day):** `is_same_day` is true where the admission date and the separation date
  are equal.
- **BL-023 (average length of stay is the consumer's):** average length of stay is
  `sum(patient_days) / sum(value_numeric)` over `inpatient_separation` rows at the consumer's
  grain, excluding any row where `patient_days = -1` (OQ-005); the overnight average is the same
  over rows where `is_same_day` is false.
- **BL-024 (separation disaggregations):** an `inpatient_separation` row carries the same
  `subject_id`, facility, ward, demographic, clinical and clinician columns as its admission row.

## Divergences from AIHW

| ID | AIHW rule | Here |
|---|---|---|
| DV-002 | Leave days are excluded from patient days | Tamanu records no leave of absence, so `patient_days` includes any leave |
| DV-003 | Patient days of unqualified newborns, hospital boarders and posthumous organ procurement are excluded | Tamanu has no flag for any of the three, so none is excluded |
| DV-004 | An episode of admitted care ends on a change of care type (statistical separation) | One encounter is one episode; a care-type change within an encounter does not separate |

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-011 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and one of `inpatient_admission`, `inpatient_separation` | BL-001, BL-019 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-006, BL-011 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-007 | `not_null` |
| AC-008 | `subject_id` is `not_null` | BL-011 | `not_null` |
| AC-009 | The shared base resolves as specified: admission segment selection (incl. an ED-preceded admission), `is_admitted_via_emergency` on concept 262, admission source and discharge disposition fallbacks, principal diagnosis earliest-wins, length of stay, open-encounter handling | BL-003–BL-005, BL-012–BL-015 | unit test `ac_009_int__inpatient_admission_derivations` |
| AC-010 | `is_admitted_via_emergency` is `not_null` | BL-005 | `not_null` |
| AC-011 | `admission_source` is `not_null` | BL-012 | `not_null` |
| AC-012 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-013 | `principal_diagnosis__icd10_chapter` is `not_null` | BL-013 | `not_null` |
| AC-014 | `discharge_disposition` is `not_null` | BL-014 | `not_null` |
| AC-015 | `length_of_stay__minutes` is non-negative where present | BL-015 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-016 | The D5 projection over the shared base: `period_end` is the encounter end, the diagnosis code is grouped to its chapter here, an open encounter yields NULL `period_end` | BL-002, BL-011, BL-013 | unit test `ac_016_metric__inpatient_admission_projection` |
| AC-017 | `is_readmission_within_30_days` is `not_null` | BL-016 | `not_null` |
| AC-018 | `clinician` is `not_null` | BL-017 | `not_null` |
| AC-019 | `clinician_designation` is `not_null`; a clinician with two designations reads both, alphabetical and comma-separated, on one row; none and no clinician read `'Not recorded'` | BL-018 | `not_null` + unit test `ac_009_int__inpatient_admission_derivations` |
| AC-020 | The `inpatient_separation` rows are exactly the `inpatient_admission` rows with a `period_end`, one each, by `subject_id` | BL-019, BL-024 | singular test `data_test__metric__inpatient_admission` (`failed_ac`) |
| AC-021 | On `inpatient_separation`, `period_start` = `period_end` and is `not_null` | BL-020 | singular test `data_test__metric__inpatient_admission` (`failed_ac`) |
| AC-022 | `patient_days` and `is_same_day` are populated on every `inpatient_separation` row, with `patient_days` either `-1` (corrupt period) or `≥ 1`, and both are NULL on every `inpatient_admission` row | BL-021, BL-022 | singular test `data_test__metric__inpatient_admission` (`failed_ac`) |
| AC-023 | Patient days follow METeOR 270045: a stay admitted and separated on one date is 1 day and same-day; an overnight stay under 24 hours crossing midnight is 1 day and not same-day; a stay admitted day 1 and separated day 4 is 3 days; a separation date earlier than the admission date reads `-1` | BL-021, BL-022 | unit test `ac_023_metric__inpatient_admission_patient_days` |
| AC-024 | An open admission emits an `inpatient_admission` row and no `inpatient_separation` row | BL-019 | unit test `ac_023_metric__inpatient_admission_patient_days` |

## Registry entry

Two rows in `documentations/metrics/inpatient.yml`, both `kind: metric`, `unit: count`,
`subject_grain: visit`, `status: approved`, `spec_path` pointing here, with
`disaggregations: facility_id,sex,admission_ward_id,admission_source,is_admitted_via_emergency,principal_diagnosis__icd10_chapter,discharge_disposition,is_readmission_within_30_days,clinician,clinician_designation`:

- `inpatient_admission` — as registered.
- `inpatient_separation` — `definition_source: AIHW`, `definition_source_code: '270045'`, its
  numerator described as separations counted on the separation date, and its description naming
  average length of stay as `sum(patient_days)` over separations (BL-023), linking the AIHW
  length-of-stay page. `is_same_day` is added to its disaggregations.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__inpatient_admission` | `intermediate/omop/` | The shared base; every ref below is reached through it |
| `clinical__visit_detail` | `clinical/` | Admission segment: inclusion, timing, location, department, encounter id (BL-003, BL-007, BL-011) |
| `clinical__visit_occurrence` | `clinical/` | Encounter end (BL-002) and concept 262 (BL-005) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-004) |
| `clinical__condition_occurrence` | `clinical/` | Principal diagnosis code (BL-013) |
| `locations` | `bases/` | Facility of the admission segment's location (BL-007) |
| `encounters` | `bases/` | Referral source (BL-012) |
| `discharges` | `bases/` | Discharge disposition (BL-014) |
| `reference_data` | `bases/` | Referral source and disposition names (BL-012, BL-014) |
| `diagnosis__icd10_chapter` | `macros/` | ICD-10 chapter grouping (BL-013) |
| `ref__provider` | `ref/` | Clinician name of the admission segment's own provider (BL-017) |
| `user_designations`, `reference_data` | `bases/` | That clinician's designations, via `user_designation_names()` (BL-018) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Reads |
|---|---|
| `tupaia-data-product` inpatient data tables (`inpatient_admission__standard`, `__maternity`, `__clinician`, `__clinician_name`) | `inpatient_admission`; its length-of-stay and discharge-disposition cards move to `inpatient_separation` once BL-019–BL-024 land |

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
| `int__inpatient_admission` | The shared base this metric projects |
| `ds__admissions` / `ds__sensitive_admissions` | Unrelated, pre-existing Tamanu-report-layer admissions dataset (raw `encounters`, not OMOP) — not reconciled with this metric |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Should a follow-up `metric__inpatient_transfer` (ward/department transfers within an admission) be added, mirroring `data-staging`'s `ds__inpatient_transfers`? | bes-maui | TBD |
| OQ-002 | Bed occupancy / census (`data-staging`'s `ds__inpatient_census`, `fct_bed_occupancy`) is a point-in-time snapshot, not a per-event grain — it does not fit the D5 metric shape used here and would need a date-spine model. Deferred out of scope for this spec. | bes-maui | TBD |
| OQ-003 | Which Tupaia dashboard or Tamanu report is the first consumer, and does it need `admission_ward_id` resolved to a name at the data-table layer (as `principal_diagnosis__icd10_chapter` etc. are)? | bes-maui | TBD |
| OQ-004 | `is_readmission_within_30_days` (BL-016) counts a readmission to *any* facility in the deployment, not just the discharging one — a patient discharged from one facility and admitted to another 10 days later still counts. Revisit if a consumer specifically wants same-facility-only. | bes-maui | TBD |
| OQ-005 | On release 2.54's data, 502 closed admissions have a recorded discharge earlier than the recorded admission (already flagged by AC-012/AC-015 as WARN). BL-021 reads these as `patient_days = -1` rather than excluding the row, so a consumer must filter `patient_days = -1` out of its average length of stay (BL-023) rather than this being handled upstream. Revisit whether the row should be excluded entirely once the source data issue is understood, and whether `-1` needs promoting to a registered disaggregation of its own. | bes-maui | TBD |

## Change log

| Date | Change |
|---|---|
| 2026-10-29 | BL-019–BL-024: `inpatient_separation` metric_id with AIHW patient days and same-day flag, so average length of stay follows the AIHW definition; BL-002 points separations at it. DV-002–DV-004 record the AIHW rules Tamanu data cannot follow (MAUI-7069). |

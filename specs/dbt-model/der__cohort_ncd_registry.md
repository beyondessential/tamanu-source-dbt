# dbt Model Spec: `der__cohort_ncd_registry` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `der__cohort_ncd_registry` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `der` |
| **Materialisation** | view |
| **Status** | `approved` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-11 |
| **Last updated** | 2026-06-11 |

Canonical definition of the MSF NCD program registry cohort. Registered in
`seeds/metric_definitions.csv` as `cohort_ncd_registry` (kind `cohort`).
Implementations are deployment-specific (see § Implementations).

## Purpose

**What this artefact measures.** A patient-level snapshot of patients enrolled
in the MSF NCD program registry whose clinical status is not waitlist —
denormalised so each row carries identity, demographics, registration
metadata, pivoted NCD condition diagnoses, and the latest exit-survey
information.

**Clinical context.** MSF deployments run a chronic NCD program registry
within Tamanu (`programRegistry-ncdregistry`). Patients are enrolled, given a
clinical status, optionally assigned one or more NCD conditions, and exit the
program via an exit survey. The registry cohort is the canonical "enrolled
NCD patient" surface used by indicator and line-list reporting.

**Who reads it.** NCD indicator chains (active care, cohort evaluation,
diagnoses, measurements), NCD patient line-lists, future Tupaia data tables
on NCD enrolment.

## Grain

**One row per:** patient currently enrolled in the NCD program registry whose
clinical status is not waitlist.

Relies on the Tamanu invariant that `patient_program_registrations` holds at
most one row per `(patient_id, program_registry_id)` — the application
enforces single-registration-per-registry. No explicit dataset-level dedup is
required.

## Output schema

Required canonical columns:

| Column | Type | Notes |
|---|---|---|
| `cohort_id` | text | Constant `'cohort_ncd_registry'`; joins to the seed row |
| `subject_id` | uuid | Same value as `patient_id`; OMOP-lite cohort convention |
| `cohort_start_date` | date | Patient's `active_status_date::date` |
| `cohort_end_date` | date | Patient's `exit_recorded_date::date`; NULL when still in cohort |

Additional canonical columns (deployment implementations preserve these
verbatim):

| Group | Columns |
|---|---|
| Identity / demographics | `id`, `display_id`, `first_name`, `last_name`, `cultural_name`, `date_of_birth`, `sex` |
| Program proxies | `ethnicity_id`, `ethnicity`, `occupation_id`, `occupation` |
| Registration | `registration_date`, `active_status_date`, `clinical_status_id`, `clinical_status`, `registering_facility_id`, `registering_facility` |
| Condition diagnoses (date or null) | `asthma`, `cvd`, `ckd`, `copd`, `diabetes_i`, `diabetes_ii`, `epilepsy`, `hepatitis`, `hiv_aids`, `htn`, `hyperthyroidism`, `hypothyroidism`, `stroke`, `tb` |
| Exit | `exit_recorded_date`, `exit_status`, `exit_explanation` |
| Composite | `address`, `contact_number` |

## Business logic

- **BL-001:** Restrict to registrations where `program_registry_id = 'programRegistry-ncdregistry'`.
- **BL-002:** Exclude patients whose current `clinical_status_id` is `'prClinicalStatus-ncdwaitlist'` (null-safe — `is distinct from` so null statuses are retained). All other clinical statuses are retained so historical-period reporting still picks up the months a patient was in active care.
- **BL-003:** Pivot diagnosed NCD conditions into one column per condition holding the `max(datetime)` for that condition (null if not diagnosed). Recognised conditions: `asthma`, `cvd`, `ckd`, `copd`, `diabetes_i`, `diabetes_ii`, `epilepsy`, `hepatitis`, `hiv_aids`, `htn`, `hyperthyroidism`, `hypothyroidism`, `stroke`, `tb`. Condition pivot is scoped to the NCD program only.
- **BL-004:** For each patient, take the most recent exit-survey response. Populates `exit_recorded_date`, `exit_status`, `exit_explanation`. `exit_recorded_date` and `exit_status` are paired — both null or both non-null.
- **BL-005:** `active_status_date` is the earliest change-log `logged_at` where the patient's NCD registration carried `clinical_status_id = 'prClinicalStatus-ncdactive'`. Canonical "start of care" date used by downstream cohort, active-care, and new-enrolment indicators. Null when the patient has no Active-status row in the change log.
- **BL-006:** `address` is a comma-joined string of non-empty division, subdivision, settlement, village, and street components; null when every component is empty. `contact_number` is a comma-joined string of non-empty primary and secondary contact numbers; null when both are empty.
- **BL-007:** Reference resolutions for IDs (ethnicity, occupation, address levels, clinical status, registering facility) use `left join` so a missing reference yields null rather than dropping the patient. Only the join to the patient record is inner.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `cohort_id = 'cohort_ncd_registry'` on every row | grain | dbt `accepted_values` |
| AC-002 | `id` is `not_null` and `unique` | grain | dbt `not_null` + `unique` |
| AC-003 | `subject_id` equals `id` on every row | grain | dbt `expression_is_true` |
| AC-004 | No row has `clinical_status_id = 'prClinicalStatus-ncdwaitlist'` | BL-002 | dbt `expression_is_true` |
| AC-005 | Condition columns only non-null when the corresponding registration condition row exists | BL-003 | dbt unit test |
| AC-006 | `exit_recorded_date` and `exit_status` are paired (both null or both non-null) | BL-004 | dbt `expression_is_true` |
| AC-007 | When `active_status_date` is non-null, the patient has a change-log Active-status row at that timestamp and no earlier such row | BL-005 | dbt unit test |
| AC-008 | Composite `address` is null when all five source components are null/empty | BL-006 | dbt singular test |
| AC-009 | Composite `contact_number` is null when both source numbers are null/empty | BL-006 | dbt singular test |

## Registry entry

`seeds/metric_definitions.csv` row:

| Column | Value |
|---|---|
| `metric_id` | `cohort_ncd_registry` |
| `kind` | `cohort` |
| `subject_grain` | `patient` |
| `disaggregations` | `sex,facility_id` |
| `definition_source` | `MSF` |
| `status` | `draft` (promotes to `approved` once a canonical implementation lands in `tamanu-source-dbt`) |

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| MSF Syria | `tamanu-dbt-msf-syria` | [`specs/dbt-model/der__cohort_ncd_registry.md`](https://github.com/beyondessential/tamanu-dbt-msf-syria/blob/main/specs/dbt-model/der__cohort_ncd_registry.md) |

Currently the model SQL lives only in the deployment repo. When a second
deployment adopts the cohort or the implementation is canonicalised, the
model moves to `tamanu-source-dbt/models/derived/` and this spec becomes the
authoritative reference; the deployment spec collapses to a thin override
note.

## Open questions

None outstanding.

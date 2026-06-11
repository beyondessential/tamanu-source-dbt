# dbt Model Spec: `der__cohort_ncd_6m` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `der__cohort_ncd_6m` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `der` |
| **Materialisation** | view |
| **Status** | `approved` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-11 |
| **Last updated** | 2026-06-11 |

Canonical definition of the MSF NCD 6-month evaluation cohort. Registered in
`seeds/metric_definitions.csv` as `cohort_ncd_6m` (kind `cohort`).
Implementations are deployment-specific (see § Implementations).

## Purpose

**What this artefact measures.** Members of the NCD program registry whose
NCD registration first transitioned to `ncdactive` exactly 9 months before
the reporting month and who remained in the program at the 6-month
evaluation point — paired with the BP and HbA1c measurements taken in the
3-9-month post-enrolment window. The cohort is the named entity that pins
those quality-of-care evaluations together.

**Clinical context.** MSF evaluates patients enrolled in the NCD program 9
months after they were first marked `ncdactive` — checking retention, exit
status, and quality-of-care measurements (BP, HbA1c). The 6-month cohort is
the canonical surface for those evaluations.

**Who reads it.** NCD 6-month-cohort indicator chains (retention, BP/HbA1c
measured and controlled percentages), future Tupaia data tables on cohort
evaluation outcomes, ad-hoc analyses on cohort retention.

## Grain

**One row per:** patient × reporting month, where the patient entered the
cohort at month `M − 9` and remained at the 6-month evaluation point in
month `M`. Each patient appears in exactly one reporting month per cohort
entry.

Note: this isn't strict OMOP shape (OMOP cohort is per-(subject, start, end)
once). The per-month grain matches how NCD indicators consume the cohort
for monthly reporting. Revisit if a strict OMOP cohort surface is ever
needed.

## Output schema

Required canonical columns:

| Column | Type | Notes |
|---|---|---|
| `cohort_id` | text | Constant `'cohort_ncd_6m'`; joins to the seed row |
| `subject_id` | uuid | Same value as `patient_id`; OMOP-lite cohort convention |
| `cohort_start_date` | date | Patient's `active_status_date::date` |
| `cohort_end_date` | date | Patient's `exit_recorded_date::date`; NULL when still in cohort |

Additional canonical columns:

| Column | Notes |
|---|---|
| `yearmonth` | Reporting month the row belongs to |
| `patient_id` | Same as `subject_id`; preserved for legacy consumers |
| `active_status_date` | Date the patient first became `ncdactive` |
| `exit_recorded_date` | Exit-survey date (null when still active) |
| `age`, `sex`, `facility_id` | Demographics + facility at the reporting month |
| `has_htn_diagnosis`, `has_diabetes_diagnosis` | Diagnosis flags |
| `ethnicity_id`, `dhis_ncd_category` | Program proxies |
| `bp_controlled`, `hba1c_controlled` | Quality-of-care flags (see sibling observations model) |

A sibling `der__cohort_ncd_6m_observations` model holds the per-observation
long format (`subject_id`, `yearmonth`, `observation_type`, `value_boolean`)
that the indicator chain consumes. Both surfaces share the `cohort_ncd_6m`
registry entry per
[derived-elements-conventions.md](../../.maui/knowledge/standards/derived-elements-conventions.md)
cohort layer structure.

## Business logic

- **BL-001:** `cohort_id` is constant `'cohort_ncd_6m'` on every row.
- **BL-002:** `subject_id` equals `patient_id` (OMOP naming convention). Both columns are present so legacy consumers keep working.
- **BL-003:** `cohort_start_date` is `active_status_date::date` — the date the patient's NCD registration first transitioned to `ncdactive`.
- **BL-004:** `cohort_end_date` is `exit_recorded_date::date`. NULL means the patient has not exited and is still in the cohort.
- **BL-005:** Membership rule: patient appears at reporting month `M` iff `cohort_start_date` is in month `M − 9` and `exit_recorded_date` is either NULL or after `M − 3`.
- **BL-006:** Membership view carries cohort + demographics + diagnosis flags only. Quality-of-care observations live in the sibling `der__cohort_ncd_6m_observations` model in long format. Both surfaces share the `cohort_ncd_6m` registry entry.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `cohort_id = 'cohort_ncd_6m'` on every row | BL-001 | dbt `accepted_values` |
| AC-002 | `subject_id` and `cohort_start_date` are `not_null` on every row | BL-002, BL-003 | dbt `not_null` |
| AC-003 | `subject_id` equals `patient_id` on every row | BL-002 | dbt `expression_is_true` |
| AC-004 | `der__cohort_ncd_6m_observations` has zero rows where `value_boolean` is NULL | BL-006 | dbt `not_null` |
| AC-005 | `der__cohort_ncd_6m_observations.subject_id × yearmonth × observation_type` is unique | BL-006 | dbt `dbt_utils.unique_combination_of_columns` |

## Registry entry

`seeds/metric_definitions.csv` row:

| Column | Value |
|---|---|
| `metric_id` | `cohort_ncd_6m` |
| `kind` | `cohort` |
| `subject_grain` | `patient` |
| `disaggregations` | `age_group,sex,facility_id` |
| `definition_source` | `MSF` |
| `status` | `draft` (promotes to `approved` once a canonical implementation lands in `tamanu-source-dbt`) |

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| MSF Syria | `tamanu-dbt-msf-syria` | [`specs/dbt-model/der__cohort_ncd_6m.md`](https://github.com/beyondessential/tamanu-dbt-msf-syria/blob/main/specs/dbt-model/der__cohort_ncd_6m.md) |

Currently the model SQL lives only in the deployment repo. When a second
deployment adopts the cohort or the implementation is canonicalised, the
model moves to `tamanu-source-dbt/models/derived/` and this spec becomes
the authoritative reference; the deployment spec collapses to a thin
override note.

## Open questions

None outstanding.

# dbt Model Spec: MSF NCD indicators (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | MSF NCD indicators (suite of 27 `metric__` indicators) |
| **Type** | dbt model suite (canonical definitions) |
| **Layer** | `metric` |
| **Materialisation** | view |
| **Status** | `approved` (definitions); deployment-only implementations |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-11 |
| **Last updated** | 2026-06-11 |

Canonical definitions for the 27 MSF NCD indicators registered in
`seeds/metric_definitions.csv`. Implementations are deployment-specific
(see § Implementations). This spec governs the *definitions* — what each
indicator measures, output shape, semantic invariants. Implementation
details (which `int__` chains feed each, materialisation strategy, view
collapsing) live in the deployment specs.

## Purpose

**What this artefact measures.** Operational indicators for the MSF NCD
program — patient counts, retention rates, blood-pressure and HbA1c
quality-of-care measures, and 6-month-cohort evaluation outcomes. The
indicators answer "how many NCD patients are enrolled / active / exited
/ controlled this month, by disease category, age, sex, and facility?"

**Clinical context.** MSF deployments run a chronic NCD program registry
within Tamanu. Indicators are computed monthly for DHIS2 reporting and
for ad-hoc analyses. The 27 indicators cover three indicator families:

| Family | Indicators |
|---|---|
| Activity | `consultations_new`, `consultations_followup`, `patients_active`, `patients_new`, `diagnoses`, `diagnoses_new`, `referred_specialist` |
| Exits | `exit_ltfu`, `exit_deceased`, `exit_transferred`, `exit_other` |
| Quality of care | `htn_bp_measured`, `htn_bp_controlled`, `diabetes_bp_measured`, `diabetes_bp_controlled`, `diabetes_hba1c_measured`, `diabetes_hba1c_controlled` |
| 6-month cohort evaluation | `cohort_6m_patients_active`, `cohort_6m_htn_active`, `cohort_6m_diabetes_active`, `cohort_6m_retention_percent`, `cohort_6m_htn_bp_measured_percent`, `cohort_6m_htn_bp_control_percent`, `cohort_6m_diabetes_bp_measured_percent`, `cohort_6m_diabetes_bp_control_percent`, `cohort_6m_diabetes_hba1c_measured_percent`, `cohort_6m_diabetes_hba1c_control_percent` |

**Who reads it.** MSF DHIS2 reporting (current consumer), future Tupaia
data tables, ad-hoc analyses on NCD program performance.

## Grain

Two grain shapes, each indicator declares which shape it uses via its
registry `disaggregations`:

**`dhis_ncd_category × age_group × sex × facility_id`** — disease-segmented
indicators (consultations, diagnoses, exits, referrals — 9 indicators).

**`age_group × sex × facility_id`** — non-disease-segmented indicators
(active/new patients, quality-of-care measures, cohort evaluation — 18
indicators).

Numerator/denominator definitions per indicator live in the registry row
(`numerator_description`, `denominator_description` columns of
`metric_definitions.csv`). The spec doesn't duplicate them — the registry
is the source of truth for per-indicator definition text.

## Output schema

D5 wide format. Each `metric__` view emits:

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the 27 indicator IDs from `metric_definitions.csv` |
| `variant_id` | text | NULL on the standard definition; deployment-set for definition variants |
| `subject_id` | uuid | NULL — these are pre-aggregated, not per-patient rows |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month |
| `period_granularity` | text | Constant `'month'` |
| `value_numeric` | numeric | Count for count indicators; rounded percentage (one decimal) for `*_percent` indicators |
| `value_boolean` | boolean | NULL — reserved for binary metrics |
| `dhis_ncd_category` | text | Disease category — disease-segmented indicators only |
| `age_group` | text | NCD age band |
| `sex` | text | Patient sex |
| `facility_id` | uuid | Facility associated with the metric — semantics per registry row |

## Business logic

- **BL-001:** Every output row carries `metric_id` set to its registered identifier in `seeds/metric_definitions.csv`. Joining a consumer to the registry on `metric_id` returns the definition.
- **BL-002:** `variant_id`, `subject_id`, and `value_boolean` are constant NULL on the standard definition. Deployment-specific definition variants set `variant_id` per D5.
- **BL-003:** `period_start` is the first of the reporting month; `period_end` is the last day of the same month; `period_granularity` is constant `'month'`.
- **BL-004:** `value_numeric` is the indicator value. Counts are integers; percentages are rounded to one decimal.
- **BL-005:** Row inclusion follows the indicator definition — count indicators emit rows only for slices where the count is positive; percentage indicators emit rows only for slices where the denominator is positive. Empty slices are not emitted as zero rows.
- **BL-006:** `facility_id` semantics differ per indicator (registering vs encounter vs referring facility) — recorded in each metric's `description` in the registry.
- **BL-007:** All 27 indicators share the same `definition_source = MSF` and follow MSF NCD program operational definitions. Deployment-specific variants flag definition variance via the `variant_of` registry mechanism (D5).

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `metric_id` on every row matches one of the 27 registered IDs | BL-001 | dbt `accepted_values` |
| AC-002 | `period_granularity = 'month'` on every row | BL-003 | dbt `accepted_values` |
| AC-003 | `value_numeric` is `not_null` on every row | BL-004 | dbt `not_null` |
| AC-004 | Composite PK (`metric_id`, `period_start`, disaggregations) is unique within each view | BL-001..BL-006 | dbt `dbt_utils.unique_combination_of_columns` |
| AC-005 | All 27 `metric_id`s in the registry appear as rows in the implementation views (no orphaned registry entries during steady-state operation) | BL-001 | dbt singular test |

## Registry entries

27 rows in `seeds/metric_definitions.csv`, all with `kind = metric`,
`definition_source = MSF`, `data_source = tamanu`. See the seed for
per-indicator `description`, `numerator_description`,
`denominator_description`, `unit`, `subject_grain`, and `disaggregations`.

Status starts `draft` for every row and promotes to `approved` row-by-row
as the corresponding canonical implementation lands in
`tamanu-source-dbt`.

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| MSF Syria | `tamanu-dbt-msf-syria` | [`specs/dbt-model/ncd-indicators-migration.md`](../../../tamanu-dbt-msf-syria/specs/dbt-model/ncd-indicators-migration.md) |

Currently the indicator implementations live only in the deployment repo
as two grouped `metric__` views over deployment-specific `int__` chains.
When a second deployment adopts the indicators, or canonical
implementations are written on top of `can__` / `der__`, the
implementations move to `tamanu-source-dbt/models/metrics/` and the
deployment specs collapse to override notes.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | D5's "one model per indicator" rule causes view-chain fan-out when several metrics share an upstream. MSF Syria collapses 27 metrics into 2 views grouped by disaggregation shape. Whether D5 should formally permit metric grouping models, or instead recommend replica-side table materialisation as the canonical fix, is a Maui architecture decision. Affects every deployment adopting D5. | Data Lead (BES) | before next deployment adopts D5 |
| OQ-002 | `facility_id` semantics differ across indicators (registering vs encounter vs referring). Documented per-metric in the registry, but a future cross-metric consumer joining on facility could be surprised. Worth surfacing in the registry schema or splitting into separate disaggregation columns. | Maui team | first cross-metric consumer |
| OQ-003 | Some indicators are likely to align with WHO PEN, WHO Core 100, IHCI, or MSF's own published NCD operational standards. Cross-mapping is worth doing once so the registry can record `definition_source_code` against the external reference. | Maui team | metric promotion from `draft` to `approved` |

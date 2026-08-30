# dbt Model Spec: MSF Mental Health Sessions (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | MSF Mental Health Sessions (suite of 3 `metric__` indicators) |
| **Type** | dbt model suite (canonical definitions) |
| **Layer** | `metric` |
| **Materialisation** | view |
| **Status** | `approved` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-19 |
| **Last updated** | 2026-07-19 |

Canonical definitions for the 3 MSF Mental Health Sessions indicators
registered in `documentations/metrics/*.yml`. Implementations are
deployment-specific (see § Implementations). This spec governs the
*definitions* — what each indicator measures, output shape, semantic
invariants. Implementation details (which upstream models feed each, session
dating mechanics, registration-status reconstruction mechanics) live in the
deployment specs.

## Purpose

**What this artefact measures.** Monthly indicators for MSF's "Mental health
sessions: Psychiatry and mhGAP" DHIS2 dataset — how many patients are under
active psychiatric care, how many psychiatry sessions occurred, and how many
patients reported medication side effects, per facility per month.

**Clinical context.** MSF deployments run a psychiatry program registry
within Tamanu, with patients progressing through Baseline, Follow Up, and
Closure assessment forms. The 3 indicators:

| Indicator | What it counts |
|---|---|
| `active_psychiatric_care` | Distinct patients whose psychiatry-registry registration status is active as of month end |
| `psychiatric_care_sessions` | Distinct sessions (one per encounter with at least one qualifying form) in the month |
| `medication_side_effects` | Distinct patients with a documented medication side effect during a session in the month |

**Who reads it.** MSF DHIS2 reporting (current consumer, via the "Mental
health sessions: Psychiatry and mhGAP" dataset).

## Grain

`metric_id × period_start × facility_id`. No disaggregation dimensions —
all three indicators emit at facility grain only, confirmed by MSF (no
age/sex/disease breakdown for this dataset).

## Output schema

D5 wide format. Each `metric__` view emits:

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of `active_psychiatric_care`, `psychiatric_care_sessions`, `medication_side_effects` |
| `variant_id` | text | NULL on the standard definition |
| `subject_id` | uuid | NULL — pre-aggregated counts, not per-patient rows |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month |
| `period_granularity` | text | Constant `'month'` |
| `value_numeric` | numeric | Count for the month |
| `value_boolean` | boolean | NULL — not used by these indicators |
| `facility_id` | uuid | Facility associated with the metric — see BL-006 |

## Business logic

- **BL-001:** Every output row carries `metric_id` set to its registered
  identifier in `documentations/metrics/*.yml`. Joining a consumer to the
  registry on `metric_id` returns the definition.
- **BL-002 (`active_psychiatric_care`):** Count of distinct patients whose
  psychiatry-program registration status is **active as of the end of each
  reporting month** — a point-in-time membership check, not a live snapshot
  taken at report-run time. A patient whose status changes mid-month counts
  or doesn't count for that month based on their status at month end, not
  their current status.
- **BL-003 (`psychiatric_care_sessions`):** Count of distinct **sessions**
  in the reporting month, where a session is one clinical encounter with at
  least one of the defined assessment forms submitted (Baseline, Follow Up,
  or Closure). Multiple forms completed as part of the same clinical
  encounter count as one session, not one per form.
- **BL-004 (`medication_side_effects`):** Count of distinct **patients**
  (not sessions) with at least one documented medication side effect
  recorded during a session in the reporting month. A patient with side
  effects recorded across multiple sessions in the same month still counts
  once.
- **BL-005:** `period_start`/`period_end` bound a calendar month;
  `period_granularity` is constant `'month'`.
- **BL-006:** `facility_id` semantics differ by indicator — session-based
  indicators (`psychiatric_care_sessions`, `medication_side_effects`)
  attribute to the facility where the session occurred;
  `active_psychiatric_care` attributes to the facility of the patient's
  registration. Implementations should document whether these two sources
  can diverge for a given deployment (they're independent, not
  cross-checked against each other).
- **BL-007:** Zero-value slices are not emitted as zero rows (DHIS2 treats
  an absent datavalue as no-data, not zero). All three indicators share
  `definition_source = MSF`, following the "Mental health sessions:
  Psychiatry and mhGAP" program operational definition.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `metric_id` on every row matches one of the 3 registered IDs | BL-001 | dbt `accepted_values` |
| AC-002 | `period_granularity = 'month'` on every row | BL-005 | dbt `accepted_values` |
| AC-003 | `value_numeric` is `not_null` on every row | — | dbt `not_null` |
| AC-004 | Composite PK (`metric_id`, `period_start`, `facility_id`) is unique within each implementation view | BL-001..BL-006 | dbt `dbt_utils.unique_combination_of_columns` |
| AC-005 | No row has `value_numeric <= 0` | BL-007 | singular test |

## Registry entries

3 rows in `documentations/metrics/*.yml`: `active_psychiatric_care`,
`psychiatric_care_sessions`, `medication_side_effects` — all with
`kind = metric`, `definition_source = MSF`, `data_source = tamanu`. See the
seed for per-indicator `description`, `subject_grain`, and `unit`.

All 3 rows are `status = approved` in the registry, shipping in
`tamanu-source-dbt` v2.54.18. An implementation holds its `metric_definitions`
relationships test at `warn` until its deployment's pin reaches a release
carrying these rows, then moves it to `error`.

## Implementations

Implemented in deployment repos; each implementation spec links here from its
identity block. A definition-level divergence between two implementations is
captured in this spec, or as a `variant_of` registry row per D5 -- never in one
deployment's own spec, where the other's readers would not see it.

## Open questions

None outstanding.

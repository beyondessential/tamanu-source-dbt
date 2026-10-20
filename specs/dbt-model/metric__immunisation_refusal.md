# dbt Model Spec: `metric__immunisation_refusal` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__immunisation_refusal` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.57`, forward-ported) |
| **Linear issue** | [MAUI-6808](https://linear.app/bes/issue/MAUI-6808) (initial), [MAUI-7034](https://linear.app/bes/issue/MAUI-7034) (BL-010, BL-011) |
| **Created** | 2026-10-20 (the model shipped in MAUI-6808 without this file; its clauses are recorded here as implemented) |
| **Last updated** | 2026-10-20 |

Canonical definition for `immunisation_refusal`: one row per vaccination attempt recorded in
Tamanu as not given.

## Purpose

Count of vaccination attempts not given, by antigen, dose position, age, sex, facility, village,
vaccine, location group and reason — read beside `metric__immunisation_dose` for a "given vs not
given" view and the reasons doses were missed. Kept as its own `metric_id` rather than a status
disaggregation on doses: see `specs/dbt-model/metric__immunisation_dose.md`, OQ-001.

**Who reads it.** Tupaia immunisation cards; Tuvalu's typhoid dashboard "not administered" and
"reason not given" cards (MAUI-7034).

## Definition sources

| Element | `definition_source` | Concept |
|---|---|---|
| `immunisation_refusal` | `BES` | No external standard defines a refusal count; a BES composition sharing `immunisation_dose`'s shape plus the reason |

## Grain

**One row per `(metric_id, subject_id)`**, asserted by AC-001. `subject_id` is the attempt's
`clinical__observation.observation_id` — the underlying `vaccine_administrations` id.

## Output schema

The same columns as `metric__immunisation_dose` (that spec, § Output schema), with
`metric_id` = `immunisation_refusal`, `subject_id` = the attempt id and the attempt date as
`period_start` / `period_end`, plus:

| Column | Type | Notes |
|---|---|---|
| `reason` | text | Why the dose was not given, `'Not recorded'` when neither a coded nor free-text reason was captured (BL-009, AC-014) |

`person_id` (AC-015), `vaccine_label` (AC-016) and `vaccine_category` (AC-017) are `not_null`, as
on the dose metric (BL-010).

## Data tables

Configured in `tupaia-data-product` at `tamanu/data_tables/`; no `data_table_*` meta here.

## Business logic

- **BL-001 (inclusion):** one row per `clinical__observation` row of type `vaccination not given`
  (already `status = 'NOT_GIVEN'`) that resolves in `int__vaccine_administration_attributes`.
- **BL-002 (reporting period):** `period_start` and `period_end` are both the attempt date, at
  `'day'` granularity.
- **BL-003 (count):** `value_numeric` is `1` per row.
- **BL-004 (facility):** as `metric__immunisation_dose` BL-004 — the facility of the attempt's
  recorded location, inner-joined.
- **BL-005 (antigen):** as `metric__immunisation_dose` BL-005.
- **BL-006 (EPI age cohort):** as `metric__immunisation_dose` BL-006.
- **BL-007 (dose position):** as `metric__immunisation_dose` BL-007.
- **BL-008 (patient village):** as `metric__immunisation_dose` BL-008.
- **BL-009 (reason):** `reason` is the coded not-given reason's reference-data name, falling back
  to the free-text reason, then `'Not recorded'`.
- **BL-010 (patient, vaccine, location group, raw age):** `person_id`, `vaccine_id`,
  `vaccine_label`, `vaccine_category`, `location_group_id`, `age_days` and `age_years` are defined
  as in `metric__immunisation_dose` BL-009 to BL-012, so the two metrics still read side by side.
- **BL-011 (classification):** `classification: restricted` and `pii: false`, for the same reason
  as `metric__immunisation_dose` BL-013.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and `immunisation_refusal` | registry | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions` | registry | `relationships` (`error`) |
| AC-004 – AC-008, AC-010 – AC-013 | As `metric__immunisation_dose`'s same-numbered criteria, on this model's columns | BL-002 – BL-007 | `not_null` / `accepted_values` |
| AC-009 | The projection resolves as specified, including the reason fallback and the BL-010 fields | BL-001, BL-002, BL-005 – BL-010 | unit test `ac_009_metric__immunisation_refusal_projection`, plus `period_end >= period_start` |
| AC-014 | `reason` is `not_null` | BL-009 | `not_null` |
| AC-015 | `person_id` is `not_null` | BL-010 | `not_null` |
| AC-016 | `vaccine_label` is `not_null` | BL-010 | `not_null` |
| AC-017 | `vaccine_category` is `not_null` | BL-010 | `not_null` |

## Registry entry

`immunisation_refusal` in `documentations/metrics/immunisation.yml`: `subject_grain: attempt`,
`spec_path` pointing here, disaggregations as `immunisation_dose` plus `reason`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__observation` | `clinical/` | Attempt identity and date (BL-001, BL-002) |
| `int__vaccine_administration_attributes` | `intermediate/` | Every attribute, shared with `metric__immunisation_dose` |
| `metric_definitions` | root | Registry (AC-003) |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-20 | Maui team | Spec written for the model shipped in MAUI-6808, recording BL-001 to BL-009 as implemented. Added BL-010 and BL-011 (MAUI-7034): the patient, scheduled-vaccine, location-group and raw-age fields, and `classification: restricted`; AC-015 to AC-017 and AC-009 extended |

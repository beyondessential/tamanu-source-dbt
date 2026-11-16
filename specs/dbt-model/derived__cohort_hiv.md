# dbt Model Spec: `derived__cohort_hiv` (canonical definition)

## Purpose

HIV indicators and line lists need one answer to who was in HIV care, and from when to when. This
defines that as an OMOP-style cohort: one row per patient on a deployment's HIV programme registry,
with the date they entered the cohort and the date they left it.

**Consumers:** the HIV indicator models and HIV line lists of a deployment that runs an HIV register.

## Identity

| Field | Value |
|---|---|
| **Name** | `derived__cohort_hiv` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `derived` |
| **Status** | `draft` |
| **Owner** | Maui team (`bes-maui`) |
| **Linear issue** | [MAUI-6861](https://linear.app/bes/issue/MAUI-6861) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-17 |

Registered in `documentations/metrics/hiv_cohort.yml` as `cohort_hiv` (kind `cohort`), and in
`seeds/cohort_definitions.csv` as `cohort_definition_id` 1. The model is implemented by the
deployment that carries the registry (§ Implementations).

## Grain

**One row per patient on the registry.**

## Output schema

| Column | Description |
|---|---|
| `cohort_id` | `cohort_hiv` |
| `cohort_definition_id` | `1` |
| `subject_id` | The patient |
| `cohort_start_date` | The day the patient entered the cohort |
| `cohort_end_date` | The day the patient left the cohort, empty while they are in it |

## Business logic

A deployment binds three things to this definition: its HIV programme registry, the intake forms
that date entry in order of preference, and the registry's clinical statuses that record death.

- **BL-001:** A patient is in the cohort when they hold a registration on the deployment's HIV programme registry, and a registration recorded in error is never counted.
- **BL-002:** A patient with more than one counted registration enters the cohort at the earliest.
- **BL-003:** `cohort_start_date` is the date of the patient's earliest response to the most preferred bound intake form they responded to, and the registration date for a patient with no response to any of them.
- **BL-004:** A patient's date of death is the day a clinical status recording death was first logged against their registration.
- **BL-005:** `cohort_end_date` is the registration's deactivation date where it was deactivated, otherwise the date of death, and is empty for a patient still in the cohort.
- **BL-006:** Every row carries `cohort_id` `cohort_hiv` and the `cohort_definition_id` allocated to it in `cohort_definitions`.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | A registration recorded in error, and one on another registry, put no patient in the cohort | BL-001 |
| AC-002 | A patient registered twice has one row, starting from the earlier registration | BL-002 |
| AC-003 | A patient who responded to both forms enters at their earliest response to the preferred one, even where a response to the other is earlier, and a patient with no response enters at the registration date | BL-003 |
| AC-004 | `cohort_start_date` is never empty | BL-003 |
| AC-005 | Of two death statuses logged on different days, the earlier dates the death | BL-004 |
| AC-006 | A deactivated registration ends at the deactivation date even where a death is recorded, a death ends an active registration, and a patient with neither has an empty end date | BL-005 |
| AC-007 | Every row's `cohort_id` is `cohort_hiv` and its `cohort_definition_id` is the allocated id | BL-006 |
| AC-008 | There is one row per patient | Grain |

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| Fiji | `tamanu-dbt-fiji` | `specs/dbt-model/derived__cohort_hiv.md` |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-17 | @julianam-w | Initial draft of the canonical definition |

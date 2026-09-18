# dbt Model Spec: `metric__sti_reported_cases` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__sti_reported_cases` |
| **Type** | dbt model |
| **Layer** | `metric` |
| **Materialisation** | env-aware |
| **Status** | `draft` |
| **Owner** | `@beyondessential/maui` |
| **Linear issue** | [MAUI-6889](https://linear.app/bes/issue/MAUI-6889) |
| **Repo** | `tamanu-source-dbt` (definition); implemented per deployment |
| **Created** | 2026-09-18 |
| **Last updated** | 2026-09-18 |

Registers `sti_urethral_discharge_syndrome_case`, `sti_gonorrhoea_case` and `sti_syphilis_case`. Definition only: which form
fields notify a case, and which laboratory results confirm one, are deployment reference data, so
the model is built in the deployment repo.

## Purpose

**What this artefact measures.** Reported cases of a sexually transmitted infection or syndrome —
what a clinician recorded, combined with what the laboratory confirmed, deduplicated so a patient
reported through both is one case.

**Clinical context.** Case notification for programme reporting, distinct from the screening
cascade: the cascade measures testing activity against a population, these count cases.

**Who reads it.** Programme case-count reporting.

## Grain

One row per patient per reporting period within each metric ID, the condition being fixed by the
metric ID rather than carried as a column.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the three registered IDs |
| `variant_id` | text | NULL unless a deployment registers a definition variant |
| `subject_id` | varchar | Patient, matching the registered `patient` subject grain |
| `period_start` | date | First day of the reporting period |
| `period_end` | date | Last day of the reporting period |
| `period_granularity` | text | The deployment's deduplication window, constant within a metric ID |
| `value_numeric` | numeric | Always 1 |
| `value_boolean` | boolean | Unused |
| `facility_id` | varchar | Tamanu facility, untranslated |
| `sex` | text | From `clinical__person`, emitted unrestricted |

## Business logic

- **BL-001:** A case is a condition notified on a clinical form or confirmed by laboratory result.
- **BL-002:** A patient reported through both routes within one period is one case, so the two sources are deduplicated against each other rather than summed.
- **BL-003:** A patient reported more than once within a period is one case for that period.
- **BL-004:** The reporting period is not fixed by the definition. A programme deduplicating monthly and one deduplicating annually are counting the same thing over different windows, so the model declares the window it used in `period_granularity` and a consumer reads it rather than assuming one.
- **BL-005:** Each condition is registered as its own metric id, because a patient can be reported for more than one condition in a period and a single id with a condition column would make an unfiltered total count them repeatedly.
- **BL-006:** Which form fields notify a case, and which laboratory results confirm one, are deployment bindings.
- **BL-007:** A sex restriction is a property of the indicator a deployment reports, not of the definition; the model emits sex and leaves the restriction to the consumer.
- **BL-008:** `period_granularity` is constant within a metric ID, so an unfiltered total over that ID never mixes windows.
- **BL-009:** Every row carries `metric_id` set to its registered identifier, `value_numeric` 1, and a `period_start` on the first day of the reporting period.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | A patient notified on a form and confirmed by laboratory in one period yields one case | BL-002 | unit test |
| AC-002 | A patient reported twice in a period yields one case | BL-003 | unit test |
| AC-003 | `period_granularity` is `not_null` and takes a single value within each `metric_id` | BL-004, BL-008 | `not_null` + `accepted_values` |
| AC-004 | A patient reported for two conditions yields one case per condition | BL-005 | unit test |
| AC-005 | Every emitted `metric_id` is registered | BL-009 | `relationships` to `metric_definitions` |
| AC-006 | `metric_id`, `subject_id` and `period_start` are unique together | Grain, BL-003 | `dbt_utils.unique_combination_of_columns` |
| AC-007 | `value_numeric` is always 1 | BL-009 | schema `accepted_values` |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a deployment's deduplication period should be recorded as a `variant_of` where it differs from another deployment's, given BL-004 leaves it open. | @beyondessential/maui | 2026-10-31 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-18 | @beyondessential/maui | Initial definition: reported case counts for STI conditions (MAUI-6889) |

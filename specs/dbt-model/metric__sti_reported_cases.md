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

Registers `sti_uds_case`, `sti_gonorrhoea_case` and `sti_syphilis_case`. Definition only: which form
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

One row per patient per condition per reporting period.

## Business logic

- **BL-001:** A case is a condition notified on a clinical form or confirmed by laboratory result.
- **BL-002:** A patient reported through both routes within one period is one case, so the two sources are deduplicated against each other rather than summed.
- **BL-003:** A patient reported more than once within a period is one case for that period.
- **BL-004:** The reporting period is not fixed by the definition. A programme deduplicating monthly and one deduplicating annually are counting the same thing over different windows, so the model carries `period_granularity` and a consumer groups by it.
- **BL-005:** Each condition is registered as its own metric id, because a patient can be reported for more than one condition in a period and a single id with a condition column would make an unfiltered total count them repeatedly.
- **BL-006:** Which form fields notify a case, and which laboratory results confirm one, are deployment bindings.
- **BL-007:** A sex restriction is a property of the indicator a deployment reports, not of the definition; the model emits sex and leaves the restriction to the consumer.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | A patient notified on a form and confirmed by laboratory in one period yields one case | BL-002 | unit test |
| AC-002 | A patient reported twice in a period yields one case | BL-003 | unit test |
| AC-003 | Every emitted row carries a `period_granularity` | BL-004 | schema `not_null` |
| AC-004 | A patient reported for two conditions yields one case per condition | BL-005 | unit test |
| AC-005 | Every emitted `metric_id` is registered | BL-005 | schema `relationships` |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a deployment's deduplication period should be recorded as a `variant_of` where it differs from another deployment's, given BL-004 leaves it open. | @beyondessential/maui | 2026-10-31 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-18 | @beyondessential/maui | Initial definition: reported case counts for STI conditions (MAUI-6889) |

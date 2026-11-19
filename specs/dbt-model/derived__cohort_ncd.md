# dbt Model Spec: `derived__cohort_ncd` (canonical definition)

## Purpose

A deployment needs to know who was on the diabetes and hypertension registry, and with which
conditions, on any day, so indicators asked at different dates all use one definition of registry
membership. This defines that as two OMOP-style cohorts: one row per cohort entry, a continuous
period over which a patient is on the registry with hypertension, or with type 1 or type 2
diabetes. A date is in a cohort when a cohort entry covers it.

**Consumers:** registry indicators asked at a past date, such as the registry indicators of an
NCD dashboard.

## Identity

| Field | Value |
|---|---|
| **Name** | `derived__cohort_ncd` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `derived` |
| **Status** | `draft` |
| **Owner** | Maui team (`bes-maui`) |
| **Linear issue** | [MAUI-7114](https://linear.app/bes/issue/MAUI-7114) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

Registered in `documentations/metrics/ncd.yml` as `cohort_ncd_hypertension` and
`cohort_ncd_diabetes` (kind `cohort`). The model is implemented by the deployment that carries
the registry (§ Implementations).

## Grain

**One row per cohort, patient and cohort entry.** The entries of a patient in one cohort do not
overlap or adjoin.

## Output schema

| Column | Description |
|---|---|
| `cohort_id` | `cohort_ncd_hypertension` or `cohort_ncd_diabetes` |
| `subject_id` | The patient |
| `cohort_start_date` | The first day of the cohort entry |
| `cohort_end_date` | The last day of the cohort entry, empty while it has not ended |

## Business logic

- **BL-001:** A registration of the diabetes and hypertension registry (`programRegistry-dmandhtnregistry`)
  is counted when it is active, or inactive with a deactivation date, and a registration recorded in
  error, or deactivated with no date, is never counted.
- **BL-002:** A condition era lies within a counted registration, from the day the registration
  started up to the day before it was deactivated, and has no end while the registration is active.
- **BL-003:** A patient holds a condition on a day unless the record in force that day is disproven or
  recorded in error, the record in force being the latest one dated on or before the day that was not
  deleted on or before it.
- **BL-004:** The hypertension cohort is built from `prCondition-dmandhtnregistry-hypertension`, and
  the diabetes cohort from `prCondition-dmandhtnregistry-type1diabetes` and
  `prCondition-dmandhtnregistry-type2diabetes`.
- **BL-005:** Overlapping and adjoining condition eras of a patient in one cohort are one cohort entry.
- **BL-006:** The start date is the first day of a cohort entry and the end date its last day, and the
  end date is empty while the entry has not ended.

A condition era is a continuous period over which a patient holds one registry condition on one
registration.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | A registration recorded in error, one deactivated with no date and one of another registry have no era | BL-001 |
| AC-002 | An era stops the day before the deactivation date, starts at the registration when the condition was recorded earlier, and a registration deactivated the day it started has none | BL-002 |
| AC-003 | A disproven and re-confirmed condition has two eras, a deleted record ends its era, a record deleted the day it was made is never in force, and of two records on one day the later is in force | BL-003 |
| AC-004 | Hypertension and the diabetes types are separate cohorts, and the two diabetes types are one cohort | BL-004 |
| AC-005 | Adjoining and overlapping eras are one cohort entry, and eras with a gap stay apart | BL-005 |
| AC-006 | The end date is the last day of membership and is empty for an entry not ended | BL-006 |
| AC-007 | No two entries of a patient in a cohort overlap or adjoin | BL-005 |
| AC-008 | There is one row per cohort, patient and start date | Grain |

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| Samoa | `tamanu-dbt-samoa` | `specs/dbt-model/derived__cohort_ncd.md` |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Initial draft |

# dbt Model Spec: `metric__sti_service_attendance` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__sti_service_attendance` |
| **Type** | dbt model |
| **Layer** | `metric` |
| **Materialisation** | env-aware |
| **Status** | `draft` |
| **Owner** | `@beyondessential/maui` |
| **Linear issue** | [MAUI-6889](https://linear.app/bes/issue/MAUI-6889) |
| **Repo** | `tamanu-source-dbt` (definition); implemented per deployment |
| **Created** | 2026-09-18 |
| **Last updated** | 2026-09-18 |

Registers `sti_service_attendance` and `sti_service_attendance_key_population`. This is the
definition only: which clinics a deployment runs STI services from is a binding, not a property of
the measurement, so the model is built in the deployment repo. That split follows the one
`metric__sti_screening` already uses.

## Purpose

**What this artefact measures.** The population attending STI services in a reporting month — the
denominator a screening coverage rate divides by.

**Clinical context.** Screening coverage is the share of the population attending a service that
was tested. The numerator already exists as `sti_<infection>_test_key_population`; without a
registered denominator a coverage rate has to be stored, which D5 does not allow.

**Who reads it.** Screening coverage indicators, through a consumer that divides one metric id by
the other.

## Grain

`sti_service_attendance`: one row per patient per reporting month.

`sti_service_attendance_key_population`: one row per patient per reporting month per key population
the patient belongs to.

## Business logic

- **BL-001:** A patient counts once for a reporting month however many times they attended within it.
- **BL-002:** Which services count as STI services is a deployment binding; the definition does not name clinics.
- **BL-003:** Attendance is counted whether or not the patient was tested, so the denominator is not conditioned on the numerator.
- **BL-004:** Key population membership is the standing answer as at the end of the reporting month, not a property of the visit.
- **BL-005:** A patient belonging to more than one key population contributes a row to each, so summing across populations double-counts them.
- **BL-006:** The base id carries no key population, and is the only one whose unfiltered total is a patient count.
- **BL-007:** Eligibility matches whatever the corresponding testing metric applies, so a patient counted in the numerator is never absent from the denominator.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | A patient attending twice in a month yields one row | BL-001 | unit test |
| AC-002 | An untested attendee is still counted | BL-003 | unit test |
| AC-003 | A patient in two key populations yields one row per population | BL-005 | unit test |
| AC-004 | The base id carries a null key population | BL-006 | schema test |
| AC-005 | A patient present in the testing metric is present here | BL-007 | singular test |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a deployment scoping attendance to a service list narrower than its testing metric's eligibility should register a `variant_of` rather than treat it as a binding. | @beyondessential/maui | 2026-10-31 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-18 | @beyondessential/maui | Initial definition: the attendance denominator for STI screening coverage (MAUI-6889) |

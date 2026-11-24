# Definition Spec: `metric__ncd_dli7_protocol_compliance` (DLI 7 diabetes protocol compliance)

## Purpose

DLI 7 is the share of registered diabetic patients receiving protocol-compliant follow-up. A patient
is compliant when, at a quarter's end, they have been seen in the last 180 days and have had an
HbA1c test, a BMI, and nutrition and health education in the last 365 days. This defines the
patient-level counts a consumer divides to get the rate, and the count of patients lost to
follow-up.

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ncd_dli7_protocol_compliance` |
| **Type** | Canonical definition |
| **Layer** | `metric` |
| **Status** | `implemented` |
| **Owner** | Maui team (`bes-maui`) |
| **Repo** | `tamanu-source-dbt` (definition), implemented in `tamanu-dbt-samoa` |
| **Linear issue** | [MAUI-7227](https://linear.app/bes/issue/MAUI-7227) |
| **Registry** | The seven `dli7_dm_*` ids under Grain (`kind: metric`) in `documentations/metrics/ncd.yml` |
| **Definition source** | Samoa Ministry of Health (`SAMOA_MOH`), DLI 7 |
| **Created** | 2026-11-24 |

## Grain

**One row per metric id, patient and quarter** for which the patient meets that metric id. Every
patient with any row in a quarter has a `dli7_dm_registered` row in it.

| `metric_id` | A row means the patient, at the evaluation date… |
|---|---|
| `dli7_dm_registered` | is in the diabetes registry cohort (the denominator) |
| `dli7_dm_visit_180d` | had a visit in the last 180 days |
| `dli7_dm_lost_to_follow_up` | had no visit in the last 180 days |
| `dli7_dm_hba1c_365d` | had an HbA1c test in the last 365 days |
| `dli7_dm_bmi_365d` | had a BMI recorded in the last 365 days |
| `dli7_dm_nutrition_365d` | had nutrition and health education in the last 365 days |
| `dli7_dm_protocol_compliant` | meets all four of visit, HbA1c, BMI and nutrition |

## Output schema

| Column | Description |
|---|---|
| `metric_id` | One of the ids under Grain |
| `variant_id` | Empty |
| `subject_id` | The patient |
| `period_start`, `period_end` | The quarter's first and last day |
| `period_granularity` | `quarter` |
| `as_of_date` | The evaluation date: the quarter's last day, or today for the current quarter |
| `value_numeric` | 1 |
| `value_boolean` | true |
| `facility_id` | The patient's facility at the evaluation date |
| `sex` | The patient's sex as recorded |

## Business logic

- **BL-001:** A quarter is evaluated at its last day, and the current quarter at today, in deployment-local time.
- **BL-002:** A patient is in the denominator when a `cohort_ncd_diabetes` entry covers the evaluation date.
- **BL-003:** A visit is any encounter other than a survey-response encounter, at any facility, that starts on or before the evaluation date.
- **BL-004:** "In the last N days" is the N days up to and including the evaluation date, judged by the event's own local date.
- **BL-005:** A patient with no visit in the last 180 days is lost to follow-up and stays in the denominator.
- **BL-006:** An HbA1c is an HbA1c lab test whose request was not cancelled, deleted, entered in error or invalidated, whatever its result, or an HbA1c result recorded on a clinical form. [TBD: see MAUI-7227]
- **BL-007:** A BMI is a plausible BMI recorded on a vitals or screening form.
- **BL-008:** Nutrition and health education is a dietetic assessment, a nutrition note or a health behaviour check.
- **BL-009:** A patient is protocol compliant when the visit, HbA1c, BMI and nutrition conditions all hold at the evaluation date.
- **BL-010:** A patient's facility is the facility of their latest visit on or before the evaluation date, and empty when there is none.
- **BL-011:** The protocol compliance rate is `dli7_dm_protocol_compliant` patients ÷ `dli7_dm_registered` patients, for the same quarter and disaggregation.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | One row per metric id, patient and quarter | Grain |
| AC-002 | Every row has a `dli7_dm_registered` row for the same patient and quarter | Grain |
| AC-003 | A patient whose cohort entry starts in the quarter's last week counts, and one whose entry ended before the evaluation date does not | BL-002 |
| AC-004 | A visit 179 days before the evaluation date counts, one 180 days before does not, and a survey-response encounter is never a visit | BL-003–BL-005 |
| AC-005 | A cancelled HbA1c request does not count, and a test with no result does | BL-006 |
| AC-006 | A patient meeting three of the four conditions is not compliant | BL-009 |
| AC-007 | The current quarter is evaluated at today, a past quarter at its last day | BL-001 |

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| Samoa | `tamanu-dbt-samoa` | `specs/dbt-model/metric__ncd_dli7_protocol_compliance.md` |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-24 | Maui team | Initial definition |

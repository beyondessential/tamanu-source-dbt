# dbt Model Spec: `metric__hiv_viral_load` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__hiv_viral_load` |
| **Type** | dbt model |
| **Layer** | `metric` |
| **Materialisation** | env-aware (`view` in the production bundle) |
| **Status** | `draft` |
| **Owner** | `bes-maui` |
| **Repo** | `tamanu-source-dbt` (definition); implemented per deployment |
| **Linear issue** | [MAUI-6864](https://linear.app/bes/issue/MAUI-6864/report-viral-load-results-over-time-and-viral-suppression-status) |
| **Created** | 2026-09-28 |
| **Last updated** | 2026-09-28 |

Registers two metric IDs in `documentations/metrics/hiv_viral_load.yml`: `hiv_viral_load_test`
and `hiv_viral_load_patient_month`. `BL` and `AC` numbering is shared with the deployment
implementation specs and with the `-- BL-0xx` code comments, so an anchor resolves identically in
either.

## Purpose

**What this artefact measures.** HIV viral load results for people in the HIV programme cohort, each
classified into one of five viral suppression categories, so the same result reads the same way in
every consumer: a Tamanu line list of a patient's results over time, and a Tupaia distribution of
patients by suppression category.

**Clinical context.** Viral suppression is the core clinical and programmatic measure for people on
antiretroviral therapy, and the third of the UNAIDS 95-95-95 targets. A viral load result is entered
in the lab module as free text: a number of copies/mL, a number reported against the assay's limit
(`<20`), or a statement that no virus was detected.

**Who reads it.** Programme staff and ministry counterparts, through Tamanu reports and Tupaia
dashboards.

## Grain

Two grains, registered as separate metric IDs because summing them answers different questions:

- `hiv_viral_load_test` — one row per qualifying viral load test. It counts tests.
- `hiv_viral_load_patient_month` — one row per patient per reporting month in which the patient has
  a qualifying test, carrying the month's most recent result. It counts people.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the two registered IDs |
| `variant_id` | text | NULL unless a deployment registers a definition variant |
| `subject_id` | varchar | Patient, matching the registered `patient` subject grain |
| `measurement_id` | varchar | The test the row reports: the test itself, or on the patient-month ID the month's most recent test |
| `period_start` | date | Test ID: the test date. Patient-month ID: first day of the reporting month |
| `period_end` | date | Test ID: the test date. Patient-month ID: last day of the reporting month |
| `period_granularity` | text | `day` on the test ID, `month` on the patient-month ID |
| `value_numeric` | numeric | Always 1 |
| `value_boolean` | boolean | Unused |
| `test_date` | date | Date the sample was taken |
| `facility_id` | varchar | Tamanu facility, untranslated |
| `sex` | text | From `clinical__person` |
| `age_years` | integer | Whole years at the test date, unbanded |
| `test_type` | text | `Baseline` or `Follow up` |
| `result` | text | The result as entered |
| `copies_per_ml` | numeric | The result read as a number of copies/mL; 0 where no virus was detected |
| `operator` | text | `<`, `<=`, `>` or `>=` where the result was reported against a limit |
| `suppression_status` | text | `Undetectable`, `Suppressed`, `Low-level viremia`, `Unsuppressed` or `High viral load` |

## Business logic

### Scope and grain

- **BL-001:** Every row carries `metric_id` set to its registered identifier and `value_numeric` 1.
- **BL-002:** On the test ID, each qualifying test contributes one row, with `period_start` and `period_end` set to its test date.
- **BL-003:** On the patient-month ID, a patient contributes one row per reporting month containing a qualifying test, carrying that month's most recent test.
- **BL-004:** A patient's tests are ordered by test date, then measurement datetime, then measurement ID.

### Qualifying tests

- **BL-005:** A viral load test is a lab measurement of a test type the implementation binds as HIV viral load, and the implementation binds which of those types is a baseline test.
- **BL-006:** A test on a withdrawn request does not qualify.
- **BL-007:** A test qualifies for a patient who is a member of the HIV programme cohort, whatever its date relative to the patient's enrolment.
- **BL-008:** The test date is the date the sample was collected, else the lab test's own date.

### Reading the result

- **BL-009:** `copies_per_ml` and `operator` are the measurement's numeric value and comparison operator.
- **BL-010:** A result of not detected, undetectable, target not detected or TND reads as 0 copies/mL.
- **BL-011:** A deployment convention that marks a result as below the assay's limit is bound by the implementation.

### Suppression status

- **BL-012:** `suppression_status` is `Undetectable` below 50 copies/mL, `Suppressed` below 200, `Low-level viremia` below 1,000, `Unsuppressed` below 100,000, and `High viral load` from 100,000.
- **BL-013:** A result reported as `<N` is strictly below N, and a result reported as `>N` is classified at N.
- **BL-014:** A result that cannot be read as a number has no suppression status, and its row is still emitted.

### Cross-cutting

- **BL-015:** `test_type` is carried on every row, and no baseline filter is applied.
- **BL-016:** `age_years` is whole years at the test date, emitted unbanded.
- **BL-017:** `facility_id` is the Tamanu facility of the test's encounter, untranslated.
- **BL-018:** Test patients are excluded, inherited from the base models.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | Every row's `metric_id` is one of the two registered IDs | BL-001 | schema `accepted_values` |
| AC-002 | Every `metric_id` resolves against the metric registry | BL-001 | `relationships` to `metric_definitions` |
| AC-003 | `value_numeric` is always 1 | BL-001 | schema `accepted_values` |
| AC-004 | On the test ID, `measurement_id` is unique | BL-002 | `dbt_utils.unique_combination_of_columns` |
| AC-005 | On the patient-month ID, `subject_id` and `period_start` are unique together | BL-003 | `dbt_utils.unique_combination_of_columns` |
| AC-006 | A patient tested twice in a month yields two test rows and one patient-month row carrying the later test | BL-002, BL-003, BL-004 | unit test |
| AC-007 | Two tests on the same date resolve to the later measurement datetime | BL-004 | unit test |
| AC-008 | A test for a patient outside the cohort is excluded, and a test dated before the patient's enrolment is included | BL-007 | unit test |
| AC-009 | The test date is the sample collection date where one is recorded, else the lab test date | BL-008 | unit test |
| AC-010 | Results at and either side of each band boundary classify into the right band, with `<N` read as strictly below N | BL-012, BL-013 | unit test |
| AC-011 | Not-detected wording reads as 0 and Undetectable, and an unreadable result is emitted with no status | BL-010, BL-014 | unit test |
| AC-012 | `suppression_status` is one of the five categories or NULL | BL-012, BL-014 | schema `accepted_values` |
| AC-013 | `test_type` is `Baseline` or `Follow up` on every row | BL-005, BL-015 | schema `accepted_values` |
| AC-014 | `period_granularity` is `day` on the test ID and `month` on the patient-month ID | BL-002, BL-003 | schema `accepted_values` |

## Registry entries

`hiv_viral_load_test`, `hiv_viral_load_patient_month` in `documentations/metrics/hiv_viral_load.yml`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__measurement` | `clinical/` | Lab result, numeric value and operator |
| `lab_tests`, `lab_requests` | `bases/` | Sample collection date and lab test date (BL-008) |
| `derived__cohort_hiv` (or the deployment's equivalent) | `derived/` | HIV programme cohort membership (BL-007) |
| `clinical__person` | `clinical/` | Sex and date of birth |

## Open questions

None outstanding.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-28 | @beyondessential/maui | Add the canonical HIV viral load definition (MAUI-6864) |

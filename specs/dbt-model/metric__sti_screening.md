# dbt Model Spec: `metric__sti_screening`

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__sti_screening` |
| **Type** | dbt model |
| **Layer** | `metric` (over `int__sti_*`) |
| **Materialisation** | env-aware (`view` in the production bundle) |
| **Status** | `draft` |
| **Owner** | `@beyondessential/maui` |
| **Linear issue** | [MAUI-6637](https://linear.app/bes/issue/MAUI-6637) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-04 |
| **Last updated** | 2026-09-04 |

Registers six metric IDs in `documentations/metrics/sti.yml`. Deployment implementations bind these
clauses to local forms, lab catalogues and prescribing records, and number their own clauses from
BL-022 and AC-014 onward. The Fiji implementation is at
`tamanu-dbt-fiji/specs/dbt-model/metric__sti_screening.md`.

## Purpose

**What this artefact measures.** The STI screening cascade — for each infection, who was screened, who
screened positive, and who was treated — at patient grain per calendar month.

**Why it exists.** Screening coverage and treatment completion are the operational measures for an STI
programme. Without them a programme can see individual results but cannot say what proportion of its
population it reached, nor how many positives went untreated.

**Who consumes it.** Programme staff through Tupaia data tables, and deployment reports. Consumers read
this model rather than re-deriving the cascade.

## Grain

One row per `metric_id` × patient × infection × reporting month.

The `_key_population` metric IDs add a key population dimension: one row per patient per infection per
month **per key population the patient belongs to**. A patient in three key populations therefore
yields three `_key_population` rows and one base row for the same infection and month.

## Output schema

Follows the D5 standard shape.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the six registered IDs |
| `variant_id` | text | Null unless a deployment registers a definition variant |
| `subject_id` | uuid | Patient |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month, inclusive |
| `period_granularity` | text | `month` |
| `value_numeric` | numeric | `1` — the row asserts the fact; consumers sum |
| `value_boolean` | boolean | Unused |
| `infection` | text | `syphilis`, `gonorrhoea` or `chlamydia` |
| `key_population` | text | Null on the base IDs; the population on the `_key_population` IDs |
| `sex` | text | From the patient record |
| `age_group` | text | Banded from age at the earliest countable test in the month |
| `facility_id` | uuid | Attributed per BL-021 |

## Business logic

- **BL-000:** A patient is in scope for a month once the deployment's eligibility condition holds; deployments bind what makes a patient part of the screened population.
- **BL-001:** Every row carries a `metric_id` that is one of the six registered IDs.
- **BL-002:** The base IDs emit one row per patient per infection per month; the `_key_population` IDs emit one row per patient per infection per month per key population.
- **BL-003:** The reporting period is a calendar month, with `period_start` and `period_end` both inclusive and `period_granularity` set to `month`.
- **BL-004:** The infections covered are syphilis, gonorrhoea and chlamydia.
- **BL-005:** A screening test is a lab test whose type screens for one of those infections; deployments bind their own catalogue, and one test type may screen for more than one infection, yielding a row per infection.
- **BL-006:** A test is countable unless its request was withdrawn; deployments bind which request states count as withdrawn.
- **BL-007:** A test with no result recorded is countable, so the screened population includes tests still awaiting a result.
- **BL-008:** A patient is screened for an infection in a month where at least one countable test for that infection falls in that month.
- **BL-009:** A patient is positive for an infection in a month where at least one countable test in that month indicates infection; deployments bind which type and result combinations indicate it.
- **BL-010:** Treatment is a medication appropriate to the infection; deployments bind the medication set.
- **BL-011:** Treatment is an existence test, so a patient with several qualifying medications is treated once.
- **BL-012:** A medication counts as treatment where it starts no earlier than 28 days before the patient's earliest positive test in the month.
- **BL-013:** Treatment is read from both encounter-linked prescribing and any patient-level ongoing medication the deployment records.
- **BL-014:** A patient who is not positive for an infection in a month is not treated for it in that month.
- **BL-015:** Key population is a standing attribute of a patient, not a cohort with entry and exit dates.
- **BL-016:** A patient may belong to several key populations; each yields its own `_key_population` row, and the base row is emitted once regardless of how many apply.
- **BL-017:** The key populations are men who have sex with men, sex worker, people who inject drugs, pregnant, transgender, people living with HIV, youth aged 15 to 24, and adolescent aged 10 to 19; youth and adolescent overlap by definition.
- **BL-018:** Age is computed at the patient's earliest countable test in the month, not at the date the model runs.
- **BL-019:** A patient with no countable test for an infection in a month emits no row for that infection and month.
- **BL-020:** The canonical disaggregation columns are `infection`, `key_population`, `sex`, `age_group` and `facility_id`.
- **BL-021:** Facility is attributed to where the screening was delivered; deployments bind the attribution and may add local disaggregation columns beyond the canonical set.

## Acceptance criteria

Numbering stops at AC-013 so deployment implementations can number from AC-014 without collision.

Ten clauses carry no criterion here, and deliberately so. BL-000, BL-010, BL-013, BL-017 and BL-021
are the clauses a deployment binds, and are testable only once bound — a criterion written here could
not name the forms, medications or facilities it would assert against. BL-015 and BL-020 are structural
statements about shape rather than behaviour, held by the output schema. BL-016, BL-018 and BL-019 are
testable in principle but need a deployment's data to exercise, so implementations assert them: the Fiji
implementation covers BL-016 at its AC-019 and BL-018 through its age banding.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `metric_id` on every row is one of the six registered IDs | BL-001 | schema `accepted_values` |
| AC-002 | `metric_id` on every row resolves to a row in the metric registry | BL-001 | schema `relationships` |
| AC-003 | Base-ID output is unique on `metric_id`, `subject_id`, `infection`, `period_start` | BL-002 | `dbt_utils.unique_combination_of_columns` |
| AC-004 | `_key_population` output is unique on `metric_id`, `subject_id`, `infection`, `key_population`, `period_start` | BL-002 | `dbt_utils.unique_combination_of_columns` |
| AC-005 | `period_end` is the last day of the month `period_start` begins, and `period_granularity` is `month` | BL-003 | singular test |
| AC-006 | `infection` is one of `syphilis`, `gonorrhoea`, `chlamydia` | BL-004 | schema `accepted_values` |
| AC-007 | A test type screening two infections yields one row per infection | BL-005 | unit test |
| AC-008 | A test on a withdrawn request emits no row | BL-006 | unit test |
| AC-009 | A test with no result is counted as screened and not as positive | BL-007, BL-009 | unit test |
| AC-010 | Every positive patient-infection-month is also screened in that month | BL-008, BL-009 | singular test |
| AC-011 | A patient with several qualifying medications is treated once | BL-011 | unit test |
| AC-012 | A medication starting more than 28 days before the earliest positive test is not treatment, and one starting within 28 days is | BL-012 | unit test |
| AC-013 | Every treated patient-infection-month is also positive in that month | BL-014 | singular test |

## Lineage

```
lab tests ──────────────► int__sti_test_events ────┐
prescribing ────────────► int__sti_treatment ──────┼──► metric__sti_screening
patient attributes ─────► int__sti_key_populations ┘
```

All `int__` models are ephemeral. There is no `derived__` cohort: key population is a standing
attribute and a bridge, not a cohort with entry and exit dates (BL-015).

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | BL-012 sets the treatment window at 28 days before the earliest positive test. The figure came from the delivered Fiji extract rather than from a published standard. Should it be confirmed against WHO STI treatment guidance, and is a symmetric window after the test also needed? | @amanda | 2026-09-24 |
| OQ-002 | BL-013 admits patient-level ongoing medication as treatment. Where a deployment records dispensing separately from prescribing, should treatment read dispenses instead? | @amanda | 2026-09-24 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-04 | @beyondessential/maui | Initial draft: canonical STI screening cascade, six registered metric IDs (MAUI-6637) |

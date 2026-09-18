# dbt Model Spec: `metric__sti_screening_coverage` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__sti_screening_coverage` |
| **Type** | dbt model |
| **Layer** | `metric` |
| **Materialisation** | env-aware |
| **Status** | `draft` |
| **Owner** | `@beyondessential/maui` |
| **Linear issue** | [MAUI-6889](https://linear.app/bes/issue/MAUI-6889) |
| **Repo** | `tamanu-source-dbt` (definition); implemented per deployment |
| **Created** | 2026-09-18 |
| **Last updated** | 2026-09-18 |

Registers `sti_syphilis_screening_coverage`, `sti_gonorrhoea_screening_coverage` and
`sti_chlamydia_screening_coverage`. Definition only: which clinics a deployment runs STI services
from, and which lab results count as a test, are bindings rather than properties of the
measurement, so the model is built in the deployment repo — the same split `metric__sti_screening`
uses.

## Purpose

**What this artefact measures.** Of the key population patients attending STI services in a
reporting month, the share tested for a given infection.

**Clinical context.** Screening reach: whether the people coming through a service are actually
being offered and given the test.

**Who reads it.** Screening coverage indicators, through a consumer that divides the tested rows by
all of them.

## Grain

One row per patient per reporting month per key population they belong to, within each metric ID —
the infection being fixed by the metric ID rather than carried as a column.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the three registered IDs |
| `variant_id` | text | NULL unless a deployment registers a definition variant |
| `subject_id` | varchar | Patient, matching the registered `patient` subject grain. A patient is repeated once per key population, distinguished by `key_population` |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month |
| `period_granularity` | text | `month` |
| `value_numeric` | numeric | Always 1 |
| `value_boolean` | boolean | Unused |
| `tested` | boolean | Whether the patient was tested for this infection that month |
| `facility_id` | varchar | Tamanu facility, untranslated |
| `sex` | text | From `clinical__person` |
| `key_population` | text | The population this row counts the patient in |

## Business logic

- **BL-001:** A row is a patient who attended an STI service in the reporting month, counted once for that month however many times they attended.
- **BL-002:** Which services count as STI services is a deployment binding; the definition does not name clinics.
- **BL-003:** A patient is counted whether or not they were tested, so the denominator is not conditioned on the outcome it measures.
- **BL-004:** Key population membership recorded as an answer is a standing attribute of the patient, taken from their most recent answer recorded on or before the end of the reporting month, while a population defined by a patient attribute rather than an answer is evaluated for the reporting month.
- **BL-005:** A patient belonging to more than one key population contributes a row to each, so summing across populations double-counts them.
- **BL-006:** `tested` is true where the patient has a countable test for this infection dated in the reporting month.
- **BL-007:** The numerator and the denominator are the same rows, filtered by `tested`, so the numerator is contained in the denominator by construction rather than by agreement between two metrics. This is why coverage is registered as one metric and not as a testing metric divided by an attendance metric: the testing metrics apply no facility filter, so a patient tested away from an STI service would sit in such a numerator and not in its denominator, and the rate could exceed 100%.
- **BL-008:** A patient tested but not attending is out of scope entirely, which is what the indicator asks for — the share *of those attending* who were tested.
- **BL-009:** Every row carries `metric_id` set to its registered identifier, `value_numeric` 1, `period_granularity` of `month`, and a `period_start` on the first day of the reporting month.
- **BL-010:** No rate is stored. `value_numeric` is 1 per row and the consumer forms the rate.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | A patient attending twice in a month yields one row per key population | BL-001 | unit test |
| AC-002 | An untested attendee is counted, with `tested` false | BL-003, BL-006 | unit test |
| AC-003 | A patient in two key populations yields one row per population | BL-005 | unit test |
| AC-004 | A patient tested for the infection that month has `tested` true | BL-006 | unit test |
| AC-005 | A patient tested but not attending yields no row | BL-008 | unit test |
| AC-006 | `metric_id`, `subject_id`, `period_start` and `key_population` are unique together | Grain, BL-001 | `dbt_utils.unique_combination_of_columns` |
| AC-007 | Every emitted `metric_id` is registered | BL-009 | `relationships` to `metric_definitions` |
| AC-008 | `value_numeric` is always 1 | BL-009, BL-010 | schema `accepted_values` |
| AC-009 | `tested` is never null | BL-006 | schema `not_null` |
| AC-010 | A patient classified into an attribute-derived population in the testing metric is classified into the same population here | BL-004 | singular test |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a deployment should also register a standalone attendance metric, for indicators that count attendance rather than measure coverage over it. Not required by the coverage rate, which holds both sides in one row. | @beyondessential/maui | 2026-10-31 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-18 | @beyondessential/maui | Initial definition: STI screening coverage, numerator and denominator in one metric so containment is structural (MAUI-6889) |

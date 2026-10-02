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
| `facility_id` | varchar | Tamanu facility attended, untranslated |
| `sex` | text | From `clinical__person` |
| `age_years` | integer | Whole years at the earliest attendance in the month, unbanded |
| `key_population` | text | The population this row counts the patient in. Never NULL |

## Business logic

- **BL-001:** A row is a patient whose attendance in the reporting month counts under BL-002, counted once for that month however many times they attended.
- **BL-002:** Which attendance counts — which services are STI services, and whether the patient must be enrolled in the programme those services run — is a deployment binding; the definition names neither clinics nor an enrolment rule.
- **BL-003:** A patient is counted whether or not they were tested, so the denominator is not conditioned on the outcome it measures.
- **BL-004:** Key population membership recorded as an answer is a standing attribute of the patient, taken from their most recent answer recorded on or before the end of the reporting month, while a population defined by a patient attribute rather than an answer is evaluated for the reporting month.
- **BL-005:** A patient belonging to more than one key population contributes a row to each, so summing across populations double-counts them.
- **BL-006:** `tested` is true where the patient has a countable test for this infection dated in the reporting month. The population a row counts the patient in is settled by BL-004 on the attending side alone, so the mark says the patient was tested and does not additionally require the test to have been recorded against that population.
- **BL-007:** The numerator and the denominator are the same rows, filtered by `tested`, so the numerator is contained in the denominator by construction rather than by agreement between two metrics. This is why coverage is registered as one metric and not as a testing metric divided by an attendance metric: the testing metrics apply no facility filter, so a patient tested away from an STI service would sit in such a numerator and not in its denominator, and the rate could exceed 100%.
- **BL-008:** A patient tested but not attending is out of scope entirely, which is what the indicator asks for — the share *of those attending* who were tested.
- **BL-009:** Every row carries `metric_id` set to its registered identifier, `value_numeric` 1, `period_granularity` of `month`, and a `period_start` on the first day of the reporting month.
- **BL-010:** No rate is stored. `value_numeric` is 1 per row and the consumer forms the rate.
- **BL-011:** An attendee belonging to no key population produces no row, so `key_population` is never NULL and the denominator is the attending key population rather than all attendance.
- **BL-012:** `facility_id` is the Tamanu facility identifier, untranslated, and the rule attributing a patient-month attending more than one facility to a single facility is bound by the implementation, so a total grouped by facility attributes such a patient to one facility only.
- **BL-013:** `age_years` is whole years at the earliest attendance in the month, emitted unbanded, so a consumer bands the tested rows and all of them identically.
- **BL-014:** Where a deployment binds attendance to enrolled patients, the denominator is the enrolled key population attending, so the rate reads as coverage of the programme's own cohort rather than of everyone through the door.
- **BL-015:** The binding narrows both sides of the rate together, because BL-007 holds it in one set of rows, so a narrower attending population cannot push the rate above 100%.
- **BL-016:** Where two deployments would bind different attending populations to one metric id, that id no longer names a single measurement, so the narrower takes a `variant_of` row instead of a binding.

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
| AC-010 | A tested attendee is marked tested whatever population the testing metric classified them into | BL-006 | unit test |
| AC-011 | `key_population` is never null | BL-011 | schema `not_null` |
| AC-012 | A patient attending two facilities in a month yields one row per key population, attributed to one facility | BL-012 | unit test |
| AC-013 | `age_years` derives from the attendance date, not the run date | BL-013 | unit test |
| AC-014 | A patient attending an STI service but outside the bound attending population yields no row | BL-002, BL-014 | unit test |
| AC-015 | Every tested row has a matching row in the same metric id, so the rate never exceeds 100% | BL-007, BL-015 | singular test |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a deployment should also register a standalone attendance metric, for indicators that count attendance rather than measure coverage over it. Not required by the coverage rate, which holds both sides in one row. | @beyondessential/maui | 2026-10-31 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-18 | @beyondessential/maui | Initial definition: STI screening coverage, numerator and denominator in one metric so containment is structural (MAUI-6889) |
| 2026-09-19 | @beyondessential/maui | BL-006 no longer requires the test to be recorded against the row's own key population. Requiring it made the mark depend on two independently derived classifications agreeing, and an implementation deriving an age-based population from a different date on each side dropped tested patients from the numerator while keeping them in the denominator (MAUI-6889) |

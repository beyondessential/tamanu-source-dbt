# dbt Model Spec: `metric__hiv_testing` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__hiv_testing` |
| **Type** | dbt model |
| **Layer** | `metric` |
| **Materialisation** | env-aware (`view` in the production bundle) |
| **Status** | `draft` |
| **Owner** | `bes-maui` |
| **Repo** | `tamanu-source-dbt` (definition); implemented per deployment |
| **Linear issue** | [MAUI-6637](https://linear.app/bes/issue/MAUI-6637) |
| **Created** | 2026-09-08 |
| **Last updated** | 2026-09-08 |

Registers six metric IDs in `documentations/metrics/hiv_testing.yml`: `hiv_screening_test`,
`hiv_screening_test_event`, `hiv_screening_test_key_population`, and the same three names with
`confirmatory` in place of `screening`. `BL` and `AC` numbering is shared with the deployment
implementation specs and with the `-- BL-0xx` code comments, so an anchor resolves identically in
either. The canonical block is `BL-000`–`BL-022` and `AC-001`–`AC-014`; a canonical clause added
after a deployment spec has claimed the numbers above that block takes the next free number in the
shared sequence rather than a suffixed variant.

## Purpose

**What this artefact measures.** The two-stage HIV testing cascade: how many clients were screened,
how many of those screens were reactive, how many went on to a confirmatory test, and how many of
those confirmatory tests were positive — each stage counted both by test and by client-month.

**Clinical context.** HIV testing commonly runs a screen-then-confirm algorithm: a screening test
flags a reactive result, which a separate confirmatory test then verifies. The two stages use
different test types, are read at different points, and a client can be screened without ever
reaching confirmation, so they are modelled as two related but distinct metric families rather than
one pass/fail test.

**Who reads it.** Programme staff and ministry counterparts, through a consumer dashboard or export.

**What this artefact does not measure.** A coverage rate — the proportion of an eligible population
who were tested — needs a denominator this metric does not carry: the population who could have been
tested, tested or not. That population is sourced from attendance or registry data, not from a test
record, and computing the rate is a `dataset__` or report concern that joins this metric against it.
This metric answers "how many were tested and how many of those were positive", not "how many of
those who should have been tested were".

## Grain

Two grains per stage, registered as separate metric IDs rather than as a column, because summing
across grains answers two different questions. The client-month grain is one row per patient per
reporting month; the test-event grain is one row per countable test, so a patient tested twice in a
month contributes twice to the test-event grain and once to the client-month grain. The
`_key_population` IDs are the client-month grain further split to one row per patient per reporting
month per key population the patient belongs to.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the six registered IDs |
| `variant_id` | text | NULL unless a deployment registers a definition variant |
| `subject_id` | varchar | Patient, matching the registered `patient` subject grain. The `_key_population` IDs repeat a patient once per population, distinguished by `key_population` |
| `period_start` | date | Client-month IDs: first day of the reporting month. Test-event IDs: the test date |
| `period_end` | date | Client-month IDs: last day of the reporting month. Test-event IDs: the test date, unchanged |
| `period_granularity` | text | `month` on the client-month IDs, `day` on the test-event IDs |
| `value_numeric` | numeric | Always 1 |
| `value_boolean` | boolean | Unused |
| `facility_id` | varchar | Tamanu facility, untranslated |
| `sex` | text | From `clinical__person` |
| `age_years` | integer | Whole years at the test (client-month IDs: the earliest countable test in the month), unbanded |
| `is_positive` | boolean | Screening IDs: whether the test/month's screen was reactive. Confirmatory IDs: whether the test/month's confirmatory result was positive |
| `key_population` | text | NULL except on the `_key_population` IDs |

## Business logic

### Scope and grain

- **BL-000:** The metric covers two stages of the HIV testing cascade, screening and confirmatory testing, each a separate pair of registered metric IDs.
- **BL-001:** Every row carries `metric_id` set to its registered identifier and `value_numeric` 1.
- **BL-002:** On a client-month ID, `period_start` is the first day of the reporting month and a patient tested more than once within it contributes one row.
- **BL-003:** On a test-event ID, `period_start` is the test date and each countable test contributes its own row; two tests for the same patient on the same date are two rows, not one.
- **BL-004:** No relationship is asserted between a patient's screening rows and their confirmatory rows beyond both being scoped to the same patient — a client screened without ever being confirmatory-tested appears only in the screening IDs.

### Testing

- **BL-005:** A test counts once it is recorded against the patient, whatever its result.
- **BL-006:** A test whose request or result was withdrawn, cancelled, deleted or entered in error does not count.
- **BL-007:** A test recorded at a facility marked sensitive counts identically to one recorded elsewhere.
- **BL-008:** A test is attributed to the reporting month, or the reporting day on a test-event ID, containing its test date.
- **BL-009:** Which test types are read as a screening test and which as a confirmatory test is bound by the implementation.

### Result

- **BL-010:** On a client-month screening ID, `is_positive` is true where at least one countable screening test in the month was reactive.
- **BL-011:** On a client-month confirmatory ID, `is_positive` is true where at least one countable confirmatory test in the month was positive.
- **BL-012:** On a test-event ID, `is_positive` is the result of that test alone, not aggregated with any other test.
- **BL-013:** A result that does not indicate reactivity or positivity is negative, including an inconclusive or normal result.

### Key population

- **BL-014:** Key population membership recorded as an answer is a standing attribute of the patient, taken from their most recent answer recorded on or before the end of the reporting month, while a population defined by a patient attribute rather than an answer is evaluated for the reporting month.
- **BL-015:** The `_key_population` IDs emit one row per patient per key population they belong to, so summing across populations counts a multiply-classified patient more than once.
- **BL-016:** The client-month base IDs carry `key_population` as NULL and are the only screening or confirmatory IDs whose unfiltered total is a patient count; the test-event IDs carry no key population disaggregation at all.

### Cross-cutting

- **BL-017:** `age_years` is whole years at the test (client-month IDs: the earliest countable test in the month), emitted unbanded.
- **BL-018:** `facility_id` is the Tamanu facility identifier, untranslated, and the rule attributing a patient-month tested at more than one facility to a single facility is bound by the implementation, so a total grouped by facility attributes such a patient to one facility only.
- **BL-019:** Test patients are excluded, inherited from the base models.
- **BL-020:** A patient-month with no countable test of that stage produces no row on that stage's IDs.
- **BL-021:** No facility, programme registry or eligibility filter restricts which tests count; per the Purpose section, a coverage rate against an eligible or attending population is computed downstream of this metric, not within it.
- **BL-022:** This metric asserts no relationship between the two stages' positivity — a screening ID's `is_positive` says nothing about whether that patient was subsequently confirmatory-tested, and vice versa.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | Every row's `metric_id` is one of the six registered IDs | BL-001 | schema `accepted_values` |
| AC-002 | On each client-month ID, `metric_id`, `subject_id`, `period_start` and `key_population` are unique together | BL-002 | `dbt_utils.unique_combination_of_columns` |
| AC-003 | Every `metric_id` resolves against the metric registry | BL-001 | `relationships` to `metric_definitions` |
| AC-004 | `value_numeric` is always 1 | BL-001 | schema `accepted_values` |
| AC-005 | A patient tested twice for one stage in a month yields one row on that stage's client-month ID | BL-002 | unit test |
| AC-006 | A patient tested twice for one stage in a month yields two rows on that stage's test-event ID | BL-003 | unit test |
| AC-007 | A test at a sensitive facility is counted | BL-007 | unit test |
| AC-008 | A withdrawn or cancelled test is not counted | BL-006 | unit test |
| AC-009 | `age_years` derives from the test date, not the run date | BL-017 | unit test |
| AC-010 | A patient in three key populations yields three `_key_population` rows and one client-month base row | BL-015 | unit test |
| AC-011 | A patient screened but never confirmatory-tested appears on a screening ID and on no confirmatory ID | BL-004 | unit test |
| AC-012 | `key_population` is NULL on every client-month base row and every test-event row, and non-NULL on every `_key_population` row | BL-015, BL-016 | singular test |
| AC-013 | A test-event ID's `period_granularity` is always `day`; a client-month ID's is always `month` | BL-002, BL-003 | schema `accepted_values` |
| AC-014 | A test for a patient with no programme registry or attendance record at that facility is still counted | BL-021 | unit test |

## Registry entries

**Screening (3):** `hiv_screening_test`, `hiv_screening_test_event`, `hiv_screening_test_key_population`

**Confirmatory (3):** `hiv_confirmatory_test`, `hiv_confirmatory_test_event`, `hiv_confirmatory_test_key_population`

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| Fiji | `tamanu-dbt-fiji` | `specs/dbt-model/metric__hiv_testing.md` (pending) |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether `hiv_screening_test` and `hiv_confirmatory_test` should each additionally emit a `retested` flag or similar, to carry forward Fiji's existing Indicator 4 (retesting) concept, or whether retesting is better served as its own metric reading the same test-event ID. | `bes-maui` | TBD |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-08 | @beyondessential/maui | Initial draft: canonical definition of the six HIV screening and confirmatory testing metric IDs (MAUI-6637) |

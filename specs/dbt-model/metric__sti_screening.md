# dbt Model Spec: `metric__sti_screening` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__sti_screening` |
| **Type** | dbt model |
| **Layer** | `metric` |
| **Materialisation** | env-aware (`view` in the production bundle) |
| **Status** | `draft` |
| **Owner** | `bes-maui` |
| **Repo** | `tamanu-source-dbt` (definition); implemented per deployment |
| **Linear issue** | [MAUI-6637](https://linear.app/bes/issue/MAUI-6637) |
| **Created** | 2026-09-02 |
| **Last updated** | 2026-09-05 |

Registers six metric IDs in `documentations/metrics/sti.yml`: `sti_{syphilis,gonorrhoea,chlamydia}_test`
and a `_key_population` counterpart for each. `BL` and `AC` numbering is shared with the deployment
implementation specs and with the `-- BL-0xx` code comments, so an anchor resolves identically in
either. The canonical block is `BL-000`–`BL-021` and `AC-001`–`AC-013`; a canonical clause added
after a deployment spec has claimed the numbers above that block takes the next free number in the
shared sequence rather than a suffixed variant.

## Purpose

**What this artefact measures.** Sexually transmitted infection screening as a cascade: how many
patients were tested for each infection, how many tested positive, and how many of those positives
received treatment — with a parallel cut by key population.

**Clinical context.** Syphilis, gonorrhoea and chlamydia screening delivered through sexual and
reproductive health services, commonly alongside HIV testing. Programme performance is judged on
testing coverage among key populations and on how completely positives are treated, so the three
cascade stages have to reconcile against one another for the same patients.

**Who reads it.** Programme staff and ministry counterparts, through a consumer dashboard or export.

## Grain

One row per patient per reporting month within each metric ID, the infection being fixed by the
metric ID rather than carried as a column. The `_key_population` IDs add a further row per key
population the patient belongs to.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the six registered IDs |
| `variant_id` | text | NULL unless a deployment registers a definition variant |
| `subject_id` | varchar | Patient, matching the registered `patient` subject grain. The `_key_population` IDs repeat a patient once per population, distinguished by `key_population` |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month |
| `period_granularity` | text | `month` |
| `value_numeric` | numeric | Always 1 |
| `value_boolean` | boolean | Unused |
| `facility_id` | varchar | Tamanu facility, untranslated |
| `sex` | text | From `clinical__person` |
| `age_years` | integer | Whole years at the earliest countable test in the month, unbanded |
| `is_positive` | boolean | Whether any countable test in the month indicated infection |
| `treatment_status` | text | `Treated`, `Untreated`, or `Not applicable` |
| `key_population` | text | NULL on the base IDs |

## Business logic

### Scope and grain

- **BL-000:** The metric covers syphilis, gonorrhoea and chlamydia screening, and each infection is a separate registered metric ID.
- **BL-001:** Every row carries `metric_id` set to its registered identifier, `value_numeric` 1, and a `period_start` on the first day of the reporting month.
- **BL-002:** A patient tested more than once for one infection within a reporting month contributes one row for that infection and month.
- **BL-003:** A patient tested for two infections by one specimen contributes one row to each infection's metric.

### Testing

- **BL-004:** A test counts once it is recorded against the patient, whatever its result.
- **BL-005:** A test whose request or result was withdrawn, cancelled, deleted or entered in error does not count.
- **BL-006:** A test recorded at a facility marked sensitive counts identically to one recorded elsewhere.
- **BL-007:** A test is attributed to the reporting month containing its test date.

### Result

- **BL-008:** `is_positive` is true where at least one countable test for that infection in the month indicated infection.
- **BL-009:** A result that does not indicate infection is negative, including an inconclusive or normal result.

### Treatment

- **BL-010:** `treatment_status` is `Not applicable` where `is_positive` is false.
- **BL-011:** `treatment_status` is `Treated` where the patient holds an order for a medication indicated for that infection, dated within a window that opens 28 days before their earliest positive result for that infection and closes a bounded interval after it, with the medication set and the closing interval bound by the implementation.
- **BL-054:** `treatment_status` is `Untreated` where `is_positive` is true and no such order exists, so the three values are exhaustive and the column is never NULL.
- **BL-012:** An ongoing medication order is subject to the same date bound as BL-011 and counts only where it starts no earlier than 28 days before the earliest positive result, so being currently active is not on its own sufficient.
- **BL-013:** Antiretroviral therapy for HIV is not treatment for these infections.
- **BL-014:** `treatment_status` is evaluated as at query time, so a past month's treated count rises when a patient is treated after that month.

### Key population

- **BL-015:** Key population membership recorded as an answer is a standing attribute of the patient, taken from their most recent answer recorded on or before the end of the reporting month, while a population defined by a patient attribute rather than an answer is evaluated for the reporting month.
- **BL-016:** The `_key_population` IDs emit one row per patient per key population they belong to, so summing across populations counts a multiply-classified patient more than once.
- **BL-017:** The base IDs carry `key_population` as NULL and are the only IDs whose unfiltered total is a patient count.

### Cross-cutting

- **BL-018:** `age_years` is whole years at the earliest countable test for that infection in the month, emitted unbanded.
- **BL-019:** `facility_id` is the Tamanu facility identifier, untranslated, and the rule attributing a patient-month tested at more than one facility to a single facility is bound by the implementation, so a total grouped by facility attributes such a patient to one facility only.
- **BL-020:** Test patients are excluded, inherited from the base models.
- **BL-021:** A patient-month with no countable test produces no row.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | Every row's `metric_id` is one of the six registered IDs | BL-001 | schema `accepted_values` |
| AC-002 | Each `metric_id` has one row per grain tuple | Grain | `dbt_utils.unique_combination_of_columns` |
| AC-003 | Every `metric_id` resolves against the metric registry | BL-001 | `relationships` to `metric_definitions` |
| AC-004 | `value_numeric` is always 1 | BL-001 | schema `accepted_values` |
| AC-005 | `treatment_status` is `Not applicable` wherever `is_positive` is false | BL-010 | singular test |
| AC-006 | `treatment_status` is never `Not applicable` where `is_positive` is true | BL-010, BL-011 | singular test |
| AC-007 | `key_population` is NULL on every base-ID row and non-NULL on every `_key_population` row | BL-016, BL-017 | singular test |
| AC-008 | A patient tested twice for one infection in a month yields one row | BL-002 | unit test |
| AC-009 | A specimen screening two infections yields one row per infection | BL-003 | unit test |
| AC-010 | A test at a sensitive facility is counted | BL-006 | unit test |
| AC-011 | A withdrawn or cancelled test is not counted | BL-005 | unit test |
| AC-012 | A medication order more than 28 days before the earliest positive does not make a patient `Treated` | BL-011, BL-012 | unit test |
| AC-013 | `age_years` derives from the test date, not the run date | BL-018 | unit test |
| AC-036 | A medication order dated after the window's closing bound does not make a patient `Treated` | BL-011 | unit test |
| AC-035 | `treatment_status` is always one of `Treated`, `Untreated` or `Not applicable`, and never NULL | BL-010, BL-054 | schema `accepted_values` + `not_null` |

## Registry entries

**Base (3):** `sti_syphilis_test`, `sti_gonorrhoea_test`, `sti_chlamydia_test`

**Key population (3):** `sti_syphilis_test_key_population`, `sti_gonorrhoea_test_key_population`,
`sti_chlamydia_test_key_population`

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| Fiji | `tamanu-dbt-fiji` | `specs/dbt-model/metric__sti_screening.md` (pending) |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether the reporting-month grain (BL-002) is the right default, or whether a test-event grain should be offered alongside it for laboratory volume reporting. The month grain answers "how many people were tested"; it cannot answer "how many tests were performed". | `bes-maui` | TBD |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-02 | @beyondessential/maui | Initial draft: canonical definition of the six STI screening metric IDs (MAUI-6637) |
| 2026-09-05 | @beyondessential/maui | Require treatment to be indicated for the infection and bound the treatment window at both ends (BL-011) |

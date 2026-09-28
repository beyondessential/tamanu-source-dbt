# dbt Model Spec: `metric__ed_lab_request` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ed_lab_request` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `ed_lab_request`: one row per lab test requested during the emergency
phase of an encounter. A sibling of `metric__ed_procedure` and `metric__ed_imaging_request`,
scoped the same way.

## Purpose

Lab tests requested during emergency care, one row per test.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_lab_request` | count | Lab tests requested in an ED phase (always 1 per row) |

**Who reads it.** The Tupaia Emergency Department dashboard's lab tests table and summary table
(MAUI-6907), via a data table in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of lab tests requested in the emergency setting -- no external body registers this indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the Tamanu lab test id, so a
panel requesting several tests contributes one row per test. Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_lab_request` |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The Tamanu lab test id |
| `period_start` | timestamp | When the request was raised (BL-003) |
| `period_end` | timestamp | When the request was published, NULL unless completed (BL-003) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1` (BL-008) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The qualifying segment's location's facility (BL-005) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | Whether the request was published (BL-003) |
| `lab_test_code` | text | The test type's code (BL-006) |
| `lab_test` | text | The test type's name (BL-006) |
| `age_years` | integer | Age in whole years at the request, unbanded -- a measure, not a dimension |
| `department` | text | The qualifying segment's department, resolved to a name (BL-007) |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every lab test on a lab request whose status is not `deleted` or `entered-in-error`, including a request with no status, is a candidate, whether or not it has produced a result.
- **BL-002 (segment):** each test resolves to the `clinical__visit_detail` segment active at its request's `requested_datetime`, clamped to the encounter's first segment where the request predates every segment, by `visit_detail__active_segment`.
- **BL-003 (period and completion):** `period_start` is the request's `requested_datetime`, `is_completed` is true only when the request's status is `published`, and `period_end` is its `published_datetime` only when `is_completed`.
- **BL-004 (emergency scope):** a test is counted only when its segment carries OMOP concept 9203, so a test requested while the patient boards in the admission segment is not counted.
- **BL-005 (facility):** `facility_id` is the facility of the segment's `care_site_id`, and a test whose patient or segment location does not resolve is excluded.
- **BL-006 (test type):** `lab_test_code` and `lab_test` are the test type's code and name, falling back to the code and then `'Not recorded'`, never NULL.
- **BL-007 (department):** `department` is the segment's department name, `'Not recorded'` where it does not resolve.
- **BL-008 (registration and count):** `metric_id` is the constant `'ed_lab_request'` and `value_numeric` the constant `1`, so a consumer sums it to count tests at any grain.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-008 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `ed_lab_request` and registered in `metric_definitions` | BL-008 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `period_start`, `period_granularity`, `value_numeric`, `facility_id`, `is_completed`, `lab_test_code`, `lab_test` and `department` are `not_null` | BL-003, BL-005, BL-006, BL-007, BL-008 | `not_null` |
| AC-004 | `period_end` is set only when `is_completed`, and is at or after `period_start` | BL-003 | `dbt_utils.expression_is_true` + `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-005 | Only 9203 segments are counted, a test in the boarding segment is not, a request predating its segments clamps to the first, withdrawn requests are excluded while cancelled ones and one with no status are counted as not completed with no `period_end`, and a panel contributes one row per test | BL-001 -- BL-004 | unit test `ac_005_metric__ed_lab_request_scope_and_completion` |

## Registry entry

Registered in `documentations/metrics/emergency.yml` as `ed_lab_request`, `kind: metric`,
`unit: count`, `subject_grain: lab_test`, with disaggregations `facility_id`, `sex`,
`is_completed`, `lab_test`, `lab_test_code` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `lab_requests`, `lab_tests`, `lab_test_types` | The population, request time, completion and test type (BL-001, BL-003, BL-006) |
| `clinical__visit_detail` | The segment whose OMOP concept decides inclusion (BL-002, BL-004) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-005) |
| `departments` | Department name resolution (BL-007) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia ED dashboard | The lab tests table, ranked high to low, and the summary table (MAUI-6907) |

## Related

| Artefact | Relationship |
|---|---|
| `metric__lab_request` | Counts completed tests carrying a reading, dated at completion, across all settings -- a different population on a different clock |
| `metric__ed_imaging_request` | Sibling ED metric, the same request-time scoping and completion gating |
| `metric__ed_procedure` | Sibling ED metric |
| `metric__emergency_visit` | The attendance population these tests sit within |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-28 | Maui team | Initial draft (MAUI-6907) |

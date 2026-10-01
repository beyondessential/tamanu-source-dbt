# dbt Model Spec: `metric__ed_lab_order` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ed_lab_order` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `ed_lab_order`: one row per lab test panel, and per lab test ordered
outside a panel, requested during the emergency phase of an encounter: what the clinician
ordered, not the tests a panel expands to. A sibling of `metric__ed_imaging_request` and
`metric__ed_pharmacy_order`, scoped the same way.

## Purpose

Lab orders placed during emergency care, one row per order line.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_lab_order` | count | Panels and individually ordered tests requested in an ED phase (always 1 per row) |

**Who reads it.** The Tupaia Emergency Department dashboard's lab tests/panels table and summary
table (MAUI-6907), via a data table in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of lab orders placed in the emergency setting -- no external body registers this indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the lab request id for a panel
and the lab test id for a test ordered outside a panel. Tamanu raises one lab request per panel
ordered, holding every test in the panel, and one lab request per test category for tests
ordered individually. Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_lab_order` |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The lab request id for a panel, the lab test id otherwise (BL-002, BL-003) |
| `period_start` | timestamp | When the request was raised (BL-004) |
| `period_end` | timestamp | When the request was published, NULL unless completed (BL-004) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1` (BL-009) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The qualifying segment's location's facility (BL-006) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | Whether the request was published (BL-004) |
| `is_panel` | boolean | Whether the order line is a panel (BL-002, BL-003) |
| `lab_order_code` | text | The panel's code, or the test type's code (BL-007) |
| `lab_order` | text | The panel's name, or the test type's name (BL-007) |
| `age_years` | integer | Age in whole years at the request, unbanded -- a measure, not a dimension |
| `department` | text | The qualifying segment's department, resolved to a name (BL-008) |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every lab request whose status is not `deleted` or `entered-in-error`, including a request with no status, is a candidate, whether or not it has produced a result.
- **BL-002 (panel orders):** a request carrying a `lab_test_panel_request_id` is one order line keyed on the request, with `is_panel` true, however many tests it holds.
- **BL-003 (individual orders):** a request with no `lab_test_panel_request_id` contributes one order line per test on it, keyed on the test, with `is_panel` false.
- **BL-004 (period and completion):** `period_start` is the request's `requested_datetime`, `is_completed` is true only when the request's status is `published`, and `period_end` is its `published_datetime` only when `is_completed`.
- **BL-005 (emergency scope):** each order line resolves to the `clinical__visit_detail` segment active at its request's `requested_datetime`, clamped to the encounter's first segment where the request predates every segment, by `visit_detail__active_segment`, and is counted only when that segment carries OMOP concept 9203.
- **BL-006 (facility):** `facility_id` is the facility of the segment's `care_site_id`, and an order line whose patient or segment location does not resolve is excluded.
- **BL-007 (label):** `lab_order_code` and `lab_order` are the panel's code and name for a panel and the test type's code and name otherwise, falling back to the code and then `'Not recorded'`, never NULL.
- **BL-008 (department):** `department` is the segment's department name, `'Not recorded'` where it does not resolve.
- **BL-009 (registration and count):** `metric_id` is the constant `'ed_lab_order'` and `value_numeric` the constant `1`, so a consumer sums it to count order lines at any grain.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-009 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `ed_lab_order` and registered in `metric_definitions` | BL-009 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `period_start`, `period_granularity`, `value_numeric`, `facility_id`, `is_completed`, `is_panel`, `lab_order_code`, `lab_order` and `department` are `not_null` | BL-004, BL-006, BL-007, BL-008, BL-009 | `not_null` |
| AC-004 | `period_end` is set only when `is_completed`, and is at or after `period_start` | BL-004 | `dbt_utils.expression_is_true` + `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-005 | A panel is one row labelled with the panel, individually ordered tests are a row each, a panel whose panel request does not resolve stays one row, only 9203 segments are counted, a request in the boarding segment is not, a request predating its segments clamps to the first, and withdrawn requests are excluded | BL-001 -- BL-007 | unit test `ac_005_metric__ed_lab_order_scope_and_grouping` |

## Registry entry

Registered in `documentations/metrics/emergency.yml` as `ed_lab_order`, `kind: metric`,
`unit: count`, `subject_grain: lab_order`, with disaggregations `facility_id`, `sex`,
`is_completed`, `is_panel`, `lab_order`, `lab_order_code` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `lab_requests`, `lab_tests`, `lab_test_types` | The population, request time, completion and individual test labels (BL-001, BL-003, BL-004, BL-007) |
| `lab_test_panel_requests`, `lab_test_panels` | The panel an order line was raised from (BL-002, BL-007) |
| `clinical__visit_detail` | The segment whose OMOP concept decides inclusion (BL-005) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-006) |
| `departments` | Department name resolution (BL-008) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia ED dashboard | The lab tests/panels table, ranked high to low, and the summary table (MAUI-6907) |

## Related

| Artefact | Relationship |
|---|---|
| `metric__lab_test` | Resulted lab tests one row per test, across all settings, dated at completion |
| `metric__ed_pharmacy_order` | Sibling ED metric, the same request-time scoping |
| `metric__ed_imaging_request` | Sibling ED metric, the same request-time scoping and completion gating |
| `metric__emergency_visit` | The attendance population these orders sit within |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-29 | Maui team | Initial draft (MAUI-6907) |

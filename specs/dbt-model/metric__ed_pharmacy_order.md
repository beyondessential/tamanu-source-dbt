# dbt Model Spec: `metric__ed_pharmacy_order` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ed_pharmacy_order` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `ed_pharmacy_order`: one row per pharmacy order drug line placed during
the emergency phase of an encounter. The emergency-side counterpart of `metric__pharmacy_order`,
scoped the same way as `metric__ed_procedure` and `metric__ed_imaging_request`.

## Purpose

Medications ordered from the pharmacy during emergency care, one row per ordered drug line.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_pharmacy_order` | count | Pharmacy order drug lines placed in an ED phase (always 1 per row) |

**Who reads it.** The Tupaia Emergency Department dashboard's medications table and summary table
(MAUI-6907), via a data table in `tupaia-data-product`. A consumer forms the dispensed count by
filtering on `is_completed`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of pharmacy order drug lines in the emergency setting -- no external body registers this indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the
`pharmacy_order_prescriptions` id, so an order bundling several drugs contributes one row per
drug. Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_pharmacy_order` |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The pharmacy order drug line id |
| `period_start` | date | The date the order was placed (BL-003) |
| `period_end` | date | NULL -- unused |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-008) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The qualifying segment's location's facility (BL-005) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | Whether the drug line was dispensed (BL-003) |
| `drug_source_value` | text | The medication's code (BL-006) |
| `drug_source_name` | text | The medication's name (BL-006) |
| `age_years` | integer | Age in whole years at the order, unbanded -- a measure, not a dimension |
| `department` | text | The qualifying segment's department, resolved to a name (BL-007) |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every drug line on a pharmacy order is a candidate, whether or not it has been dispensed.
- **BL-002 (segment):** each drug line resolves to the `clinical__visit_detail` segment active at its order's `datetime`, clamped to the encounter's first segment where the order predates every segment, by `visit_detail__active_segment`.
- **BL-003 (period and completion):** `period_start` is the order's date and `is_completed` is the drug line's own dispensed flag.
- **BL-004 (emergency scope):** a drug line is counted only when its segment carries OMOP concept 9203, so an order placed while the patient boards in the admission segment is not counted.
- **BL-005 (facility):** `facility_id` is the facility of the segment's `care_site_id`, and a drug line whose patient or segment location does not resolve is excluded.
- **BL-006 (medication):** `drug_source_value` and `drug_source_name` are the code and name of the prescription's medication, from whichever of the encounter prescription or the ongoing prescription the line carries, `'Not recorded'` where it does not resolve.
- **BL-007 (department):** `department` is the segment's department name, `'Not recorded'` where it does not resolve.
- **BL-008 (registration and count):** `metric_id` is the constant `'ed_pharmacy_order'` and `value_numeric` the constant `1`, so a consumer sums it to count drug lines at any grain.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-008 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `ed_pharmacy_order` and registered in `metric_definitions` | BL-008 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `period_start`, `period_granularity`, `value_numeric`, `facility_id`, `is_completed`, `drug_source_value`, `drug_source_name` and `department` are `not_null` | BL-003, BL-005, BL-006, BL-007, BL-008 | `not_null` |
| AC-004 | Only 9203 segments are counted, a drug line in the boarding segment is not, an order predating its segments clamps to the first, an ongoing-prescription line resolves its medication, and an unresolved medication falls back to `'Not recorded'` | BL-001 -- BL-006 | unit test `ac_004_metric__ed_pharmacy_order_scope` |

## Registry entry

Registered in `documentations/metrics/emergency.yml` as `ed_pharmacy_order`, `kind: metric`,
`unit: count`, `subject_grain: pharmacy_order_prescription`, with disaggregations `facility_id`,
`sex`, `is_completed`, `drug_source_value`, `drug_source_name` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `pharmacy_order_prescriptions`, `pharmacy_orders` | The population, order time and dispensed flag (BL-001, BL-003) |
| `prescriptions`, `reference_data` | The medication (BL-006) |
| `clinical__visit_detail` | The segment whose OMOP concept decides inclusion (BL-002, BL-004) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-005) |
| `departments` | Department name resolution (BL-007) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia ED dashboard | The medications table, ranked high to low, and the dispensed count in the summary table (MAUI-6907) |

## Related

| Artefact | Relationship |
|---|---|
| `metric__pharmacy_order` | The same population across all settings, resolving the segment the same way and carrying its setting as `visit_detail_concept_id` rather than filtering to one |
| `metric__ed_lab_order`, `metric__ed_imaging_request`, `metric__ed_procedure` | Sibling ED metrics, the same scoping |
| `metric__emergency_visit` | The attendance population these orders sit within |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-28 | Maui team | Initial draft (MAUI-6907) |

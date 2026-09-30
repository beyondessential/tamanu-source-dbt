# dbt Model Spec: `metric__pharmacy_order` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__pharmacy_order` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6807 |

Canonical definition for `pharmacy_order`: one row per drug line ordered to pharmacy, in every
setting, attributed to the encounter segment the patient was in when the order was placed.

## Purpose

Medications ordered from the pharmacy, one row per ordered drug line, and whether each has been
dispensed.

| `metric_id` | Unit | Measures |
|---|---|---|
| `pharmacy_order` | count | Ordered drug lines (always 1 per row) |

**Who reads it.** Tupaia pharmacy cards via data tables in `tupaia-data-product`. A consumer
forms the dispensed count by filtering on `is_completed`, and the dispensing rate as
`sum(value_numeric) filter (where is_completed) / sum(value_numeric)`. A consumer scopes to one
setting by filtering `encounter_setting`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of ordered drug lines -- no external body registers a dispensing-status indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the
`pharmacy_order_prescriptions` id. The ordered drug line is the unit, not the pharmacy order (which
can bundle several lines) and not the physical dispense event (a line can be filled across 0..n
dispenses). Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `pharmacy_order` (BL-005) |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The pharmacy order drug line id |
| `period_start` | date | The date the order was placed (BL-006) |
| `period_end` | date | NULL -- a pharmacy order is point-in-time |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-005) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The facility of the active segment's location (BL-009) |
| `encounter_type` | varchar(255) | The active segment's encounter type (BL-010) |
| `encounter_setting` | text | `Outpatient`, `Inpatient` or `Other`, from the active segment's OMOP concept (BL-010) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | Whether the drug line has been dispensed (BL-006) |
| `drug_source_value` | text | The medication's code (BL-001, BL-004) |
| `drug_source_name` | text | The medication's name (BL-001, BL-004) |
| `age_years` | integer | Age in whole years at the order, unbanded -- a measure, not a dimension |
| `department` | text | The active segment's department, resolved to a name (BL-007) |

## Data tables

The Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (medication source):** the medication is resolved from `prescriptions` and `reference_data` directly.
- **BL-002 (population):** every drug line on a pharmacy order is a candidate, in every setting, whether or not it has been dispensed.
- **BL-003 (prescription):** a drug line carries either an encounter prescription or an ongoing prescription, never both, and the medication is read from whichever is set.
- **BL-004 (medication fallback):** `drug_source_value` and `drug_source_name` are `'Not recorded'` where the prescription or its medication does not resolve, so the drug line is kept.
- **BL-005 (registration and count):** `metric_id` is the constant `'pharmacy_order'` and `value_numeric` the constant `1`, so a consumer sums it to count drug lines at any grain.
- **BL-006 (period and completion):** `period_start` is the order's date and `is_completed` is the drug line's own dispensed flag.
- **BL-007 (department):** `department` is the active segment's department name, `'Not recorded'` where it does not resolve.
- **BL-008 (segment):** each drug line resolves to the `clinical__visit_detail` segment active at its order's `datetime`, clamped to the encounter's first segment where the order predates every segment, by `visit_detail__active_segment`. A drug line whose encounter has no segment is excluded.
- **BL-009 (facility):** `facility_id` is the facility of the active segment's `care_site_id`, and a drug line whose patient or segment location does not resolve is excluded.
- **BL-010 (setting):** `encounter_setting` is `Inpatient` for OMOP concept 9201, `Outpatient` for 9202 and `Other` for everything else, and `encounter_type` is the active segment's own encounter type. An emergency-phase order falls in `Other` -- emergency reporting reads `metric__ed_pharmacy_order`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-005 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `pharmacy_order` and registered in `metric_definitions` | BL-005 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `subject_id`, `period_start`, `period_granularity`, `value_numeric`, `facility_id`, `encounter_type`, `encounter_setting`, `is_completed`, `drug_source_value`, `drug_source_name` and `department` are `not_null` | BL-004 -- BL-010 | `not_null` |
| AC-004 | `period_end` is always NULL and `period_granularity` always `'day'` | BL-006 | `expect_column_values_to_be_null` + `accepted_values` |
| AC-005 | `encounter_setting` is one of `Outpatient`, `Inpatient`, `Other` | BL-010 | `accepted_values` |
| AC-006 | Facility, department and setting follow the segment active at the order, not the encounter's later segment; an order predating its segments clamps to the first; an order on a segment's start time falls in that segment; an order after the last segment began falls in the last segment; an emergency-phase order reads `Other`; a drug line on an encounter with no segment is dropped; an ongoing-prescription line resolves its medication; an unresolved medication falls back to `'Not recorded'` | BL-002 -- BL-004, BL-007 -- BL-010 | unit test `ac_006_metric__pharmacy_order_segment` |
| AC-007 | Every drug line in `pharmacy_order_prescriptions` has a row, so a drug line dropped for want of a segment, patient or location is surfaced | BL-002, BL-008, BL-009 | `dbt_utils.equal_rowcount` against `pharmacy_order_prescriptions` (`warn`) |

## Registry entry

Registered in `documentations/metrics/pharmacy.yml` as `pharmacy_order`, `kind: metric`,
`unit: count`, `subject_grain: pharmacy_order_prescription`, with disaggregations `facility_id`,
`encounter_type`, `encounter_setting`, `sex`, `is_completed`, `drug_source_value`,
`drug_source_name` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `pharmacy_order_prescriptions`, `pharmacy_orders` | The population, order time and dispensed flag (BL-002, BL-006) |
| `prescriptions`, `reference_data` | The medication (BL-001, BL-003, BL-004) |
| `clinical__visit_detail` | The active segment, its OMOP concept and department (BL-007, BL-008, BL-010) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-009) |
| `departments` | Department name resolution (BL-007) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia pharmacy cards | The dispensing rate and dispensed counts, via `pharmacy_order__standard` |

## Related

| Artefact | Relationship |
|---|---|
| `metric__ed_pharmacy_order` | The emergency-phase counterpart, resolving the segment the same way and counting only 9203 segments |
| `metric__procedure`, `metric__lab_order` | The same segment attribution and the same `encounter_setting` values |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-30 | Maui team | Spec written; facility, department and setting resolved from the active segment |

# dbt Model Spec: `metric__ed_medication_dispense` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ed_medication_dispense` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `ed_medication_dispense`: one row per medication dispense against a drug
line ordered during the emergency phase of an encounter, dated to the day it was dispensed. The
emergency-side counterpart of `metric__medication_dispense`, and the dispensing counterpart of
`metric__ed_pharmacy_order`, scoped the same way.

## Purpose

Medication handed over by pharmacy for emergency care, counted on the day it happened.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_medication_dispense` | count | Dispenses against ED-phase drug lines (always 1 per row) |

**Who reads it.** The Tupaia Emergency Department dashboard's medications dispensed table and the
summary table's medications dispensed column (MAUI-6907), via a data table in
`tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of medication dispenses in the emergency setting -- no external body registers this indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the `medication_dispenses` id. A
drug line dispensed in several partial fills has one row per fill. Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_medication_dispense` |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The medication dispense id |
| `period_start` | date | The date the medication was dispensed (BL-002) |
| `period_end` | date | NULL -- unused |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-008) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The ordering segment's location's facility (BL-004) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `drug_source_value` | text | The dispensed medication's code (BL-006) |
| `drug_source_name` | text | The dispensed medication's name (BL-006) |
| `age_years` | integer | Age in whole years on the day of the dispense, unbanded |
| `department` | text | The ordering segment's department, resolved to a name (BL-007) |
| `quantity` | numeric | The quantity handed over in the dispense (BL-009) |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every medication dispense against a drug line on a pharmacy order is a candidate.
- **BL-002 (period):** `period_start` is the date of the dispense's `dispensed_at`.
- **BL-003 (segment):** each dispense resolves to the `clinical__visit_detail` segment active at its drug line's order `datetime`, clamped to the encounter's first segment where the order predates every segment, by `visit_detail__active_segment`.
- **BL-004 (facility):** `facility_id` is the facility of the segment's `care_site_id`, and a dispense whose patient or segment location does not resolve is excluded.
- **BL-005 (emergency scope):** a dispense is counted only when its ordering segment carries OMOP concept 9203, so a drug line ordered while the patient boards in the admission segment is not counted.
- **BL-006 (medication):** `drug_source_value` and `drug_source_name` are the code and name of the dispense's own medication, `'Not recorded'` where it does not resolve.
- **BL-007 (department):** `department` is the segment's department name, `'Not recorded'` where it does not resolve.
- **BL-008 (registration and count):** `metric_id` is the constant `'ed_medication_dispense'` and `value_numeric` the constant `1`, so a consumer sums it to count dispenses at any grain.
- **BL-009 (quantity):** `quantity` is the dispense's own recorded quantity.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-008 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `ed_medication_dispense` and registered in `metric_definitions` | BL-008 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `period_start`, `period_granularity`, `value_numeric`, `facility_id`, `drug_source_value`, `drug_source_name` and `department` are `not_null` | BL-002, BL-004, BL-006 -- BL-008 | `not_null` |
| AC-004 | Only dispenses on 9203-segment drug lines are counted, a drug line dispensed twice has a row on each dispense's own date, a substituted drug reports the dispensed medication, an unresolved medication falls back to `'Not recorded'`, a line ordered while boarding is not counted, and an order predating its segments clamps to the first | BL-001 -- BL-007, BL-009 | unit test `ac_004_metric__ed_medication_dispense_scope` |

## Registry entry

Registered in `documentations/metrics/emergency.yml` as `ed_medication_dispense`, `kind: metric`,
`unit: count`, `subject_grain: medication_dispense`, with disaggregations `facility_id`, `sex`,
`drug_source_value`, `drug_source_name` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `medication_dispenses` | The population, dispense date, quantity and dispensed medication (BL-001, BL-002, BL-006, BL-009) |
| `pharmacy_order_prescriptions`, `pharmacy_orders` | The drug line's order time, for the segment (BL-003) |
| `reference_data` | The medication's code and name (BL-006) |
| `clinical__visit_detail` | The ordering segment, whose OMOP concept decides inclusion (BL-003, BL-005) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-004) |
| `departments` | Department name resolution (BL-007) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia ED dashboard | The medications dispensed table and the summary table's medications dispensed column (MAUI-6907) |

## Related

| Artefact | Relationship |
|---|---|
| `metric__medication_dispense` | The same dispenses across all settings, resolving the segment the same way and carrying its setting as `encounter_setting` |
| `metric__ed_pharmacy_order` | The same ED-phase drug lines counted on their order date |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-02 | Maui team | Initial draft (MAUI-6907) |

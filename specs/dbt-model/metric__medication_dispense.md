# dbt Model Spec: `metric__medication_dispense` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__medication_dispense` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, set on the shared `metrics:` block |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `medication_dispense`: one row per medication dispense, dated to the day
it was dispensed, in every setting. The dispensing counterpart of `metric__pharmacy_order`, which
counts ordered drug lines on the day they were ordered.

## Purpose

Medication handed over by pharmacy, counted on the day it happened, so a period's figure is what
pharmacy dispensed in that period.

| `metric_id` | Unit | Measures |
|---|---|---|
| `medication_dispense` | count | Medication dispenses (always 1 per row) |

**Who reads it.** The FSM emergency, outpatient, dental, inpatient and summary dashboards'
medications dispensed cards, via data tables in `tupaia-data-product`, each scoping to its setting
by `visit_detail_concept_id` and `department`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of medication dispenses -- no external body registers this indicator |

## Grain

**One row per `(metric_id, subject_id)`,** where `subject_id` is the `medication_dispenses` id. A
drug line dispensed in several partial fills has one row per fill. Asserted by AC-001.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `medication_dispense` |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | The medication dispense id |
| `period_start` | date | The date the medication was dispensed (BL-002) |
| `period_end` | date | NULL -- unused |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (BL-008) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The dispensing segment's location's facility (BL-004) |
| `encounter_type` | varchar(255) | The dispensing segment's encounter type (BL-005) |
| `visit_detail_concept_id` | integer | The dispensing segment's OMOP Visit concept: 9201, 9202, 9203 or 0 (BL-005) |
| `visit_detail_concept_name` | text | Its OMOP concept name, e.g. Emergency Room Visit (BL-005) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `drug_source_value` | text | The dispensed medication's code (BL-006) |
| `drug_source_name` | text | The dispensed medication's name (BL-006) |
| `age_years` | integer | Age in whole years on the day of the dispense, unbanded |
| `department` | text | The dispensing segment's department, resolved to a name (BL-007) |
| `quantity` | numeric | The quantity handed over in the dispense (BL-009) |

## Data tables

The Tupaia data tables over this view belong in `tupaia-data-product`, at `tamanu/data_tables/`,
so this model carries no `data_table_*` meta.

## Business logic

- **BL-001 (population):** every medication dispense against a drug line on a pharmacy order is counted.
- **BL-002 (period):** `period_start` is the date of the dispense's `dispensed_at`.
- **BL-003 (segment):** each dispense resolves to the `clinical__visit_detail` segment active at its `dispensed_at`, clamped to the encounter's first segment where the dispense predates every segment, by `visit_detail__active_segment`.
- **BL-004 (facility):** `facility_id` is the facility of the segment's `care_site_id`, and a dispense whose patient or segment location does not resolve is excluded.
- **BL-005 (setting):** `visit_detail_concept_id` is the segment's OMOP Visit concept, `visit_detail_concept_name` is that concept's name in `map__omop_visit_type`, and `encounter_type` is the segment's own encounter type.
- **BL-006 (medication):** `drug_source_value` and `drug_source_name` are the code and name of the dispense's own medication, `'Not recorded'` where it does not resolve.
- **BL-007 (department):** `department` is the segment's department name, `'Not recorded'` where it does not resolve.
- **BL-008 (registration and count):** `metric_id` is the constant `'medication_dispense'` and `value_numeric` the constant `1`, so a consumer sums it to count dispenses at any grain.
- **BL-009 (quantity):** `quantity` is the dispense's own recorded quantity.
- **BL-010 (indexes):** where the model is materialised as a table, it carries a btree index on `(visit_detail_concept_id, period_start)` and one on `period_start`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-008 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is always `medication_dispense` and registered in `metric_definitions` | BL-008 | `not_null` + `accepted_values` + `relationships` |
| AC-003 | `period_start`, `period_granularity`, `value_numeric`, `facility_id`, `encounter_type`, `visit_detail_concept_id`, `visit_detail_concept_name`, `drug_source_value`, `drug_source_name` and `department` are `not_null` | BL-002, BL-004 -- BL-008 | `not_null` |
| AC-004 | `visit_detail_concept_id` is one of 9201, 9202, 9203, 0 | BL-005 | `accepted_values` |
| AC-005 | A drug line dispensed twice has a row on each dispense's own date, a substituted drug reports the dispensed medication, an unresolved medication falls back to `'Not recorded'`, a dispense takes the concept and name of the segment active when it was dispensed (an ED-ordered line dispensed after admission is 9201), a dispense predating its segments clamps to the first, and a dispense whose encounter has no segment is dropped | BL-001 -- BL-007, BL-009 | unit test `ac_005_metric__medication_dispense_segment` |

## Registry entry

Registered in `documentations/metrics/pharmacy.yml` as `medication_dispense`, `kind: metric`,
`unit: count`, `subject_grain: medication_dispense`, with disaggregations `facility_id`,
`encounter_type`, `visit_detail_concept_id`, `visit_detail_concept_name`, `sex`,
`drug_source_value`, `drug_source_name` and `department`.

## Dependencies

| Model | Why |
|---|---|
| `medication_dispenses` | The population, dispense date, quantity and dispensed medication (BL-001, BL-002, BL-006, BL-009) |
| `pharmacy_order_prescriptions`, `pharmacy_orders` | The dispense's encounter, for the segment (BL-003) |
| `reference_data` | The medication's code and name (BL-006) |
| `clinical__visit_detail` | The dispensing segment and its OMOP Visit concept (BL-003, BL-005) |
| `map__omop_visit_type` | The concept's OMOP name (BL-005) |
| `clinical__person` | Sex and birth date |
| `locations` | Facility resolution (BL-004) |
| `departments` | Department name resolution (BL-007) |
| `metric_definitions` | The canonical registry |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia FSM emergency, outpatient, dental, inpatient and summary dashboards | Medications dispensed tables, the ED daily summary and the monthly summaries' medications dispensed column |

## Related

| Artefact | Relationship |
|---|---|
| `metric__pharmacy_order` | The same drug lines counted on their order date, with whether each has been dispensed. It labels the setting with `encounter_setting`; emergency orders are `metric__ed_pharmacy_order` |
| `clinical__drug_exposure` | Carries the same dispenses as OMOP drug exposures |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-02 | Maui team | Initial draft (MAUI-6907) |

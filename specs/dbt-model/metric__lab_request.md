# dbt Model Spec: `metric__lab_request` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__lab_request` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6909 |

Canonical definition for `lab_request`: one row per completed lab test carrying a reading,
at day resolution. Sourced from `clinical__measurement`'s lab branch, the same clinical-layer
convention `metric__opd_procedure`/`metric__opd_imaging_request` use over
`clinical__procedure_occurrence`.

## Purpose

| `metric_id` | Unit | Measures |
|---|---|---|
| `lab_request` | count | Completed lab tests carrying a reading (always 1 per row) |

**Why per-test, not per-request (BL-001).** A lab request can bundle several tests (e.g. a
panel); the grain that answers "how much lab activity happened" is the individual test, the
same "bundle vs. line" distinction `metric__pharmacy_order` draws against pharmacy orders
(the ordered drug line, not the pharmacy order).

**Why sourced from `clinical__measurement`, not `bases/lab_requests` directly (BL-001).**
`clinical__measurement` is the existing clinical-layer abstraction for lab results (unioned
with vitals and birth anthropometry, discriminated by `measurement_type_source_value`) --
reading from it, filtered to the `'lab'` branch, follows the same convention every other
setting-scoped OPD metric in this repo uses rather than reading `bases/` directly.

**Who reads it.** The Tupaia Dental dashboard for FSM, via a data table over this view in
`tupaia-data-product` (MAUI-6909), and any future consumer wanting lab activity counts.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of completed lab tests -- no external body registers a plain lab-test-count indicator |

No AIHW/WHO/DHIS2 anchor defines this concept; this is a BES composition over Tamanu's own
laboratory workflow, `status: draft`, the same status every other BES-composed `metric__`
model in this project carries.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a test in any consumer that sums `value_numeric`.

`subject_id` is the Tamanu `lab_tests.id` (`clinical__measurement.measurement_id` for the lab
branch), matching the registry's `subject_grain: lab_test`.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `lab_request`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | The Tamanu `lab_tests` id. `not_null` |
| `period_start` | date | Completed date, else published/requested date (BL-002) |
| `period_end` | date | NULL -- a lab test is point-in-time |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The test's encounter's own facility (BL-004). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `lab_test_code` | text | The test type's reference-data code (BL-003). Never NULL |
| `lab_test` | text | The test type as recorded, ungrouped (BL-003). Never NULL |
| `age_years` | integer | Age in whole years at the test, unbanded (BL-006). A measure, not a dimension |
| `department` | text | The test's encounter's own department, resolved to a name (BL-007). Never NULL |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention every other `metric__` model in this project uses
-- filter types, aggregation and any bands are the consumer's vocabulary, not dbt's. This
model therefore carries no `data_table_*` meta. Not yet built as of this spec.

## Business logic

- **BL-001 (a thin wrapper over the clinical layer, per-test grain):** this model filters
  `clinical__measurement` to `measurement_type_source_value = 'lab'` and reshapes it into the
  D5 metric contract. `clinical__measurement`'s own lab branch already restricts to tests
  carrying a reading, under a request that was not withdrawn (its own BL-009/BL-011) -- this
  model does not re-filter that scope, only reshapes the columns it needs.
- **BL-002 (reporting period):** `period_start` is `clinical__measurement.measurement_date`
  for the lab branch (completed date, else published/requested date -- that model's own
  BL-004 fallback order). `period_end` is hardcoded NULL, the same convention
  `metric__opd_procedure`/`metric__pharmacy_order` use: a lab test is point-in-time, so there
  is no closing date to emit.
- **BL-003 (test identity is emitted raw):** `lab_test` and `lab_test_code` are the test
  type's reference-data name and code (`clinical__measurement.measurement_source_name`/
  `measurement_source_value` for the lab branch), coalesced so neither is ever NULL (Tupaia
  exposes these as array filters, which drop a NULL row). Emitted ungrouped -- a
  panel/category grouping is a consumer concern, the same reasoning `procedure`/
  `procedure_code` and `diagnosis`/`diagnosis_code` use.
- **BL-004 (facility attribution):** `facility_id` is resolved through `bases/locations` on
  the test's own encounter's `location_id` (`encounters.location_id`, joined via
  `clinical__measurement.visit_occurrence_id`) -- encounter-level, not segment-level, the same
  attribution `metric__pharmacy_order` uses, since a lab request's facility does not move
  mid-encounter the way a procedure's own location can. The join is **inner**: a test whose
  encounter does not resolve is excluded rather than attributed to a NULL facility.
- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the shared `metrics:` block in `dbt_project.yml`.
- **BL-006 (age is the consumer's to band):** `age_years` is age in whole years at the test
  date, emitted raw and unbanded, the same reasoning every other `metric__` model in this
  project uses. A measure, not a dimension: absent from the registry's disaggregations.
- **BL-007 (department attribution):** `department` is the test's encounter's own
  `department_id` (`encounters.department_id`), the same encounter-level attribution BL-004
  uses for facility, resolved to a name through `departments` so a consumer can scope to one
  department (e.g. Dental) via `metric_filters` on a readable value. Never NULL -- falls back
  to `'Not recorded'`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__lab_request_grain`) |
| AC-002 | `metric_id` is `not_null` | BL-001 | `not_null` (`ac_metric__lab_request_metric_id_not_null`) |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`, `ac_metric__lab_request_metric_id_registered`) |
| AC-004 | `metric_id` is always `lab_request` | BL-001 | `accepted_values` (`ac_metric__lab_request_metric_id_values`) |
| AC-005 | `period_start` is `not_null` | BL-002 | `not_null` (`ac_metric__lab_request_period_start_not_null`) |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` (`ac_metric__lab_request_facility_id_not_null`) |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` (`ac_metric__lab_request_subject_id_not_null`) |
| AC-009 | `period_end` is always NULL | BL-002 | `dbt_expectations.expect_column_values_to_be_null` (`ac_metric__lab_request_period_end_null`) |
| AC-010 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-011 | `lab_test_code` is `not_null` | BL-003 | `not_null` (`ac_metric__lab_request_lab_test_code_not_null`) |
| AC-012 | `lab_test` is `not_null` | BL-003 | `not_null` (`ac_metric__lab_request_lab_test_not_null`) |
| AC-013 | `department` is `not_null` | BL-007 | `not_null` (`ac_metric__lab_request_department_not_null`) |
| AC-014 | Department and facility resolve off the test's encounter, sourced correctly from `clinical__measurement`'s lab branch | BL-001, BL-004, BL-007 | dbt unit test `test_metric__lab_request_attribution` |

Test names are unnumbered (`ac_metric__lab_request_<column>_<check>`), matching
`metric__opd_procedure.yml`'s own convention rather than the `ac_NNN_...` scheme -- this
spec's AC numbering is for cross-reference within this document only.

## Registry entry

One active row -- `lab_request`, `kind: metric`, `subject_grain: lab_test`, `status: draft`,
`spec_path` pointing here, with `disaggregations: facility_id,sex,lab_test_code,lab_test,department`.

`lab_test_code`, `lab_test` and `department` are new to the allowlist in
`assert__metric_definitions__disaggregations`; `facility_id`/`sex` are already admitted by
earlier metrics.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__measurement` | `clinical/` | The test itself, via its lab branch: identity, date, test type, grain anchor (BL-001, BL-002, BL-003) |
| `encounters` | `bases/` | The test's encounter: location and department (BL-004, BL-007) |
| `locations` | `bases/` | Facility id of the encounter's own location (BL-004) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-006) |
| `departments` | `bases/` | Department name of the encounter's own department (BL-007) |
| `metric_definitions` | root | Registry; `metric_id` FK target |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Not yet built as of this spec (MAUI-6909) |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   day-resolution dates, so a monthly card applies its own month bucketing and filters the
   current month itself.
3. **Band `age_years` itself.** No band set is emitted here.
4. **Group `lab_test`/`lab_test_code` itself if a panel/category grouping is wanted.** Neither
   is grouped here.

## Related

| Artefact | Relationship |
|---|---|
| `clinical__measurement` | The clinical-layer source this model filters to its lab branch, the same convention `metric__opd_procedure` uses over `clinical__procedure_occurrence` |
| `metric__pharmacy_order` | Same "bundle vs. line" grain reasoning (drug line, not order); same encounter-level (not segment-level) facility/department attribution |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

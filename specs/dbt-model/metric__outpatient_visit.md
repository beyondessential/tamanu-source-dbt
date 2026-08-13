# dbt Model Spec: `metric__outpatient_visit` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__outpatient_visit` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `opd_visit`: one row per outpatient visit, at day resolution.
Replaces the earlier `ds__outpatient_visit` dataset, converting it onto the same
registry-backed metric pattern as `metric__emergency_visit`.

## Purpose

Outpatient department activity at a Tamanu facility, one row per visit.

| `metric_id` | Unit | Measures |
|---|---|---|
| `opd_visit` | count | Outpatient visits (always 1 per row) |

**Clinical context.** An outpatient visit is a self-contained event -- unlike an ED
attendance, it carries no admission/departure distinction, so there is no equivalent to
`metric__emergency_visit`/`metric__emergency_stay`'s split. One metric covers it.

**Who reads it.** The Tupaia "Hospital Administration" dashboard for Queen of Sheba
Hospital, via a data table over this view.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | AIHW | [400604](https://meteor.aihw.gov.au/content/400604) | Non-admitted patient service event -- concept anchor, not an implemented indicator (BL-001) |

AIHW registers no plain OPD attendance-count indicator: its non-admitted reporting is built
around the Tier 2 Non-Admitted Services Classification and per-clinic activity counts, not a
single cross-clinic count. "Occasion of service" (METeOR 270511) was considered and
rejected as the anchor -- it is scoped to a narrower residual clinic category, not the
general OPD population this metric covers.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a visit in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id, matching the registry's `subject_grain:
visit`, and is unique because only the intake segment is counted (BL-003) -- so
`count(distinct subject_id)` and `sum(value_numeric)` agree.

## Output schema

D5 wide format, plus four disaggregation columns and one measure attribute.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `opd_visit`. FK -> `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Encounter id. `not_null` (AC-008) |
| `period_start` | date | Visit date (BL-002) |
| `period_end` | date | Always NULL -- no departure event is tracked (BL-002) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Intake segment's facility (BL-006) |
| `location_group_id` | varchar(255) | Area. `'locationgroup-unknown'` (not a real FK value) when the area doesn't resolve; otherwise FK -> `bases/location_groups.id` (BL-007) |
| `location_group_name` | varchar(255) | Area name; `'Unknown'` when the area doesn't resolve (BL-007) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at the visit, unbanded (BL-004). A measure, not a dimension |

## Data tables

The Tupaia data tables over this view are configured in `tupaia-data-product`, at
`tamanu/data_tables/`, one file per data table -- the filter types, the aggregation and any
bands are the consumer's vocabulary, not dbt's, so they live with the rest of a data table's
configuration (permission groups included) in that repo. `validate_data_tables.py` there
checks each file against this project's dbt manifest, so a column renamed here fails there
at generate time rather than emptying a dashboard.

This model therefore carries no `data_table_*` meta.

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (reporting period):** `period_start` is the visit date
  (`clinical__visit_detail.visit_detail_start_date` for the intake segment), at `'day'`
  granularity. `period_end` is always NULL -- Tamanu tracks the visit date only for
  outpatient encounters, with no arrival/departure timestamp pair the way ED has, so no
  duration is computable and none is emitted.

  Every visit is emitted as it happens; the model reads no clock, and a consumer needing
  whole periods applies its own date filter. A period with no visit emits no row.
- **BL-003 (inclusion + intake attribution):** a visit is the **first** segment of an
  encounter (`preceding_visit_detail_id is null`) whose `visit_detail_concept_id = 9202`,
  which covers `clinic`, `vaccination` and `imaging` via `map__omop_visit_type`.

  Anchoring on the first segment counts one row per visit and ties inclusion to the
  OMOP-standard mapping rather than the raw `visit_detail_source_value`.
- **BL-004 (age is the consumer's to band):** `age_years` is age in whole years at the visit
  date, emitted raw and unbanded. An age classification -- WHO primary bands, five-year
  bands, a national HMIS grouping -- is a presentation choice a deployment may set
  differently, so banding it here would either freeze one choice or need a column per
  variant. `age_years` is therefore a **measure, not a dimension**: absent from the
  registry's disaggregations, banded (if at all) by the data table declaring it, in
  `tupaia-data-product` (same convention as `metric__emergency_visit` BL-019).

  `sex` is `clinical__person.gender_source_value`. The join to `clinical__person` is
  **inner**, so a visit whose patient `bases/patients` excludes as soft-deleted or merged
  away is excluded rather than counted with blank demographics.
- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml` (shared
  with every model under `models/metrics/`).
- **BL-006 (facility attribution):** `facility_id` is the intake segment's location resolved
  through `bases/locations` on `care_site_id`. The join is **inner**, so an encounter whose
  location does not resolve is excluded rather than attributed to a NULL facility.
- **BL-007 (area attribution):** `location_group_id`/`location_group_name` are the intake
  segment's location's `location_group`, resolved through `bases/location_groups`. The join
  is **left**, not inner: areas are sparse in Tamanu -- most locations have none -- so a
  missing `location_group` is the expected common case, not an anomaly, and the visit still
  counts under the `'locationgroup-unknown'`/`'Unknown'` sentinel pair. Both sentinels are
  driven off the same *joined* `location_groups` row, not the raw `location_group_id` value
  on `locations`, so a missing area (never assigned, or soft-deleted since) always yields
  both sentinels together; a real `location_group_id` never pairs with an `'Unknown'` name,
  or vice versa.

  This is the first `metric__` model to register a disaggregation finer than facility --
  `metric__emergency_visit` has none. Nothing in D5 forbids it; no other metric has needed
  it yet.
- **BL-008 (facility identity stays Tamanu's):** the model emits `facility_id`, the Tamanu
  id, and nothing else. Consumer-specific identifiers -- a Tupaia entity code -- are
  resolved in the consumer layer, not here.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `opd_visit` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-003 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-006 | `not_null` |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | `location_group_id` is `not_null` | BL-007 | `not_null` |
| AC-010 | `location_group_name` is `not_null` | BL-007 | `not_null` |

## Registry entry

One active row -- `opd_visit`, `kind: metric`, `subject_grain: visit`, `status: approved`,
`spec_path` pointing here, with `disaggregations: facility_id,location_group_id,sex`.

Every disaggregation is in the allowlist in `assert__metric_definitions__disaggregations`,
which keeps the registry and the model from drifting.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment: inclusion, visit date, location, encounter id (BL-003, BL-006) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-004) |
| `locations` | `bases/` | Facility and area of the intake segment's location (BL-006, BL-007) |
| `location_groups` | `bases/` | Area (location_group) name, joined via the visit's location (BL-007) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table over this view, backing OPD visuals for Queen of Sheba |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   day-resolution dates, so a monthly card applies its own month bucketing and filters the
   current month itself.
3. **Band `age_years` itself.** No band set is emitted here -- a consumer wanting age groups
   declares its own classification in its data table.
4. **Translate `facility_id`.** This is the Tamanu id, not a consumer-specific one -- for
   Tupaia, the crosswalk to a Tupaia entity code is joined at the data table.

## Related

| Artefact | Relationship |
|---|---|
| `metric__emergency_visit` | Same registry pattern, same conventions (including BL-019's "banding is the consumer's") -- the reference this model was built from |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

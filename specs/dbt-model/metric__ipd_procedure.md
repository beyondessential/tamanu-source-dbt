# dbt Model Spec: `metric__ipd_procedure` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ipd_procedure` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `ipd_procedure`: one row per procedure recorded during an
inpatient admission, at day resolution. Modelled directly on the general `metric__procedure`,
and the IPD-scoped counterpart to `metric__opd_procedure`.

## Purpose

Procedure activity performed in the inpatient setting, one row per procedure.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ipd_procedure` | count | Procedures during an inpatient admission (always 1 per row) |

**Why a separate metric, not a filter (BL-001).** `metric__procedure` already emits
`encounter_type` precisely so a consumer scopes to one setting via a filter on that one
metric (its own header comment). `metric__ipd_procedure` was built as a dedicated metric
instead, mirroring the decision (MAUI-6862) already made for `metric__opd_procedure` -- kept
apart from every other setting rather than mixed with it, matching how `opd_visit` and
`ed_visit` are separate metrics rather than one metric filtered by setting.

**Clinical context.** A procedure is point-in-time, unlike a visit or a stay -- there is no
admission/departure pair to split, so one metric covers it, the same shape `metric__procedure`
and `metric__opd_procedure` already use.

**Who reads it.** The Tupaia inpatient department dashboards, via a data table over this
view in `tupaia-data-product`, once built.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of recorded procedures scoped to the inpatient setting -- no external body registers a procedure-count indicator (BL-001 of `metric__procedure`'s own registry entry applies here too) |

No external indicator is implemented; this is a BES composition, the same status
`metric__procedure` and `metric__opd_procedure` carry (`status: draft`). This metric differs
only in scoping to the inpatient admission setting instead of the general or outpatient one.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a procedure in any consumer that sums `value_numeric`.

`subject_id` is the Tamanu procedure id (`clinical__procedure_occurrence.procedure_occurrence_id`),
matching the registry's `subject_grain: procedure`.

## Output schema

D5 wide format, plus five disaggregation columns and one measure attribute.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ipd_procedure`. FK -> `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | The Tamanu procedure id. `not_null` (AC-008) |
| `period_start` | date | The date the procedure was performed (BL-002) |
| `period_end` | date | NULL -- a procedure is point-in-time (BL-002) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The procedure's own location's facility (BL-004). `not_null` (AC-007) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `procedure` | text | The procedure as recorded, ungrouped (BL-006). Never NULL |
| `procedure_code` | text | The procedure type's reference-data code (BL-006). Never NULL |
| `is_completed` | boolean | Whether the procedure was marked completed. Never NULL |
| `age_years` | integer | Age in whole years at the procedure, unbanded (BL-007). A measure, not a dimension |

## Data tables

The Tupaia data table(s) over this view belong in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention `metric__opd_procedure` and `metric__procedure`
use -- filter types, aggregation and any bands are the consumer's vocabulary, not dbt's.
This model therefore carries no `data_table_*` meta. Not yet built as of this spec.

## Business logic

- **BL-001 (a dedicated metric, not a filter):** `metric__procedure` already carries
  `encounter_type` so a consumer scopes to one setting via a filter on that single metric.
  `metric__ipd_procedure` duplicates that filter's effect as its own metric instead, mirroring
  the decision (MAUI-6862) already applied to `metric__opd_procedure` -- inpatient procedures
  are kept apart from every other setting rather than mixed with it in the general metric.
  Both metrics read the same underlying `clinical__procedure_occurrence` rows; a procedure
  recorded during an inpatient admission appears in both.
- **BL-002 (registration + reporting period):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity. `period_start` is
  the procedure date (`clinical__procedure_occurrence.procedure_date`); `period_end` is
  hardcoded NULL, asserted by AC-009 as the null invariant itself (a procedure is
  point-in-time, so there is no closing date to emit, the same reasoning `metric__procedure`
  and `metric__opd_procedure` use).
- **BL-003 (inpatient scope: the segment active when the procedure happened):** a
  procedure is included when the `clinical__visit_detail` segment active at its own
  `procedure_datetime` has `visit_detail_concept_id = 9201` (OMOP "Inpatient Visit") --
  the concept that maps only from Tamanu encounter_type `admission`
  (`models/maps/map__omop_visit_type.sql`), unlike 9202's three encounter types.

  The active segment is found with an as-of join -- the latest `clinical__visit_detail` row
  for the encounter whose `visit_detail_start_datetime` is at or before the procedure's
  timestamp -- rather than the encounter's first segment or its current/final segment. This
  is also the standard OMOP answer: the CDM spec's own `PROCEDURE_OCCURRENCE.visit_detail_id`
  field description gives the identical case ("if the Person was in the ICU at the time of
  the Procedure ... the VISIT_DETAIL record would reflect the ICU stay during the hospital
  visit") as the reason `PROCEDURE_OCCURRENCE` carries a `visit_detail_id` distinct from
  `visit_occurrence_id` at all -- the same reasoning `metric__opd_procedure` BL-003 documents.

  A procedure performed during an admission's earlier ER/triage phase (segment type
  emergency/triage/observation, concept 9203) correctly does **not** count as IPD -- it
  belongs to that earlier segment, not the later admission one, regardless of what the
  encounter as a whole became. Concept 262 (`admission_from_emergency`) is not a
  consideration here: `map__omop_visit_type.sql` never emits 262 from a segment's own
  `encounter_type` -- it is applied only at the whole-encounter level in
  `clinical__visit_occurrence`, for an admission whose `encounter_history` shows a prior
  emergency/triage/observation phase -- so segment-level filtering on 9201 alone is already
  correct and complete; no special-casing of 262 is needed or applied.

  **Clamped to the first segment when the procedure predates every segment (decision,
  Juliana -- mirrors `metric__opd_procedure` BL-003).** A procedure can be timestamped before
  its own encounter's earliest recorded segment even starts -- a data-timing artifact (the
  segment's own start time recorded late), not a real ordering issue; the procedure still
  genuinely belongs to that encounter. Every encounter has at least one
  `clinical__visit_detail` segment (its own BL-005), so the join to `visit_detail` carries no
  timestamp condition -- the `order by` picks the latest segment that had already started
  where one qualifies, and falls back to the earliest segment otherwise, so a procedure is
  never dropped purely because a segment's own recorded start time is unreliable. The clamp
  resolves *which* segment a procedure is compared against; it does not change the 9201 scope
  check itself -- a procedure clamped onto a non-9201 segment (e.g. the only segment is
  `clinic`) is still excluded.
- **BL-004 (facility attribution):** `facility_id` is resolved through `bases/locations` on
  the procedure's own `location_id` -- not the encounter's `care_site_id` -- the same
  convention `metric__procedure` and `metric__opd_procedure` use, since a procedure can be
  performed somewhere other than where the patient's encounter is otherwise located (e.g. a
  theatre). The join is **inner**, so a procedure whose location does not resolve is
  excluded rather than attributed to a NULL facility.
- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml` (shared
  with every model under `models/metrics/`).
- **BL-006 (procedure identity is emitted raw):** `procedure` and `procedure_code` are the
  procedure type's reference-data name and code, coalesced so neither is ever NULL (Tupaia
  exposes these as array filters, which drop a NULL row). Emitted ungrouped -- deployments
  differ in what they code procedures with, so any classification grouping is a consumer
  concern, the same approach `metric__procedure` and `metric__opd_procedure` take.
- **BL-007 (age is the consumer's to band):** `age_years` is age in whole years at the
  procedure date, emitted raw and unbanded, the same reasoning `metric__procedure` and
  `metric__opd_procedure` use. A measure, not a dimension: absent from the registry's
  disaggregations.
- **BL-008 (procedure branch only):** `clinical__procedure_occurrence` also carries an
  imaging branch, distinguished by `procedure_type_source_value` (its own spec, BL-001,
  which requires every consumer to filter explicitly). This model filters to
  `procedure_type_source_value = 'procedure'` before any other join, the same filter
  `metric__procedure` and `metric__opd_procedure` apply -- imaging is
  `metric__opd_imaging_request`'s population, not this one's.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__ipd_procedure_grain`) |
| AC-002 | `metric_id` is `not_null` | BL-002 | `not_null` (`ac_metric__ipd_procedure_metric_id_not_null`) |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-002 | `relationships` (`error`, `ac_metric__ipd_procedure_metric_id_registered`) |
| AC-004 | `metric_id` is always `ipd_procedure` | BL-002 | `accepted_values` (`ac_metric__ipd_procedure_metric_id_values`) |
| AC-005 | `period_start` is `not_null` | BL-002 | `not_null` (`ac_metric__ipd_procedure_period_start_not_null`) |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` (`ac_metric__ipd_procedure_value_numeric_not_null` / `_is_one`) |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` (`ac_metric__ipd_procedure_facility_id_not_null`) |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` (`ac_metric__ipd_procedure_subject_id_not_null`) |
| AC-009 | `period_end` is always NULL | BL-002 | `dbt_expectations.expect_column_values_to_be_null` (`ac_metric__ipd_procedure_period_end_null`) |
| AC-010 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` (`ac_metric__ipd_procedure_period_granularity_not_null` / `_is_day`) |
| AC-011 | `procedure` is `not_null` | BL-006 | `not_null` (`ac_metric__ipd_procedure_procedure_not_null`) |
| AC-012 | `procedure_code` is `not_null` | BL-006 | `not_null` (`ac_metric__ipd_procedure_procedure_code_not_null`) |
| AC-013 | `is_completed` is `not_null` | BL-006 | `not_null` (`ac_metric__ipd_procedure_is_completed_not_null`) |
| AC-014 | A procedure predating every segment of its encounter clamps to the first segment, rather than being dropped | BL-003 | dbt unit test `test_metric__ipd_procedure_segment_clamp` |

Test names are unnumbered (`ac_metric__ipd_procedure_<column>_<check>`), matching
`metric__procedure.yml`'s and `metric__opd_procedure.yml`'s own convention rather than the
newer `ac_NNN_...` scheme -- this spec's AC numbering is for cross-reference within this
document only.

## Registry entry

One active row -- `ipd_procedure`, `kind: metric`, `subject_grain: procedure`,
`status: draft`, `spec_path` pointing here, with `disaggregations:
facility_id,sex,procedure,procedure_code,is_completed`.

Every disaggregation is already in the allowlist in
`assert__metric_definitions__disaggregations`, admitted by `metric__procedure`'s own
registration -- no vocabulary change was needed for this metric.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical/` | Procedure date, type, completion, location, person and visit FKs (BL-002, BL-004, BL-006). Filtered to the procedure branch (BL-008) |
| `clinical__visit_detail` | `clinical/` | Inpatient scope: the segment active at the procedure's own timestamp (BL-003) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-007) |
| `locations` | `bases/` | Facility id of the procedure's own location (BL-004) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Not yet built as of this spec |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   day-resolution dates, so a monthly card applies its own month bucketing and filters the
   current month itself.
3. **Band `age_years` itself.** No band set is emitted here.
4. **Do not expect this to reconcile with `metric__opd_procedure`'s complement.** Both
   metrics are segment-grain decisions evaluated at the procedure's own time, but against
   disjoint concepts (9201 here, 9202 there); a procedure whose active segment is 9203
   (emergency/triage/observation) counts in neither -- see BL-003 before treating that as a
   gap.

## Related

| Artefact | Relationship |
|---|---|
| `metric__procedure` | Same clinical source and structure -- the reference this model was built from. Unaffected by this change: still general, still carries `encounter_type` |
| `metric__opd_procedure` | Sibling metric, same segment-as-of pattern (BL-003) against the complementary OMOP concept (9202 there, 9201 here) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

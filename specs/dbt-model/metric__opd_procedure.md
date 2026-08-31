# dbt Model Spec: `metric__opd_procedure` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__opd_procedure` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `opd_procedure`: one row per procedure recorded during an
outpatient encounter, at day resolution. Sits beside `metric__outpatient_visit` (`opd_visit`)
in the outpatient product, and is modelled directly on the general `metric__procedure`.

## Purpose

Procedure activity performed in the outpatient setting, one row per procedure.

| `metric_id` | Unit | Measures |
|---|---|---|
| `opd_procedure` | count | Procedures during an outpatient encounter (always 1 per row) |

**Why a separate metric, not a filter (BL-001).** `metric__procedure` already emits
`encounter_type` precisely so a consumer scopes to one setting via a filter on that one
metric (its own header comment). `metric__opd_procedure` was built as a dedicated metric
instead, by decision (MAUI-6862) -- kept apart from every other setting rather than mixed
with it, matching how `opd_visit` and `ed_visit` are separate metrics rather than one
metric filtered by setting.

**Clinical context.** A procedure is point-in-time, unlike a visit or a stay -- there is no
admission/departure pair to split, so one metric covers it, the same shape `metric__procedure`
already uses.

**Who reads it.** The Tupaia outpatient department dashboards, via a data table over this
view in `tupaia-data-product`, once built.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of recorded procedures scoped to the outpatient setting -- no external body registers a procedure-count indicator (BL-001 of `metric__procedure`'s own registry entry applies here too) |

No external indicator is implemented; this is a BES composition, the same status
`metric__procedure` carries (`status: draft`, `spec_path: null` there). This metric differs
only in adding the outpatient scope.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a procedure in any consumer that sums `value_numeric`.

`subject_id` is the Tamanu procedure id (`clinical__procedure_occurrence.procedure_occurrence_id`),
matching the registry's `subject_grain: procedure`.

## Output schema

D5 wide format, plus five disaggregation columns and one measure attribute.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `opd_procedure`. FK -> `metric_definitions.metric_id` (AC-003) |
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
`tamanu/data_tables/`, the same convention `metric__outpatient_visit` and `metric__procedure`
use -- filter types, aggregation and any bands are the consumer's vocabulary, not dbt's.
This model therefore carries no `data_table_*` meta. Not yet built as of this spec.

## Business logic

- **BL-001 (a dedicated metric, not a filter):** `metric__procedure` already carries
  `encounter_type` so a consumer scopes to one setting via a filter on that single metric.
  `metric__opd_procedure` duplicates that filter's effect as its own metric instead, by
  decision (MAUI-6862) -- outpatient procedures are kept apart from every other setting
  rather than mixed with it in the general metric. Both metrics read the same underlying
  `clinical__procedure_occurrence` rows; a procedure recorded during an outpatient encounter
  appears in both.
- **BL-002 (registration + reporting period):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity. `period_start` is
  the procedure date (`clinical__procedure_occurrence.procedure_date`); `period_end` is
  hardcoded NULL, asserted by AC-009 as the null invariant itself (a procedure is
  point-in-time, so there is no closing date to emit, the same reasoning `metric__procedure`
  uses).
- **BL-003 (outpatient scope, and its grain caveat):** a procedure is included when its
  encounter's `clinical__visit_occurrence.visit_concept_id = 9202` (OMOP "Outpatient
  Visit"), which covers `clinic`, `imaging` and `vaccination` via
  `models/maps/map__omop_visit_type.sql` -- the same three encounter types, and the same
  OMOP concept, `metric__outpatient_visit` uses for `opd_visit`.

  **This is filtered at the whole-encounter grain** (`clinical__visit_occurrence`), the
  same relation `metric__procedure` already joins to for `encounter_type`. It is **not**
  filtered at `clinical__visit_detail`'s first-segment grain
  (`visit_detail_concept_id = 9202`, `preceding_visit_detail_id is null`), which is what
  `metric__outpatient_visit` itself uses for `opd_visit`. For the ordinary case -- an
  encounter that is outpatient from start to finish -- the two grains agree. They can
  disagree for a multi-segment encounter whose first recorded phase was **not** outpatient
  (e.g. triage before being seen in clinic): `metric__outpatient_visit` would exclude it (its
  first segment is not 9202), while `metric__opd_procedure` would still include a procedure
  recorded against it (the encounter's overall type is 9202 once redirected to clinic). This
  is expected to be rare, and is a genuine, open definitional gap rather than an
  implementation bug -- a consumer cross-referencing `opd_visit` counts against
  `opd_procedure` counts should read this note first if the two do not reconcile exactly.
  Tightening this to the first-segment grain, matching `opd_visit` exactly, is a candidate
  follow-up once real deployment data shows whether the disagreement is actually rare or
  not.
- **BL-004 (facility attribution):** `facility_id` is resolved through `bases/locations` on
  the procedure's own `location_id` -- not the encounter's `care_site_id` -- the same
  convention `metric__procedure` and `clinical__procedure_occurrence` use, since a procedure
  can be performed somewhere other than where the patient's encounter is otherwise located
  (e.g. a theatre). The join is **inner**, so a procedure whose location does not resolve is
  excluded rather than attributed to a NULL facility.
- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml` (shared
  with every model under `models/metrics/`).
- **BL-006 (procedure identity is emitted raw):** `procedure` and `procedure_code` are the
  procedure type's reference-data name and code, coalesced so neither is ever NULL (Tupaia
  exposes these as array filters, which drop a NULL row). Emitted ungrouped -- deployments
  differ in what they code procedures with, so any classification grouping is a consumer
  concern, the same approach `metric__procedure` and `diagnosis`/`diagnosis_code` take.
- **BL-007 (age is the consumer's to band):** `age_years` is age in whole years at the
  procedure date, emitted raw and unbanded, the same reasoning `metric__outpatient_visit`
  BL-004 and `metric__procedure` use. A measure, not a dimension: absent from the registry's
  disaggregations.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__opd_procedure_grain`) |
| AC-002 | `metric_id` is `not_null` | BL-002 | `not_null` (`ac_metric__opd_procedure_metric_id_not_null`) |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-002 | `relationships` (`error`, `ac_metric__opd_procedure_metric_id_registered`) |
| AC-004 | `metric_id` is always `opd_procedure` | BL-002 | `accepted_values` (`ac_metric__opd_procedure_metric_id_values`) |
| AC-005 | `period_start` is `not_null` | BL-002 | `not_null` (`ac_metric__opd_procedure_period_start_not_null`) |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` (`ac_metric__opd_procedure_value_numeric_not_null` / `_is_one`) |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` (`ac_metric__opd_procedure_facility_id_not_null`) |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` (`ac_metric__opd_procedure_subject_id_not_null`) |
| AC-009 | `period_end` is always NULL | BL-002 | `dbt_expectations.expect_column_values_to_be_null` (`ac_metric__opd_procedure_period_end_null`) |
| AC-010 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` (`ac_metric__opd_procedure_period_granularity_not_null` / `_is_day`) |
| AC-011 | `procedure` is `not_null` | BL-006 | `not_null` (`ac_metric__opd_procedure_procedure_not_null`) |
| AC-012 | `procedure_code` is `not_null` | BL-006 | `not_null` (`ac_metric__opd_procedure_procedure_code_not_null`) |
| AC-013 | `is_completed` is `not_null` | BL-006 | `not_null` (`ac_metric__opd_procedure_is_completed_not_null`) |

Test names are unnumbered (`ac_metric__opd_procedure_<column>_<check>`), matching
`metric__procedure.yml`'s own convention rather than the newer `ac_NNN_...` scheme -- this
spec's AC numbering is for cross-reference within this document only.

## Registry entry

One active row -- `opd_procedure`, `kind: metric`, `subject_grain: procedure`,
`status: draft`, `spec_path` pointing here, with `disaggregations:
facility_id,sex,procedure,procedure_code,is_completed`.

Every disaggregation is already in the allowlist in
`assert__metric_definitions__disaggregations`, admitted by `metric__procedure`'s own
registration -- no vocabulary change was needed for this metric.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical/` | Procedure date, type, completion, location, person and visit FKs (BL-002, BL-004, BL-006) |
| `clinical__visit_occurrence` | `clinical/` | Outpatient scope via `visit_concept_id` (BL-003) |
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
4. **Read BL-003 before reconciling against `opd_visit`.** The two metrics scope
   "outpatient" at different grains (whole-encounter here, first-segment there) and can
   disagree for a multi-segment encounter -- see BL-003 before treating a mismatch as a bug.

## Related

| Artefact | Relationship |
|---|---|
| `metric__procedure` | Same clinical source and structure -- the reference this model was built from. Unaffected by this change: still general, still carries `encounter_type` |
| `metric__outpatient_visit` | Sibling metric in the outpatient product; same OMOP 9202 definition, different grain (BL-003) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

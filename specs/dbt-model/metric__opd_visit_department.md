# dbt Model Spec: `metric__opd_visit_department` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__opd_visit_department` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, segment grain -- see § Grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else, same block as every model under `models/metrics/` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Companion definition to `opd_visit` (`metric__outpatient_visit`), not a replacement: built to
answer a question that metric cannot -- "did this outpatient visit ever touch department X, and
how long did it spend there" -- without changing that model's own shipped, already-consumed
grain (MAUI-6909 follow-up).

## Purpose

Outpatient visit activity broken out by every department segment a visit's history recorded,
one row per segment.

| `metric_id` | Unit | Measures |
|---|---|---|
| `opd_visit_department` | count | Outpatient visit segments (always 1 per row) |

**Why this exists alongside `opd_visit`.** `metric__outpatient_visit.department` (its own
BL-013) resolves off the visit's **first (intake) segment only**. Reconciling a Dental-scoped
Tupaia dashboard against Tamanu's own in-product Encounter Summary report surfaced a real gap:
that report counts a visit against a department wherever it appears in the visit's full
`encounter_history`, not only its first segment -- so a visit that transferred into or out of
Dental partway through, with no `encounter_type` change (which `clinical__visit_detail` still
opens as a new segment on any field change, department included), is invisible to
`opd_visit`'s intake-only column but visible to the report. Confirmed with real numbers before
this model was built (708 report vs 705 `opd_visit`-backed data table for one FSM period).

`metric__outpatient_visit` is left unchanged: it already ships and is already consumed by the
unrelated `outpatient` Tupaia product, so multiplying its rows per department touched would
silently over-count every existing consumer that isn't Dental. This is an additive new metric.

**Who reads it.** The FSM `dental` Tupaia product (`tupaia-data-product`
`tamanu/bes/dental/`), replacing that product's visit-based cards' previous dependency on
`metric__outpatient_visit`.

## Definition sources

Same anchor as `metric__outpatient_visit` -- see that spec's own § Definition sources. This
metric is a different grain over the same underlying population, not a separate indicator with
its own AIHW/METeOR anchor.

## Grain

**One row per segment, not one row per visit.** Deliberately different from every other
registered metric in this repo, each of which asserts `(metric_id, subject_id)` unique via its
own AC-001 -- here `subject_id` legitimately repeats once per `clinical__visit_detail` segment
the visit's history recorded. Asserted instead as `(metric_id, segment_id)` unique at `error`
severity (AC-001), where `segment_id` is the segment's own `clinical__visit_detail` id.
`period_start` is a date, so segments of one visit that start on the same day share it, and
`department` repeats when a visit re-enters a department -- neither distinguishes segments.

`subject_id` is the same OMOP visit occurrence id `metric__outpatient_visit` emits for the same
visit -- the two metrics correlate on it. **`count(distinct subject_id)` and `sum(value_numeric)`
do not agree here**, unlike that metric: an unscoped sum counts every segment, and a visit
touching three departments contributes three. Both are valid only once a consumer scopes to
exactly one `department` (Tupaia's `scope` mechanism -- a fixed WHERE condition baked into the
generated SQL -- is the intended way, since Tupaia's data-table generator has no
`DISTINCT`/dedup capability of its own; see § Consumers).

## Output schema

D5 wide format. Every column not called out below is copied unchanged, per visit, from the same
source `metric__outpatient_visit` reads -- see that spec for their own BL clauses.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `opd_visit_department`. FK -> `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Encounter id. Repeats once per segment (BL-001). `not_null` (AC-005) |
| `segment_id` | varchar(255) | The segment's own `clinical__visit_detail` id -- the grain key (BL-001). `not_null` (AC-018) |
| `period_start` | date | **This segment's own start date**, not the visit's intake date (BL-002) |
| `period_end` | date | This segment's own end date. NULL while the segment is open (BL-002) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (AC-008). Additive per segment -- see § Grain for why an unscoped sum is not a visit count |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | Intake segment's facility -- same value on every row of a visit (unchanged from `metric__outpatient_visit`) |
| `location_id` | varchar(255) | Intake segment's location -- same value on every row of a visit (unchanged) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` -- same value on every row of a visit (unchanged) |
| `age_years` | integer | Age at the visit, unbanded -- same value on every row of a visit (unchanged) |
| `clinician_id` | varchar(255) | **This segment's own clinician** (BL-003), not the visit's intake clinician. Nullable |
| `clinician_name` | varchar(255) | That clinician's display name, from `ref__provider` (BL-003). `not_null` (AC-011), `'Not recorded'` fallback |
| `is_admitted` | boolean | Whether the visit went on to an inpatient admission -- same value on every row of a visit (unchanged). `not_null` (AC-012) |
| `admission_clinician_id` | varchar(255) | Admission segment's clinician -- same value on every row of a visit (unchanged) |
| `admission_clinician_name` | varchar(255) | That clinician's display name -- same value on every row of a visit (unchanged). `not_null` (AC-013), `'Not recorded'` fallback |
| `is_auto_discharge` | boolean | Discharge was system-generated -- same value on every row of a visit (unchanged). `not_null` (AC-014) |
| `segment_time__minutes` | numeric | **This segment's own duration**, minutes to 2 dp (BL-004). NULL while open |
| `department` | text | **This segment's own department**, resolved to a name (BL-005). Never NULL, `'Not recorded'` fallback |

## Data tables

Same convention as `metric__outpatient_visit` -- configured in `tupaia-data-product`, at
`tamanu/data_tables/`, validated against this project's manifest by `validate_data_tables.py`.
This model therefore carries no `data_table_*` meta.

Unlike that model, a data table over this one is expected to declare a `count_distinct`
aggregation (a Tupaia-side capability added alongside this metric, see § Consumers) rather than
`sum`, and to rely on the dataset's own `scope` mechanism to fix `department` to exactly one
value -- an unscoped data table over this metric is not a meaningful "total" of anything.

## Business logic

- **BL-001 (segment grain, not visit grain):** every row is one `clinical__visit_detail`
  segment belonging to an outpatient visit (same population as `metric__outpatient_visit`'s
  own BL-003 -- first segment at OMOP concept 9202), not a collapsed or deduplicated view of
  it. A visit that leaves and re-enters the same department emits one row per segment, not one
  row per distinct department -- `clinical__visit_detail` bounds each segment at the next
  segment's start (its own BL-002), so segments are contiguous with no gaps, and summing
  `segment_time__minutes` for one department after scoping to it therefore gives the correct
  total time in that department, however finely an unrelated field change (an examiner
  handover, say) sliced the segments.

  Restricted to `visit_detail_concept_id = 9202` -- the same boundary
  `metric__outpatient_visit`'s own `opd_time__minutes` uses (its BL-011): a segment after the
  visit transitions to a different concept (an inpatient admission, most commonly) belongs to
  that different episode, not to this outpatient visit's own department history. Without this,
  an admitted visit would pull its entire subsequent inpatient stay's department transfers into
  what is supposed to be an outpatient metric. `clinical__visit_detail`'s own lead()-based
  end-dating already closes the last included 9202 segment at that transition segment's start
  (or the encounter end, for a visit that never leaves 9202), so no separate exit-finding CTE
  (`metric__outpatient_visit`'s own `opd_exits`) is needed here.

  This is a deliberate departure from every sibling metric's "grain is `(metric_id,
  subject_id)`, and `count(distinct subject_id)` agrees with `sum(value_numeric)`" contract --
  collapsing to one row per `(visit, department)` in dbt was considered and rejected: it would
  discard the per-segment start/end that `segment_time__minutes` depends on, which the
  mean-time card needs. Deduplicating down to "did this visit ever touch department X" is
  therefore a **consumer-layer** concern (Tupaia's `count_distinct` aggregation), not this
  model's.
- **BL-002 (reporting period is the segment's, not the visit's):** `period_start`/`period_end`
  are this segment's own `visit_detail_start_date`/`visit_detail_end_date` --
  `clinical__visit_detail`'s own bounding (its BL-002: next segment's start, or the encounter
  end for a closed visit's final segment). Deliberately the opposite anchoring choice from an
  earlier draft of this design, which anchored to the visit's overall dates instead: Tamanu's
  Encounter Summary report filters a visit by the **visit's own** start/end date and only then
  checks its full department history, with no per-segment date filter, so anchoring this
  metric's period to the segment's own date is what lets a data table reproduce that same
  encounter-level date semantics itself (by fetching unfiltered-by-segment-date and filtering
  on the visit's own dates elsewhere) -- anchoring here to the segment's own date does not
  block that; anchoring to the visit's overall date instead would have made the per-segment
  duration meaningless. NULL `period_end` means the segment (and therefore the visit) is still
  open, not a duration of zero.
- **BL-003 (segment's own clinician):** `clinician_id` is this segment's own `provider_id`, not
  the visit's intake clinician `metric__outpatient_visit.clinician_id` carries. More accurate
  for a segment the visit was transferred into: the clinician who saw the patient specifically
  during (for example) its Dental segment, rather than whoever admitted them into outpatient
  care generally. Nullable, no `not_null` test -- a segment recorded with no clinician keeps
  the row. `clinician_name` resolves to `'Not recorded'`, never NULL, the same array-filter
  safety reasoning `metric__outpatient_visit.clinician_name` uses.
- **BL-004 (segment duration):** `segment_time__minutes` is this segment's own
  `visit_detail_end_datetime - visit_detail_start_datetime`, in minutes to two decimal places
  -- not the same quantity as `metric__outpatient_visit.opd_time__minutes`, which spans the
  whole outpatient episode from intake to departure. Summing this column across every segment
  of a visit reproduces that same total; summing it after scoping to one department gives time
  spent in that department specifically, including a visit that left and came back. NULL while
  the segment is open, not zero -- excluded from a mean's denominator the same way
  `opd_time__minutes` is (AC-015 covers `>= 0` where present).
- **BL-005 (segment's own department):** `department` is this segment's own `department_id`,
  resolved to a name through `departments` -- the same resolution
  `metric__outpatient_visit.department` (its BL-013) uses, applied per segment instead of only
  to the intake segment. Never NULL, `'Not recorded'` fallback, same array-filter-safety
  reasoning.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, segment_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `opd_visit_department` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-005 | `subject_id` is `not_null` | grain | `not_null` |
| AC-006 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-007 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-008 | `value_numeric` is `not_null` and always `1` | BL-001 | `not_null` + `accepted_values` |
| AC-009 | `facility_id` is `not_null` | -- | `not_null` |
| AC-010 | `location_id` is `not_null` | -- | `not_null` |
| AC-011 | `clinician_name` is `not_null` | BL-003 | `not_null` |
| AC-012 | `is_admitted` is `not_null` | -- | `not_null` |
| AC-013 | `admission_clinician_name` is `not_null` | -- | `not_null` |
| AC-014 | `is_auto_discharge` is `not_null` | -- | `not_null` |
| AC-015 | `segment_time__minutes`, where present, is `>= 0` | BL-004 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-016 | `department` is `not_null` | BL-005 | `not_null` |
| AC-017 | Segment fan-out behaves as specified: multiple departments across a visit's history, a revisited department producing multiple rows (not collapsed), the synthesized-single-segment case, a NULL segment department, population parity with `opd_visit`, and an open final segment | BL-001..BL-005 | `unit_test` (`data_tests/unit_tests/metric__opd_visit_department.yml`) |
| AC-018 | `segment_id` is `not_null` | grain | `not_null` |

## Registry entry

One active row -- `opd_visit_department`, `kind: metric`, `subject_grain: visit`,
`status: draft` pending a first real-data spot-check against FSM, `variant_of: null`
(deliberately not a variant of `opd_visit` -- grain and sum semantics differ), `spec_path`
pointing here, with `disaggregations:
facility_id,location_id,sex,clinician_id,is_admitted,admission_clinician_id,is_auto_discharge,department`.

`age_years` and `segment_time__minutes` are absent: measures, not dimensions, same convention
`opd_visit` follows for `age_years`/`opd_time__minutes`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Every segment of the visit: department, clinician, start/end (BL-001..BL-005) |
| `clinical__visit_occurrence` | `clinical/` | Population parity with `opd_visit` (its own encounter_type mapping guard) |
| `clinical__person` | `clinical/` | Sex and birth date, copied unchanged from the visit's intake |
| `locations` | `bases/` | Facility and location id of the intake segment's location, copied unchanged |
| `ref__provider` | `ref/` | This segment's own clinician display name (BL-003) |
| `discharges` | `bases/` | Discharge note, copied unchanged from the visit |
| `departments` | `bases/` | This segment's own department name (BL-005) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source, `dental` product | Replaces that product's visit-based cards' previous read of `metric__outpatient_visit`, once a `count_distinct` aggregation mode lands in `_classes/dataset.py` |

**What a consumer must do (this metric, specifically -- contrast `metric__outpatient_visit`'s
own § Consumers):**

1. **Scope to exactly one `department` before aggregating anything.** An unscoped
   `sum(value_numeric)` or `sum(segment_time__minutes)` mixes every department a visit ever
   touched into one number.
2. **Count visits with `count(distinct subject_id)`, not `sum(value_numeric)`**, even after
   scoping to one department -- a visit that left and re-entered that department still
   contributes multiple rows.
3. **Sum `segment_time__minutes`, not `opd_time__minutes`, for time in a specific
   department.** The two are different quantities (§ BL-004) and are not interchangeable.
4. **Everything else** -- age banding, facility translation, NULL clinician labelling, rate/mean
   formation -- follows `metric__outpatient_visit`'s own § Consumers guidance unchanged, since
   those columns carry the same values and the same caveats here.

## Related

| Artefact | Relationship |
|---|---|
| `metric__outpatient_visit` | Companion metric this one exists alongside, not in place of -- same population, visit grain instead of segment grain, intake-only department instead of per-segment |
| `clinical__visit_detail` | Segment source this model reads directly, at the same grain it already produces -- see its own BL-002 for the union/synthesized-segment logic this model relies on |
| `int__admission_history_department` | Existing department-only-change collapsing precedent in this repo, scoped to admission encounters and a different (occupancy-log) purpose -- considered and not reused here, since this model deliberately does not collapse |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

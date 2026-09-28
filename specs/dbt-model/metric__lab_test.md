# dbt Model Spec: `metric__lab_test` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__lab_test` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6837 (renamed from `metric__lab_request`, MAUI-6909) |
| **Created** | 2026-09-23 |

Canonical definition for `lab_test`: one row per laboratory test ordered, whether or not it
ever produced a result. The generic (all-settings) metric of the laboratory family, carrying
`encounter_setting` so a consumer scopes to outpatient or inpatient activity by filtering a
column, the same shape `metric__procedure` took when its own OPD/IPD variants were folded in.
**No outpatient or inpatient sibling metrics** -- see BL-001.

## Purpose

Laboratory testing activity, one row per test ordered.

| `metric_id` | Unit | Measures |
|---|---|---|
| `lab_test` | count | Laboratory tests ordered (always 1 per row) |

**Answers the four standing questions** raised by Queen of Sheba (MAUI-6694) and Tokelau
(MAUI-6688):

1. **Tests requested versus completed** -- every ordered test is a row; `is_completed`
   splits them on the test's own completion timestamp (BL-006).
2. **Turnaround time** -- request placed to test completed, as `turnaround__minutes`, averaged
   by the consumer over `is_completed` rows (BL-007). Not pre-aggregated.
3. **Results and categories** -- `result` and `lab_test_category` as recorded, ungrouped
   (BL-008).
4. **Positivity rate** -- **not materialised and not classified.** The result is emitted raw;
   both deciding which values mean "positive" and forming the ratio are the consumer's
   (BL-009).

**Why the order side does not come from `clinical__`.** Decision (Juliana, 2026-09-23): the
OMOP clinical models record what has *clinically happened*; an order is an intent, not an
occurrence, so a test requested and never resulted has no place in the clinical layer. Order
facts therefore source from `bases/` directly, results from `clinical__measurement`. See
BL-004 -- this is a general rule the team expects to recur (referrals, appointments, tasks),
not a laboratory-specific carve-out.

**Supersedes `metric__lab_request`** (MAUI-6909, Salman), which this model renames and
rewrites. That model sourced only from `clinical__measurement`'s lab branch, which keeps tests
carrying a reading under a request that was not withdrawn (its own BL-009/BL-011) -- so
requested-but-unresulted and cancelled tests were absent by construction, and the headline
indicator of this card could not be answered. Its `metric_id` also named a request while its
grain was the test. Every row it emitted is still emitted here, as the subset where the results
join hits and `is_completed` is true, so its FSM Dental use case is preserved; `department` is
carried forward unchanged for that reason (BL-002). Renamed rather than deprecated in place: it
was one day old with no downstream consumer in `tupaia-data-product`, and D5 holds that a
`metric_id` is stable and never reused, so correcting it early was cheaper than carrying a
misnamed id.

**Who reads it.** The Tupaia laboratory dashboard (MAUI-6837), via a data table over this view
in `tupaia-data-product` -- not yet built as of this spec. The FSM Dental lab-activity cards
(MAUI-6909) are the inherited consumer, scoped by `department` and `is_completed`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of laboratory tests ordered -- no external body registers a single lab-activity count indicator |

No AIHW METeOR element is registered. AIHW's pathology reporting is built on Medicare
Benefits Schedule item counts, which carry neither an unfulfilled order nor a turnaround
time, so neither requested-versus-completed nor turnaround can be anchored to it. This is a
BES composition over Tamanu's own `lab_requests`/`lab_tests` objects,
`definition_source: BES`, the same status `metric__encounter_diagnosis` and
`metric__opd_imaging_request` carry. Pending alignment with the deploying country's national
HMIS definition.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted at `error` severity -- a duplicate would
double-count a test in any consumer that sums `value_numeric`.

`subject_id` is `lab_tests.id`, matching the registry's `subject_grain: lab_test`.

**Test, not request (BL-003).** A lab request fans out to one `lab_tests` row per ordered
test type. Test grain is chosen because the requested indicators are test-level, and because
`clinical__measurement`'s lab branch is keyed on `lab_tests.id` -- so the join to results is
1:1 and cannot fan out. The cost is that a five-test panel counts as five tests;
`lab_request_id` is emitted so a consumer that wants order counts can
`count(distinct lab_request_id)` where `sum(value_numeric)` counts tests. See OQ-001.

## Output schema

D5 wide format, plus eleven disaggregation columns, an order identifier, and two measure attributes.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `lab_test`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | `lab_tests.id`. `not_null` |
| `period_start` | timestamp | Request placed (BL-002) |
| `period_end` | timestamp | The test's own completion. NULL until then (BL-002, BL-006) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The encounter's own location's facility (BL-010). `not_null` |
| `encounter_type` | varchar(255) | The resolved segment's own `encounter_type` (BL-010). `not_null` |
| `encounter_setting` | text | `Outpatient` (9202) / `Inpatient` (9201) / `Other`. Emergency deliberately unnamed (BL-010). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | The test carries a completion timestamp (BL-006). Never NULL |
| `lab_request_id` | varchar(255) | The order this test belongs to, so orders can be counted as well as tests (BL-003). Not a disaggregation -- an identifier, like `age_years` is a measure. `not_null` |
| `is_panel_request` | boolean | Test was ordered as part of a panel (BL-003). Never NULL |
| `department` | text | The encounter's own department, e.g. Dental, resolved to a name (BL-002). Never NULL |
| `lab_test_type` | text | Test name as recorded, else its code, else `'Not recorded'` (BL-008). Never NULL |
| `lab_test_type_code` | text | Test code as recorded, else `'Not recorded'` (BL-008). Never NULL |
| `lab_test_category` | text | Request's category name, else `'Not recorded'` (BL-008). Never NULL |
| `result` | text | Result as recorded and unclassified, else `'Not recorded'` (BL-008, BL-009). Never NULL |
| `age_years` | integer | Age in whole years at the request, unbanded (BL-011). A measure, not a dimension |
| `turnaround__minutes` | integer | Request placed to test completed, in minutes. NULL unless completed. Can be negative where the completion was backdated, emitted as recorded (BL-007). A measure, not a dimension |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product` at
`tamanu/data_tables/lab_test__standard.yml`, the same convention every other metric in the
family uses -- filter types, aggregation and any bands are the consumer's vocabulary, not
dbt's. This model therefore carries no `data_table_*` meta.

## Business logic

- **BL-001 (one metric, no outpatient or inpatient siblings):** the setting is a column
  (`encounter_setting`, BL-010), not a separate `metric_id`. This matches where the procedure
  and imaging families landed, and departs from diagnosis, which still ships `ipd_` and `opd_`
  variants. The dividing line is the event's shape, not its domain.

  A **diagnosis** stays valid from its own date to the end of the encounter, so its window can
  overlap an outpatient *and* an inpatient segment, and it legitimately counts in both. No
  single column can express membership of two settings at once, which is why
  `metric__ipd_diagnosis` and `metric__opd_diagnosis` exist.

  A **lab order** is point-in-time. It resolves to exactly one segment, so there is no
  double-count case, and filtering `encounter_setting = 'Outpatient'` returns precisely the
  rows a separate `opd_lab_test` would. Three models would be the same answer computed three times
  -- and in production, where the bundle ships as views (D5), three views re-running the same
  `lab_requests`/`lab_tests`/`visit_detail` joins.

  Procedures and imaging requests share the lab shape, not the diagnosis shape, and have since
  been collapsed the same way -- `metric__procedure` folded in its OPD/IPD variants (#1462) and
  `metric__imaging_request` replaced `metric__opd_imaging_request` (#1385). This model follows
  that settled pattern rather than setting its own.

  **Emergency is the exception, in all three families.** `metric__ed_procedure` and
  `metric__ed_imaging_request` remain separate metrics on OMOP 9203, and `encounter_setting`
  deliberately names no emergency value, so an emergency card cannot be drawn off the merged
  metric. Lab follows suit: emergency-ordered tests read `'Other'` here, and a
  `metric__ed_lab_test` is deferred until an ED consumer asks (OQ-010). Nothing on MAUI-6837
  needs it -- the card asks for requested-versus-completed, turnaround, category and result,
  with no setting split at all.

  **If sibling `metric_id`s are wanted later** -- to address a setting by name from a dashboard
  rather than by column filter -- D5's grouping pattern covers it: this one model emits extra
  `metric_id`s off the same scan, no new model. Deliberately deferred, because adding a
  `metric_id` later is a registry row plus a union branch, while removing one is breaking (D5:
  a `metric_id` is stable and never reused).

- **BL-002 (reporting period):** `period_start` is `lab_requests.requested_datetime`, the
  moment the order was placed. It is request-level, denormalised onto every test of the
  request -- every test in a request is ordered together. `period_end` is the **test's own**
  `lab_tests.completed_datetime` (BL-006), which is *not* shared that way: a request can be
  published while one of its tests was never run, so completion is per-test and the two ends of
  the period come from different levels. `period_granularity` is `'minute'`.

- **BL-003 (grain is the test):** `subject_id` is `lab_tests.id`. The alternative, request
  grain with test types aggregated the way `metric__opd_imaging_request` aggregates body
  areas, was rejected: it cannot answer requested-versus-completed per test, and it would
  fan out against `clinical__measurement`, whose lab branch is keyed on `lab_tests.id`.
  A request with no `lab_tests` rows contributes nothing, matching
  `macros/datasets/lab_tests.sql`, which inner-joins the same way.
  **Panel consequence:** a five-test panel is five rows. Two columns address that, and they
  answer different questions. `lab_request_id` is the order the test belongs to, so
  `count(distinct lab_request_id)` counts orders where `sum(value_numeric)` counts tests.
  `is_panel_request` (`lab_requests.lab_test_panel_request_id is not null`) only says whether a
  test arrived as part of a panel -- it cannot support an order count on its own, since it
  names no panel, and an earlier draft of this spec wrongly claimed it could. See OQ-001.

- **BL-004 (order facts from `bases/`, results from `clinical__`):** decision, Juliana,
  2026-09-23. `clinical__` models hold what clinically happened; an order is an intent.
  A requested-but-unresulted test is therefore absent from the clinical layer by design, and
  this model reads `bases/lab_requests` and `bases/lab_tests` directly for the order side.
  This is D10-compliant -- D10 forbids reading `public.*`, not `bases/`. Results remain
  clinical events and are read from `clinical__measurement` (BL-008). Note that the same
  rule is *not* currently applied to imaging requests (`clinical__procedure_occurrence`) or
  prescriptions (`clinical__drug_exposure`), both of which hold intents today; see OQ-006.

- **BL-005 (membership):** every `lab_tests` row whose request is not `deleted` or
  `entered-in-error` is included. Those two assert the order never happened. `cancelled`,
  `invalidated`, `rejected` and `sample-not-collected` are **kept** -- each was genuinely
  ordered, and they are half the requested-versus-completed story. This is a deliberate
  departure from `clinical__measurement`'s lab branch (its own BL-011), which excludes all
  six, and is why the results join is a LEFT join (BL-008). Soft-deleted tests, requests,
  encounters and the test patient are already excluded by `bases/lab_tests`.

- **BL-006 (completion is the test's own timestamp):** `is_completed` is
  `lab_tests.completed_date is not null`. Decision (2026-09-24): deliberately **not** the
  request reaching `published`. Completion is a property of the individual test and this
  metric's grain is the test -- a request can be published while one of its tests was never
  run, which on Tokelau is 426 of 2502 tests. Request status is read only for membership
  (BL-005), never for completion.

  The choice moves the headline number: requested versus completed reads 2502 vs **1901**,
  where completion-by-publication would have read 2502 vs 2326. The narrower figure is the
  defensible one, since it counts tests that were actually run rather than tests belonging to a
  released request.

  Keying completion and turnaround on the same timestamp is also what makes the consumer's
  average work: filtering `is_completed` selects exactly the population that has a turnaround
  to average, bar the backdated exception in BL-007.

  `is_completed` does **not** mean the test has a result -- a completed test can carry no
  reading -- so "has a result" is read from `result` instead (BL-008). Nor does it distinguish
  cancelled from still pending: both are false.

- **BL-007 (turnaround as a measure, not an average):** `turnaround__minutes` is
  `completed_date - requested_date` in whole minutes, NULL unless `is_completed`. Emitted per
  test so the consumer averages it, following `metric__inpatient_admission`'s
  `length_of_stay__minutes` (its BL-015). A pending test has no turnaround, not a turnaround of
  zero, so it must leave the denominator as well as the numerator -- the NULL is what makes
  that possible. Pre-aggregating here would average averages once a card groups by facility.

  **A completion recorded before its request yields a negative duration, and it is emitted as
  one.** 22 tests on Tokelau, the worst by about a day, consistent with backdated entry rather
  than a timezone offset. Decision (2026-09-24): not nulled, not clamped, not filtered. The
  model reports what was recorded rather than quietly repairing it -- a deployment that cannot
  see its bad timestamps has no reason to fix them, and each of those workarounds would hide
  the problem in the one place it is visible. `ac_metric__lab_test_turnaround_not_negative` is
  the signal: it warns with the row count, and that count reaching zero is what a cleaned
  deployment looks like.

  `period_end` is likewise the completion as recorded, so `period_end < period_start` on those
  rows and the period-ordering AC warns too. Same reasoning, and neither test can fail a build.

  **Consequence for the consumer:** an unguarded average includes the negatives. On Tokelau
  that is 22 rows in 1901, so the effect is small, but a card showing turnaround should decide
  explicitly whether to exclude them rather than inherit them unnoticed. See OQ-009.

  **Distribution on Tokelau** (1879 rows with a turnaround): median 115 minutes, mean 2485,
  p95 8824. Heavily skewed, so a consumer showing a mean will report roughly 41 hours for a lab
  that usually turns around in under two. Worth a median, or a p90, rather than
  `view__metric_mean` as it stands -- see OQ-009.

- **BL-008 (results and identity, as recorded):** the results join is
  `clinical__measurement.measurement_id = lab_tests.id` on the lab branch
  (`measurement_type_source_value = 'lab'`), LEFT, so an unresulted test survives (BL-005).
  `result` is the measurement's `value_source_value`; `lab_test_type` and
  `lab_test_type_code` come from `bases/lab_test_types`; `lab_test_category` resolves
  `lab_requests.lab_test_category_id` through `bases/reference_data`. All four are emitted
  raw and ungrouped -- classifying a result or a category is a presentation choice a
  deployment may set differently, so it happens at the data-table layer, the same division
  `metric__encounter_diagnosis` BL-006 makes for diagnosis. Each is coalesced to
  `'Not recorded'`: Tupaia exposes them as array filters, and an array filter silently drops
  a NULL row. Note `lookup__lab_category` is named in D2 but does not exist, so category is
  the deployment's own reference-data name.

- **BL-009 (positivity is neither materialised nor classified):** the model emits `result`
  raw and stores no positivity flag and no rate. Two separate decisions, for two reasons.

  **No stored rate**, because a stored proportion sums incorrectly wherever a disaggregation is
  collapsed (D5 rate scale). The consumer forms the ratio with `bar__metric_ratio`, testing
  `result` on both sides.

  **No classification either** (decision, 2026-09-24). Deciding which recorded values mean
  "positive" -- `Reactive`, `Detected`, `POS`, and every local variation -- is a deployment
  vocabulary question, not a definitional one, so it belongs at the data-table layer over
  `result`, the same division BL-008 makes for test type and category and the same precedent
  MAUI-6836 sets for diagnosis. A standard-package map keyed on result text was built and then
  removed: it would have added a model every deployment inherits in order to answer a question
  only some deployments ask, and `tamanu/data_tables/` can already express the mapping through
  its own `mapped_from` block.

  **The point-of-care path still works without any join here.** A rapid test recorded by
  choosing a result-bearing test type carries its reading in the type, not in `lab_tests.result`
  -- but `clinical__measurement` already resolves that through `map__lab_test_result_encoding`
  into `value_source_value` (its own BL-009), so those readings arrive in `result` like any
  other. This model needs no map of its own.

  **Consequence for the consumer:** a positivity card is a data-table-level classification over
  `result` plus a ratio visual, not a column read off this model. Until a deployment writes
  that classification, it has no positivity rate -- which is the honest state, rather than a
  card reading zero because unclassified tests were silently counted as negative. See OQ-003.

- **BL-010 (attribution is as-at the order, not as-it-now-stands):** `encounter_setting`,
  `encounter_type`, `department` and `facility_id` all come from the `clinical__visit_detail`
  segment active when the test was **ordered** -- the latest segment that had started by
  `requested_datetime`, clamped to the earliest segment for a request that predates them all.

  The derivation is **inline**, not shared. It repeats the rule
  `clinical__procedure_occurrence` applies for its own `visit_detail_id` (that model's BL-005),
  which `metric__procedure` and `metric__imaging_request` then read off an FK -- a lab order
  cannot, being deliberately outside the clinical layer (BL-004). A macro was written and then
  withdrawn: with `clinical__procedure_occurrence` keeping its own copy either way, factoring
  lab's out removed no duplication, and it moved the model's most consequential rule into a
  second file against the metric layer's inline-with-BL-comments convention. When referrals or
  appointments need the same resolution, extract it then -- for three callers, not one.

  **Why not the encounter.** Tamanu updates `encounters.encounter_type`, `location_id` and
  `department_id` **in place** as an encounter progresses, so reading them gives the encounter
  as it now stands, not as it was at the order. Measured on Tokelau before this was fixed: 166
  of 2502 tests (6.6%) were attributed to the wrong setting, and every one ran the same
  direction -- 135 `clinic` → `admission` and 31 `triage` → `admission`. It does not wash out;
  it systematically inflates inpatient lab activity and erases the ED and outpatient share, on
  the exact dimension the dashboard splits by. The corrected split is 2111 outpatient, 360
  inpatient, 31 emergency; previously it read 1976 / 526 / 0. `department` drifted on 164 tests
  the same way. `facility_id` happened not to move on Tokelau -- all 350 location changes were
  within one facility -- but that is a deployment fact, not a guarantee.

  **Why `requested_datetime` and not `published_datetime`.** The question is where the test was
  *ordered*; and a pending or cancelled test has no publication event to anchor to at all, so
  anchoring there would leave exactly the rows this metric exists to count unattributable.

  **Why a label, not the raw concept id.** `encounter_setting` is the shape `metric__procedure`
  settled on: one stable value a consumer filters, rather than a concept id each consumer has
  to know, or an `encounter_type` list that drifts as `map__omop_visit_type` gains types.
  `'Outpatient'` is the full 9202 scope -- clinic, imaging and vaccination -- which is wider
  than `encounter_type = 'clinic'`.

  Lab follows `metric__procedure` here rather than `metric__imaging_request`, which carries no
  `encounter_setting` at all: outpatient imaging is deliberately clinic-only, because an
  imaging-typed encounter and an imaging request are independent Tamanu concepts that share a
  name (MAUI-6806), so an `'Outpatient'` label there would overclaim. Labs have no such
  collision -- a test ordered during a vaccination encounter is outpatient lab activity like
  any other -- so the full scope is correct and the label is honest.

  `encounter_type` is emitted alongside, raw, for a consumer that wants `vaccination`
  specifically. The two are **not** interchangeable: 9202 covers three `encounter_type` values
  and 9203 another three.

  **No emergency value**, matching `metric__procedure`: emergency reporting has its own metrics,
  and naming it here would let an emergency card be drawn off this one. Emergency-ordered tests
  fall in `'Other'` (31 of 2502 on Tokelau). See OQ-010.

  **Inner join**, so a test whose encounter resolves to no segment is excluded rather than
  carrying a NULL facility. Every encounter has at least one segment, *provided* its
  `encounter_type` is in `map__omop_visit_type` -- an unmapped type loses its segments entirely
  (`clinical__visit_detail` BL-003) and would drop the test. Guarded at source by
  `data_test__map__omop_visit_type_coverage`.

- **BL-011 (age is a measure):** age in whole years at `requested_datetime`, via the
  `age_years` macro, which owns the NULL rule. Unbanded -- an age classification is a
  presentation choice a deployment may set differently, so the consumer's data table bands it.

- **BL-012 (sensitive test types are not filtered):** `lab_test_types.is_sensitive` is
  available but is **not** applied here. Filtering it is a deployment privacy decision, not a
  definitional one, and the standard metric stays universal. A deployment that must suppress
  them does so at the data-table layer. Flagged rather than assumed -- see OQ-004.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC | `metric_id` is `not_null` and always `lab_test` | BL-001 | `not_null` + `accepted_values` |
| AC | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC | `subject_id` is `not_null` | grain | `not_null` |
| AC | `period_start` is `not_null` | BL-002 | `not_null` |
| AC | `period_end`, where present, is at or after `period_start` -- **warns** on backdated completions, by design | BL-002, BL-007 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` (warn) |
| AC | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC | `value_numeric` is `not_null` and always `1` | BL-003 | `not_null` + `accepted_values` |
| AC | `facility_id` is `not_null` | BL-010 | `not_null` |
| AC | `encounter_type` is `not_null` | BL-010 | `not_null` |
| AC | `is_completed` is `not_null` | BL-006 | `not_null` |
| AC | `is_panel_request` is `not_null` | BL-003 | `not_null` |
| AC | `lab_request_id` is `not_null` | BL-003 | `not_null` |
| AC | `period_end` and `turnaround__minutes` are read off the test's completion, not the request's publication | BL-006 | dbt unit test `test_metric__lab_test_membership` (its fixture publishes the request at a different time from the test's completion, so the swap fails) |
| AC | `lab_test_type`, `lab_test_type_code`, `lab_test_category`, `result` are `not_null` | BL-008 | `not_null` |
| AC | `turnaround__minutes` is populated if and only if `is_completed` | BL-007 | `dbt_utils.expression_is_true` |
| AC | `turnaround__minutes`, where present, is not negative -- **warns** on backdated completions, by design | BL-007 | `dbt_utils.expression_is_true` (warn) |
| AC | The results join does not fan out: one row per ordered test, whether or not a result exists | BL-003, BL-008 | schema test `ac_metric__lab_test_grain` (`unique_combination_of_columns`, error), plus dbt unit test `test_metric__lab_test_membership`, whose fixture puts a resulted and an unresulted test on one request and expects one row each |
| AC | An uncompleted, cancelled, completed and backdated test each land correctly across `is_completed`, `period_end`, `result` and `turnaround__minutes` | BL-005, BL-006, BL-007, BL-008 | dbt unit test `test_metric__lab_test_membership` |
| AC | `result` passes through as recorded -- unclassified, casing preserved, `'Not recorded'` where absent | BL-008, BL-009 | dbt unit test `test_metric__lab_test_result_passthrough` |

## Registry entry

One active row in `documentations/metrics/lab.yml` -- `lab_test`,
`kind: metric`, `subject_grain: lab_test`, `status: draft`, `spec_path` pointing here, with
`disaggregations: facility_id, encounter_type, encounter_setting, sex, is_completed,
is_panel_request, department, lab_test_type, lab_test_type_code, lab_test_category, result`.

`lab_request_id` is emitted but **not** registered as a disaggregation: it is an identifier a
consumer counts distinctly, not a dimension to group a card by, so it stays out of the
registry for the same reason `age_years` and `turnaround__minutes` do.

Regenerate `macros/metric_definitions.sql` with
`python scripts/generate_metric_definitions_macro.py` and commit it -- CI fails on drift.

`is_panel_request`, `lab_test_type`, `lab_test_type_code`, `lab_test_category` and `result`
are new to the allowlist in `assert__metric_definitions__disaggregations`. The
already-admitted `is_positive` is deliberately not used: this model classifies nothing, so it
registers no positivity column at all -- see BL-009. `facility_id`, `encounter_type`, `encounter_setting`, `sex`, `is_completed` and `department`
are already admitted by earlier metrics -- `encounter_setting` by `metric__procedure`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `lab_requests` | `bases/` | Order timestamps, status, category, panel link, encounter (BL-002, BL-003, BL-005, BL-006) |
| `lab_tests` | `bases/` | Grain anchor; test type link (BL-003) |
| `lab_test_types` | `bases/` | Test name and code (BL-008) |
| `reference_data` | `bases/` | Category name for `lab_requests.lab_test_category_id` (BL-008) |
| `departments` | `bases/` | Name of the resolved segment's `department_id` (BL-002, BL-010) |
| `clinical__measurement` | `clinical/` | The result, LEFT joined on the lab branch -- including point-of-care readings it has already resolved through `map__lab_test_result_encoding` (BL-008, BL-009) |
| `clinical__visit_detail` | `clinical/` | The segment active at the order: `visit_detail_concept_id` for `encounter_setting`, `visit_detail_source_value` for `encounter_type`, plus its own `care_site_id`, `department_id` and `person_id` (BL-010) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-011) |
| `locations` | `bases/` | Facility id of the resolved segment's `care_site_id` (BL-010) |
| `metric_definitions` | root | Registry; `metric_id` FK target |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Laboratory dashboard (MAUI-6837). Not yet built as of this spec |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Classify and form positivity itself.** The metric emits `result` raw, so a positivity
   card is a data-table-level classification over that column plus a ratio visual. Classify
   explicitly rather than treating unclassified values as negative, or they inflate the
   denominator. Never sum a stored rate (BL-009).
3. **Average turnaround with a predicate.** `sum(turnaround__minutes) / sum(value_numeric)`
   restricted to `is_completed`, not an `AVG` in the data table -- an average per facility
   would then be averaged again by the card, weighing a quiet facility the same as a busy one.
4. **Know what a "test" is.** A panel is one order and several tests (BL-003). Use
   `is_panel_request` if order counts are wanted.
5. **Not read `is_completed` as "not cancelled."** A cancelled test and a still-pending one
   are both `false` (BL-006).
6. **Band `age_years` and group `result`/`lab_test_category` itself**, if wanted -- none is
   emitted grouped here (BL-008, BL-011).
7. **Decide on sensitive test types** (BL-012) -- this model does not filter them.

## Related

| Artefact | Relationship |
|---|---|
| `metric__encounter_diagnosis` | The generic-with-`encounter_type` pattern this model follows (BL-001), and the raw-and-ungrouped convention for recorded values (BL-008) |
| `metric__inpatient_admission` | The duration-as-a-measure pattern `turnaround__minutes` follows (BL-007) |
| `metric__opd_imaging_request` | The nearest request-shaped metric; takes the opposite grain decision (request, with children aggregated) and reads its order from `clinical__procedure_occurrence` rather than `bases/` -- see BL-004 and OQ-006 |
| `map__lab_test_result_encoding` | Not joined by this model. `clinical__measurement` already applies it, so point-of-care readings reach `result` without it (BL-009) |
| `clinical__measurement` | Holds the result side; excludes unresulted and withdrawn tests, which is why BL-005's membership is wider and BL-008's join is LEFT |
| `ds__lab_requests` / `ds__lab_tests` | Report-layer lab datasets at test grain, with PII -- different layer (D6), different consumer, not affected by this work |
| `metric__lab_request` | Superseded by this model -- same grain, narrower membership (resulted tests only), misnamed id. Renamed, not deprecated in place; see Purpose |
| `metric__pharmacy_order` | The "bundle vs. line" grain reasoning this model inherits (the ordered line, not the order), and the same encounter-level facility and department attribution |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

- **OQ-001 (panel counting):** a five-test panel counts as five tests. Correct for laboratory
  workload, wrong for "how often were labs ordered". Both numbers are now available --
  `sum(value_numeric)` for tests, `count(distinct lab_request_id)` for orders -- but the
  headline card still needs a decision on which one it shows. Outstanding with Juliana.
- ~~**OQ-002 (what "completed" means)**~~ -- resolved 2026-09-24: the test's own
  `completed_date`, not request publication and not the presence of a result. See BL-006.
- **OQ-003 (who classifies results for positivity):** the metric classifies nothing (BL-009),
  so Tokelau's positivity card needs a classification written at the data-table layer by
  someone who knows the deployment's result vocabulary. Unassigned, and it blocks that card
  specifically -- not the rest of the dashboard.
- **OQ-004 (sensitive test types):** include, exclude, or include while suppressing the
  test-name disaggregation. A low-volume facility plus a named test type can be revealing
  even in aggregate.
- **OQ-005 (turnaround start point):** BL-007 runs request placed to test completed (decided
  2026-09-24). `lab_requests.collected_datetime` would measure laboratory performance
  specifically, excluding the wait for phlebotomy -- still open as a refinement.
- **OQ-010 (emergency lab tests):** they read `'Other'` in `encounter_setting` and are not
  separately addressable, matching how `metric__procedure` and `metric__imaging_request` handle
  emergency. A `metric__ed_lab_test` on OMOP 9203 is the established answer when an ED consumer
  asks; nothing on MAUI-6837 does.
- **OQ-009 (the turnaround visual):** two separate problems for whoever builds the card.
  First, the distribution is heavily skewed -- median 115 minutes against a mean of 2485 on
  Tokelau -- so `view__metric_mean` would report ~41 hours for a lab that usually turns around
  in under two; the card wants a median or a percentile, which no current template provides.
  Second, negative turnarounds flow through by design (BL-007), so the card has to decide
  explicitly whether to exclude them.
- **OQ-006 (the intent rule's existing exceptions):** BL-004's principle is not applied to
  imaging requests or prescriptions, both of which sit in `clinical__` today. Either they are
  grandfathered and documented as exceptions, or they are unwound -- the latter is rework on
  MAUI-6806, which is Complete. Pending a ruling.
- **OQ-007 (IPD/OPD siblings):** segment-scoped variants are separate specs. Open within
  them: whether a test is attributed to the segment active when it was *ordered* or when it
  was *resulted*, and whether OPD means full OMOP 9202 or `clinic` only.
- **OQ-008 (interim and amended results):** `interim_results` is a real status and a result
  can be revised. `clinical__measurement` carries one row per test, so this model inherits
  whatever that model resolves to; confirm it is the current value rather than the first.

## Change log

| Date | Change |
|---|---|
| 2026-09-23 | `metric__lab_request` added, sourced from `clinical__measurement`'s lab branch (MAUI-6909) |
| 2026-09-24 | Completion and turnaround keyed on the test's own `completed_date` rather than request publication; backdated completions emitted as negative durations rather than repaired, so the deployment can see and fix them (MAUI-6837) |
| 2026-09-28 | Review fixes: emit `lab_request_id`, since `is_panel_request` alone cannot support an order count as the spec had claimed; drop a tautological `period_end`/`is_completed` data test in favour of a unit-test fixture that can actually catch a regression to the request's publication time (MAUI-6837) |
| 2026-09-28 | Merged main and aligned with the settled family shape: `visit_detail_concept_id` replaced by `encounter_setting` (`metric__procedure` #1462, `metric__imaging_request` #1385), emergency deliberately unnamed and deferred to a future `metric__ed_lab_test` (MAUI-6837) |
| 2026-09-24 | Setting, department and facility attributed to the `clinical__visit_detail` segment active at the order, rather than to the encounter as it now stands; per-setting sibling metrics dropped (MAUI-6837) |
| 2026-09-24 | Dropped `result_classification` and the `map__lab_result_classification` map: classification is a deployment vocabulary question and belongs at the data-table layer over raw `result` (MAUI-6837) |
| 2026-09-23 | Renamed to `metric__lab_test` and rewritten to source the order side from `bases/`, so requested-but-unresulted and cancelled tests are counted. Added `is_completed`, `encounter_type`, `is_panel_request`, `lab_test_category`, `result` and `turnaround__minutes`; moved `period_start` to the request timestamp at minute granularity (MAUI-6837) |

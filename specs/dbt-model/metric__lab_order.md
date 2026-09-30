# dbt Model Spec: `metric__lab_order` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__lab_order` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6837 (renamed from `metric__lab_request`, MAUI-6909) |
| **Created** | 2026-09-23 |

Canonical definition for `lab_order`: one row per lab request raised from a panel, labelled
with the panel however many tests it holds, and one row per lab test on a request raised
without one. The generic counterpart to `metric__ed_lab_order`, carrying `encounter_setting`
rather than scoping to a single setting. **No outpatient or inpatient siblings** -- see BL-001.

## Purpose

Laboratory ordering activity, one row per order line.

| `metric_id` | Unit | Measures |
|---|---|---|
| `lab_order` | count | Lab order lines placed (always 1 per row) |

**The panel rule.** A request raised from a panel is one order line labelled with the panel,
however many tests it holds -- a Full Blood Count is one order, not three. A request raised
without a panel is one order line per test on it. Decision (Juliana, 2026-09-30), matching
`metric__ed_lab_order`.

**What this grain costs.** A row can cover several tests, so three things the per-test
predecessor carried are no longer expressible and are deliberately absent:

- **The result.** A panel has many tests and so many results; there is no single value for the
  row. `clinical__measurement` is not joined at all.
- **Positivity.** It was a classification over the result, so it goes with it.
- **Turnaround from the test's own completion.** Completion is per test; at order-line grain
  the only completion a row can carry is the request's publication (BL-006), which is what
  `period_end` reports.

A consumer needing results or positivity needs a per-test metric, which this is not.

**Who reads it.** The Tupaia laboratory dashboard, via a data table over this view in
`tupaia-data-product`. Not yet built as of this spec.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of laboratory tests ordered -- no external body registers a single lab-activity count indicator |

No AIHW METeOR element is registered. AIHW's pathology reporting is built on Medicare
Benefits Schedule item counts, which do not carry an unfulfilled order, so
requested-versus-completed cannot be anchored to it. This is a
BES composition over Tamanu's own `lab_requests`/`lab_tests` objects,
`definition_source: BES`, the same status `metric__encounter_diagnosis` and
`metric__opd_imaging_request` carry. Pending alignment with the deploying country's national
HMIS definition.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted at `error` severity -- a duplicate would
double-count an order in any consumer that sums `value_numeric`, and would also catch an id
appearing in both branches of the union.

`subject_id` is the `lab_requests` id on a panel line and the `lab_tests` id on a single-test
line. The two id spaces are disjoint, so it is unique across the union.

**Panel lines are keyed on the request, not the panel request.** A panel spanning several
categories fans into one `lab_requests` row per category, each with its own status and
timestamps. Collapsing them onto the panel request would leave no single status or
`requested_datetime` to report, so each request is its own line, all labelled with the panel.

## Output schema

D5 wide format, plus eleven disaggregation columns, an order identifier, and one measure.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `lab_order`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | `lab_requests.id` on a panel line, `lab_tests.id` on a single. `not_null` |
| `period_start` | timestamp | Request placed (BL-002) |
| `period_end` | timestamp | Request published. NULL until then (BL-006) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The resolved segment's own location's facility (BL-010). `not_null` |
| `encounter_type` | varchar(255) | The resolved segment's own `encounter_type` (BL-010). `not_null` |
| `encounter_setting` | text | `Outpatient` (9202) / `Inpatient` (9201) / `Other`. Emergency deliberately unnamed (BL-010). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | The request published (BL-006). Never NULL |
| `request_status` | text | The request's lifecycle status as recorded (BL-006). Never NULL |
| `lab_request_id` | varchar(255) | The request this line belongs to. Not a disaggregation -- an identifier. `not_null` |
| `is_panel` | boolean | Whether the line is a panel or a single test (BL-002, BL-003). Never NULL |
| `department` | text | The resolved segment's own department, resolved to a name (BL-010). Never NULL |
| `lab_order_code` | text | Panel code on a panel line, test type code on a single (BL-007). Never NULL |
| `lab_order` | text | Panel name on a panel line, test type name on a single (BL-007). Never NULL |
| `lab_test_category` | text | The request's category, as recorded (BL-008). Never NULL |
| `age_years` | integer | Age in whole years at the order, unbanded (BL-011). A measure, not a dimension |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product` at
`tamanu/data_tables/lab_test__standard.yml`, the same convention every other metric in the
family uses -- filter types, aggregation and any bands are the consumer's vocabulary, not
dbt's. This model therefore carries no `data_table_*` meta.

## Business logic

- **BL-001 (one metric, no outpatient or inpatient siblings):** the setting is a column
  (`encounter_setting`, BL-010), not a separate `metric_id`. A lab order is point-in-time: it
  resolves to exactly one segment, so it cannot belong to two settings at once, and filtering
  `encounter_setting = 'Outpatient'` returns precisely the rows a separate `opd_lab_test`
  would. This matches `metric__procedure` (#1462) and `metric__imaging_request` (#1385), which
  share that shape. Diagnosis does not, and keeps its `ipd_`/`opd_` variants: a diagnosis stays
  valid to the end of the encounter, so its window can overlap an outpatient *and* an inpatient
  segment and legitimately counts in both, which no single column can express.

  **Emergency is the exception, in all three families.** `metric__ed_procedure` and
  `metric__ed_imaging_request` are separate metrics on OMOP 9203, and `encounter_setting`
  names no emergency value, so an emergency card cannot be drawn off the merged metric.
  Emergency-ordered lab tests read `'Other'` here; a `metric__ed_lab_test` belongs to an ED
  consumer (OQ-010).

- **BL-002 (the panel rule, and the reporting period):** a request raised from a panel is one
  order line, labelled with the panel, however many tests it holds. `is_panel` is true on
  those rows. `period_start` is `lab_requests.requested_datetime`; `period_end` is the
  request's publication (BL-006). Both are request-level, which is coherent here because a
  line never spans more than one request (see Grain).

- **BL-003 (single-test lines):** a request raised without a panel is one order line per
  `lab_tests` row on it, labelled with the test type, `is_panel` false. A request with no
  `lab_tests` rows contributes nothing. The two branches are unioned; their id spaces are
  disjoint, so the grain assertion also guards the union.

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

- **BL-006 (completion is the request's publication):** `is_completed` is
  `lab_requests.status = 'published'`. At order-line grain a row can cover several tests, so
  the test's own `completed_date` cannot describe it -- this is a direct consequence of the
  panel rule, not an independent choice, and it is the same rule `metric__ed_lab_order` uses.

  It does **not** mean the results still stand: a request published and later invalidated,
  cancelled or rejected reads `is_completed` true. `request_status` carries the lifecycle
  value as recorded so a card counting delivered results can exclude those, while one counting
  orders placed does not. Nor does `is_completed` separate a cancelled line from a pending one
  -- both are false, and again `request_status` is what tells them apart.

- **BL-007 (order identity, as recorded):** `lab_order` and `lab_order_code` are the panel's
  name and code on a panel line and the test type's on a single. Emitted raw and ungrouped --
  classifying either is a presentation choice a deployment may set differently, so it happens
  at the data-table layer. Both are coalesced so neither is ever NULL: Tupaia exposes them as
  array filters, and an array filter silently drops a NULL row.

- **BL-008 (category):** `lab_test_category` resolves `lab_requests.lab_test_category_id`
  through `bases/reference_data`, coalesced to `'Not recorded'`. Request-level, so every line
  of a request shares it. Emitted ungrouped for the same reason as BL-007. Note
  `lookup__lab_category` is named in D2 but does not exist, so this is the deployment's own
  reference-data name.

- **BL-009 (no result, and therefore no positivity):** `clinical__measurement` is not joined.
  A panel line covers several tests and so several results, with no single value to report, so
  the column cannot exist at this grain. Positivity was a classification over the result and
  goes with it.

  This is a deliberate loss, decided with the panel rule (Juliana, 2026-09-30): the original
  card asked for a results breakdown and a positivity rate, and neither is expressible here. A
  consumer needing them needs a per-test metric alongside this one. See OQ-003.

- **BL-010 (attribution is as-at the order, not as-it-now-stands):** `encounter_setting`,
  `encounter_type`, `department` and `facility_id` all come from the `clinical__visit_detail`
  segment active when the test was **ordered** -- the latest segment that had started by
  `requested_datetime`, clamped to the earliest segment for a request that predates them all.

  The derivation is **inline**. It is the same rule `clinical__procedure_occurrence` applies
  for its own `visit_detail_id` (that model's BL-005), which `metric__procedure` and
  `metric__imaging_request` read off an FK -- a lab order has no such FK, being outside the
  clinical layer (BL-004). When referrals or appointments need the same resolution, it is worth
  extracting for the three callers.

  **Why not the encounter.** Tamanu updates `encounters.encounter_type`, `location_id` and
  `department_id` **in place** as an encounter progresses, so reading them gives the encounter
  as it now stands, not as it was at the order. The difference is not noise: on Tokelau 166 of
  2502 tests (6.6%) resolve to a different setting under the two rules, and every one runs the
  same direction -- `clinic` and `triage` reading as `admission` -- so encounter-level
  attribution systematically inflates inpatient lab activity and erases the ED and outpatient
  share, on the exact dimension the dashboard splits by. `department` drifts on 164 tests the
  same way. `facility_id` happens not to move on Tokelau, since all 350 location changes are
  within one facility, but that is a deployment fact, not a guarantee.

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
| AC | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC | `period_end` is populated if and only if `is_completed` | BL-006 | `dbt_utils.expression_is_true` |
| AC | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC | `value_numeric` is `not_null` and always `1` | BL-001 | `not_null` + `accepted_values` |
| AC | `facility_id`, `encounter_type`, `department` are `not_null` | BL-010 | `not_null` |
| AC | `encounter_setting` is `not_null` and one of `Outpatient`/`Inpatient`/`Other` | BL-010 | `not_null` + `accepted_values` |
| AC | `is_completed`, `request_status`, `lab_request_id`, `is_panel` are `not_null` | BL-002, BL-003, BL-006 | `not_null` |
| AC | `lab_order`, `lab_order_code`, `lab_test_category` are `not_null` | BL-007, BL-008 | `not_null` |
| AC | A panel request with three tests yields ONE row labelled with the panel; a non-panel request with two tests yields one row each labelled with the test type | BL-002, BL-003 | dbt unit test `test_metric__lab_order_grain` |
| AC | A cancelled request is included with `is_completed` false and its status carried; deleted and entered-in-error are excluded | BL-005, BL-006 | dbt unit test `test_metric__lab_order_grain` |
| AC | Setting, department and facility come from the segment active at the order, with the first-segment clamp | BL-010 | dbt unit test `test_metric__lab_order_segment_attribution` |

## Registry entry

One active row in `documentations/metrics/lab.yml` -- `lab_test`,
`kind: metric`, `subject_grain: lab_test`, `status: draft`, `spec_path` pointing here, with
`disaggregations: facility_id, encounter_type, encounter_setting, sex, is_completed,
is_panel_request, department, lab_test_type, lab_test_type_code, lab_test_category, result`.

`lab_request_id` is emitted but **not** registered as a disaggregation: it is an identifier a
consumer counts distinctly, not a dimension to group a card by, so it stays out of the
registry for the same reason `age_years` does.

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

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid. A panel
   counts once.
2. **Know what a row is.** A panel line covers several tests, so this metric counts *ordering
   activity*, not tests performed. `is_panel` separates the two kinds of line.
3. **Not read `is_completed` as "results still stand."** A withdrawn request's line reads
   completed; filter `request_status` to exclude cancelled, invalidated, rejected and
   sample-not-collected (BL-006).
4. **Not expect results or positivity here.** Neither exists at this grain (BL-009).
5. **Band `age_years` and group `lab_order` / `lab_test_category` itself**, if wanted -- none
   is emitted grouped (BL-007, BL-008, BL-011).
6. **Decide on sensitive test types** (BL-012) -- this model does not filter them.

## Related

| Artefact | Relationship |
|---|---|
| `metric__ed_lab_order` | The ED-scoped sibling this model mirrors: same panel rule, same completion rule, scoped to OMOP 9203 instead of carrying `encounter_setting` |
| `metric__encounter_diagnosis` | The generic-with-`encounter_type` pattern this model follows (BL-001), and the raw-and-ungrouped convention for recorded values (BL-008) |
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
- ~~**OQ-005 (turnaround start point)**~~ -- moot: turnaround is not emitted at this grain
  (BL-009). `period_start` and `period_end` remain, so a consumer can derive a
  request-to-publication duration itself.
- ~~**OQ-009 (the turnaround visual)**~~ -- moot for the same reason.
- ~~**OQ-011 (should `is_completed` exclude withdrawn requests?)**~~ -- unchanged in substance:
  it still does not, and `request_status` is still how a consumer excludes them (BL-006).
- **OQ-003 (results and positivity have no home):** the original card asked Queen of Sheba and
  Tokelau for a results breakdown, and Tokelau for a positivity rate. Neither is expressible at
  order-line grain (BL-009). If those cards are still wanted, a per-test metric is needed
  alongside this one. Outstanding with Juliana.
- **OQ-004 (sensitive test types):** include, exclude, or include while suppressing the
  `lab_order` disaggregation. A low-volume facility plus a named panel can be revealing even in
  aggregate.
- **OQ-006 (the intent rule's existing exceptions):** BL-004's principle is not applied to
  prescriptions, which sit in `clinical__drug_exposure` today. Either grandfathered and
  documented, or unwound.
- **OQ-008 (interim and amended results):** not applicable while no result is carried.
- **OQ-010 (emergency lab orders):** they read `'Other'` in `encounter_setting` and are
  `metric__ed_lab_order`'s population, not this metric's.

## Change log

| Date | Change |
|---|---|
| 2026-09-30 | Renamed to `metric__lab_order` and moved to order-line grain: a panel is one row however many tests it holds, mirroring `metric__ed_lab_order` (Juliana). Completion becomes the request's publication, since a row can span several tests. `result`, `turnaround__minutes`, the per-test identity columns and `is_panel_request` dropped; `lab_order`, `lab_order_code` and `is_panel` added (MAUI-6837) |
| 2026-09-29 | `request_status` emitted: completion does not imply the result still stands, since a withdrawn request's line still reads completed (MAUI-6837) |
| 2026-09-28 | Aligned with the procedure and imaging families: `encounter_setting` in place of the raw OMOP concept, no per-setting siblings, and setting/department/facility attributed to the segment active at the order rather than the encounter as it now stands. `lab_request_id` emitted so orders can be counted (MAUI-6837) |
| 2026-09-23 | Added as `metric__lab_request` over `clinical__measurement`'s lab branch, then renamed to `metric__lab_test` and rewritten to source orders from `bases/`, so requested-but-unresulted and cancelled tests are counted (MAUI-6909, MAUI-6837) |

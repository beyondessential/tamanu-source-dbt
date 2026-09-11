# dbt Model Spec: `metric__ipd_imaging_request` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ipd_imaging_request` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-006) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6806 |

Canonical definition for `ipd_imaging_request`: one row per imaging request raised while the
patient was in an **admission** encounter. The inpatient counterpart to
`metric__opd_imaging_request`, built with the exact same as-of-segment pattern -- same
mechanism, same clause numbering, only the scoped encounter type differs (`admission`
instead of `clinic`).

## Purpose

Diagnostic imaging requests raised during inpatient admission care, one row per request.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ipd_imaging_request` | count | Imaging requests raised during an admission encounter (always 1 per row) |

**Why a separate metric, not a filter.** Same reasoning as `metric__opd_imaging_request`
BL-001: kept apart from every other setting as its own metric, following
`metric__opd_procedure`'s precedent (MAUI-6862), rather than mixed with them behind an
`encounter_type` filter on the general `metric__imaging_request`. A consumer wanting the
filter-based answer instead reads `metric__imaging_request` and filters to
`encounter_type = 'admission'` -- encounter-grain, not segment-grain; see BL-003 for why the
two need not agree.

**Why `admission` only is already the full OMOP 9201 definition (contrast the OPD
sibling's BL-003).** `metric__opd_imaging_request` scopes to `clinic` specifically because
the full OMOP concept 9202 also admits `imaging` and `vaccination` encounter types --
narrower than 9202 by decision. No such narrowing question arises here:
`map__omop_visit_type` maps exactly one Tamanu `encounter_type`, `admission`, to concept
9201 (`Inpatient Visit`) -- concept 262 (`admission_from_emergency`) is a
`clinical__visit_occurrence`-level reclassification of an admission encounter that had a
prior ER phase, not a distinct segment-level `encounter_type` (see BL-003). So
`visit_detail_source_value = 'admission'` and `visit_detail_concept_id = 9201` select
exactly the same rows, and this metric already is the full 9201 definition -- there is no
"narrower than the full concept" tradeoff to record here the way there is for the OPD
sibling.

**Answers the same three standing questions about inpatient imaging as the OPD sibling:**

1. **By modality / area** -- `imaging_type` and `imaging_area`.
2. **Turnaround time** -- not currently surfaced. Computable later from
   `period_start`/`period_end` (both remain on the model).
3. **Completed vs cancelled** -- not currently surfaced; `is_completed` (BL-010) cannot tell
   a cancelled request apart from one still pending/in progress. Same accepted gap as the
   OPD sibling (BL-010, OQ-002).

**Who reads it.** The Tupaia inpatient/admissions dashboard, via a data table over this
view in `tupaia-data-product`, once built (MAUI-6806).

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of imaging requests scoped to the inpatient admission setting -- no external body registers this indicator |

No AIHW METeOR element is registered, for the same reason `metric__opd_imaging_request`
carries none: AIHW's own diagnostic-imaging reporting (Medicare Benefits Schedule-based)
does not report completion, cancellation, turnaround time, or body-area breakdown. This
metric is a BES composition over Tamanu's own `imaging_requests` object,
`definition_source: BES`, the same status `metric__procedure`/`metric__opd_imaging_request`
carry.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC at `error` severity -- a
duplicate would double-count a request in any consumer that sums `value_numeric`.

`subject_id` is the imaging request's own id, read as `clinical__procedure_occurrence`'s
`procedure_occurrence_id` (unchanged from `imaging_requests.id`, BL-010), matching the
registry's `subject_grain: imaging_request`. As with the OPD sibling, there is no
encounter-segment stitching to find the subject itself -- one row per request already.
Segment logic here (BL-003) decides *inclusion and scope*, not identity.

## Output schema

D5 wide format, plus six disaggregation columns and one measure attribute -- identical
shape to `metric__opd_imaging_request` (no `encounter_type` column: this metric is already
scoped to a single setting).

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ipd_imaging_request`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Imaging request id. `not_null` |
| `period_start` | timestamp | Request raised (BL-002) |
| `period_end` | timestamp | Marked complete. NULL while pending, in progress, or cancelled (BL-002) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The active admission segment's own location's facility (BL-005). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | `clinical__procedure_occurrence`'s completion flag (BL-010). Never NULL. Does not distinguish `cancelled` from `pending`/`in_progress` |
| `imaging_type` | text | Readable modality label, falling back to `imaging_type_code` then `'Not recorded'` (BL-007). Never NULL |
| `imaging_type_code` | text | Tamanu's raw imaging-type value, or `'Not recorded'` (BL-007). Never NULL |
| `imaging_area` | text | Comma-joined body area/study area, or `'Not recorded'` (BL-007). Never NULL |
| `age_years` | integer | Age in whole years at the request, unbanded (BL-008). A measure, not a dimension |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention `metric__opd_imaging_request` uses. This model
therefore carries no `data_table_*` meta. Not yet built as of this spec.

## Business logic

- **BL-001 (a dedicated metric, not a filter):** matches `metric__opd_imaging_request`
  BL-001 -- kept apart from every other setting as its own metric, rather than mixed with
  them behind an `encounter_type` filter on `metric__imaging_request`.

- **BL-002 (reporting period and status):** identical to `metric__opd_imaging_request`
  BL-002. `period_start` is `clinical__procedure_occurrence.procedure_datetime`. `period_end`
  is the completion timestamp -- `min(imaging_results.datetime)` for the request -- gated on
  `is_completed`, not surfaced merely because a matching `imaging_results` row exists.
  `period_end` is left as recorded, unguarded against a completion before the request (a
  `warn`-severity data-quality check, not a hard invariant). Rows whose Tamanu status is
  `deleted` or `entered_in_error` are excluded upstream, in
  `clinical__procedure_occurrence`'s own BL-002, not re-filtered here (BL-010).

- **BL-003 (inpatient scope: `admission`, equivalent to the full OMOP 9201 -- contrast the
  OPD sibling's narrower-than-9202 scope):** a request is included when the
  `clinical__visit_detail` segment active at its own `requested_date` has
  `visit_detail_source_value = 'admission'`. Equivalently, `visit_detail_concept_id = 9201`
  -- `map__omop_visit_type` maps exactly one local code, `admission`, to 9201 -- so, unlike
  the OPD sibling, there is no narrower-than-the-concept decision being made here: this
  metric already **is** the full 9201 definition. The string form is used (matching the OPD
  sibling's own style), for readability and consistency, not because the two forms would
  select different rows.

  **Concept 262 (`admission_from_emergency`) does not need special-casing.** 262 is applied
  only by `clinical__visit_occurrence`, at the whole-encounter grain, when an admission
  encounter's `encounter_history` shows a prior emergency/triage/observation phase (see
  `map__omop_visit_type`'s own comment and `clinical__visit_occurrence`'s BL-002). It is
  never assigned as a `clinical__visit_detail` segment's own `visit_detail_concept_id` --
  that model joins `map__omop_visit_type` on `local_code` directly, with no equivalent
  262-promotion logic (confirmed against `clinical__visit_detail.sql`). An `admission`
  segment's concept is always 9201, whatever the encounter as a whole resolves to. Filtering
  on `visit_detail_source_value = 'admission'` (or, equivalently, `visit_detail_concept_id
  = 9201`) at the segment level is therefore already correct and complete -- no additional
  262 branch is needed or possible at this grain.

  **The mechanism -- an as-of join, not the encounter's current type.** Identical to
  `metric__opd_imaging_request` BL-003: the latest `clinical__visit_detail` row for the
  request's encounter whose `visit_detail_start_datetime` is at or before the request's own
  timestamp, tie-broken on `visit_detail_id` descending on a same-instant tie. Segment-grain,
  not encounter-grain -- an imaging request raised while a patient's encounter segment is
  still coded `admission`, before or after some other segment, is scoped correctly regardless
  of what the encounter's segments are at other times.

- **BL-004 (request time, not completion time; first-segment clamp):** identical to
  `metric__opd_imaging_request` BL-004. The as-of join is evaluated at `requested_date`, not
  a completion timestamp, so a `pending`/`in_progress`/`cancelled` request (no completion
  event) still resolves to a segment. Clamped to the first segment when the request predates
  every segment -- a data-timing artifact (the segment's own recorded start is late), not a
  real ordering issue; the request still genuinely belongs to that encounter. Every
  encounter has at least one segment (`clinical__visit_detail` BL-005), so the join carries
  no timestamp condition and can never drop a row.

- **BL-005 (facility attribution -- the admission segment's own location, not the request's
  `location_group_id`):** identical mechanism to `metric__opd_imaging_request` BL-005.
  `facility_id` is resolved through `bases/locations` on the `clinical__visit_detail`
  segment active at the request's own time -- the same segment BL-003 finds for
  admission-scoping -- via that segment's own `care_site_id`. Not
  `imaging_requests.location_id` (deprecated in Tamanu and effectively unpopulated for the
  imaging branch -- see `clinical__procedure_occurrence`'s header comment), and not the
  request's own `location_group_id` -- the same real zero-row failure mode
  `metric__opd_imaging_request`'s own BL-005 documents and fixed, avoided here from the
  outset.

  The join to `locations` is still **inner**: an admission segment whose own `care_site_id`
  doesn't resolve to a facility is excluded rather than attributed to a NULL one -- the same
  "excluded rather than guessed" convention `metric__opd_imaging_request` uses.

- **BL-006 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the shared `metrics:` block in `dbt_project.yml` --
  no new config needed for this model.

- **BL-007 (modality as name and code; area emitted raw):** identical to
  `metric__opd_imaging_request` BL-007 -- `imaging_type`/`imaging_type_code` as readable
  label and raw code, `imaging_area` as a comma-joined, alphabetically ordered list of
  body-part names from `imaging_request_areas` -> `reference_data.name`, falling back to the
  legacy free-text note. None of the three is ever NULL.

- **BL-008 (age is the consumer's to band):** `age_years` is age in whole years at the
  request date, emitted raw and unbanded -- a measure, not a dimension, matching
  `metric__opd_imaging_request` BL-008.

- **BL-010 (sourced from the clinical layer, not `bases/imaging_requests` directly):**
  identical to `metric__opd_imaging_request` BL-010 -- reads
  `clinical__procedure_occurrence`, filtered to `procedure_type_source_value = 'imaging
  request'`. `deleted`/`entered_in_error` requests are excluded upstream; this model does not
  re-filter status. Only `is_completed` (boolean) is carried, not the full four-value
  `status`, so `cancelled` and still-open requests remain indistinguishable here -- same
  accepted gap as the OPD sibling (OQ-002).

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__ipd_imaging_request_grain`) |
| AC | `metric_id` is `not_null` and always `ipd_imaging_request` | BL-002 | `not_null` + `accepted_values` |
| AC | Every `metric_id` exists in `metric_definitions.metric_id` | BL-002 | `relationships` (`error`) |
| AC | `period_start` is `not_null` | BL-002 | `not_null` |
| AC | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC | `value_numeric` is `not_null` and always `1` | BL-001 | `not_null` + `accepted_values` |
| AC | `facility_id` is `not_null` | BL-005 | `not_null` |
| AC | `subject_id` is `not_null` | grain | `not_null` |
| AC | `is_completed` is `not_null` | BL-010 | `not_null` |
| AC | `imaging_type` is `not_null` | BL-007 | `not_null` |
| AC | `imaging_type_code` is `not_null` | BL-007 | `not_null` |
| AC | `imaging_area` is `not_null` | BL-007 | `not_null` |
| AC | `period_end` is populated only where `is_completed` | BL-002 | `dbt_utils.expression_is_true` |
| AC | The as-of join: tie-break on `visit_detail_id`, `admission`-only scoping, a pending/cancelled request (no completion event) still resolves via `requested_date`, and a request predating every segment clamps to the first segment | BL-003, BL-004 | Covered by the same as-of-join mechanism `metric__opd_imaging_request`'s own dbt unit test exercises; no separate unit test added for this metric, since the mechanism is unchanged and only the scoped `encounter_type` literal differs |

Test names are unnumbered (`ac_metric__ipd_imaging_request_<column>_<check>`), matching
`metric__opd_imaging_request.yml`'s convention.

## Registry entry

One active row -- `ipd_imaging_request`, `kind: metric`, `subject_grain: imaging_request`,
`status: draft`, `spec_path` pointing here, with `disaggregations:
facility_id,sex,is_completed,imaging_type,imaging_type_code,imaging_area` -- identical
disaggregation list to `metric__opd_imaging_request`.

All disaggregations are already admitted to the allowlist in
`assert__metric_definitions__disaggregations` by `metric__opd_imaging_request` and
`metric__procedure`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical/` | The request itself, via its imaging branch: identity, timestamp, modality, completion flag, grain anchor (BL-002, BL-007, BL-010) |
| `imaging_results` | `bases/` | Completion timestamp, `min(datetime)` per request (BL-002) |
| `imaging_request_areas` | `bases/` | Structured body-area links (BL-007) |
| `reference_data` | `bases/` | Area names for `imaging_request_areas.area_id` (BL-007) |
| `notes` | `bases/` | Legacy free-text area fallback (BL-007) |
| `clinical__visit_detail` | `clinical/` | Inpatient scope and facility: the segment active at the request's own timestamp, and its own `care_site_id` (BL-003, BL-004, BL-005) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-008) |
| `locations` | `bases/` | Facility id of the active segment's own `care_site_id` (BL-005) |
| `metric_definitions` | root | Registry; `metric_id` FK target |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Not yet built as of this spec (MAUI-6806) |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   minute-resolution timestamps, so a monthly card applies its own month bucketing and
   filters the current month itself.
3. **Not rely on `is_completed` to mean "not cancelled."** A cancelled request and a still
   `pending`/`in_progress` one are both `is_completed = false` (BL-010) -- this column
   answers "did it finish," not "is it still active."
4. **Compute turnaround time itself, if needed.** Not emitted as of this change -- both
   `period_start` and `period_end` remain on the model.
5. **Read BL-003 before reconciling against `metric__imaging_request`.** Both are
   segment/encounter-grain OMOP-scoped decisions, but this metric's segment-precise
   `admission` scope and `metric__imaging_request`'s encounter-grain `encounter_type`
   filter need not agree for an encounter whose segments span more than one type. A
   mismatch is expected, not a bug -- same caveat `metric__opd_imaging_request` gives
   against `opd_visit`/`opd_procedure`.
6. **Band `age_years` and/or group `imaging_type` itself**, if wanted -- neither is emitted
   here.

## Related

| Artefact | Relationship |
|---|---|
| `metric__opd_imaging_request` | Same as-of-segment pattern and mechanism, scoped to `clinic` instead of `admission` -- the reference this model was built from. Unlike this model, the OPD sibling's scope is narrower than its OMOP concept (9202); this model's scope already is the full 9201 concept (BL-003) |
| `metric__imaging_request` | The general, all-settings sibling with no as-of segment join -- `encounter_type` there is the encounter's own whole-visit type, a disaggregation rather than a restriction |
| `metric__opd_procedure` | The as-of-segment pattern both imaging-request siblings were built from |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

- **OQ-001:** Should a coarser AIHW-aligned modality grouping (Ultrasound/CT/X-ray/Nuclear
  medicine/MRI) be added as a data-table-layer derived column in `tupaia-data-product`,
  alongside the raw `imaging_type`? Same open question as `metric__opd_imaging_request`'s
  OQ-002.
- **OQ-002:** Should the full `pending`/`in_progress`/`completed`/`cancelled` status
  lifecycle be reintroduced as a disaggregation, once a consumer needs the completed-vs-
  cancelled split BL-010 currently gives up? Same open question as
  `metric__opd_imaging_request`'s OQ-004.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-11 | @gagank16 | Initial draft (MAUI-6806) -- inpatient counterpart to metric__opd_imaging_request, built alongside metric__imaging_request |

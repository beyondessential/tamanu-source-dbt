# dbt Model Spec: `metric__opd_imaging_request` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__opd_imaging_request` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-006) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6806 |

Canonical definition for `opd_imaging_request`: one row per imaging request raised while the
patient was in a **clinic** encounter. Sits beside `metric__outpatient_visit` (`opd_visit`)
and `metric__opd_procedure` in the outpatient product, modelled directly on
`metric__opd_procedure`'s as-of-segment pattern -- with one deliberate departure from it,
covered in full in BL-003 and BL-004.

## Purpose

Diagnostic imaging requests raised during outpatient clinic care, one row per request.

| `metric_id` | Unit | Measures |
|---|---|---|
| `opd_imaging_request` | count | Imaging requests raised during a clinic encounter (always 1 per row) |

**Why a separate metric, not a filter.** Following `metric__opd_procedure`'s precedent
(itself a decision, MAUI-6862): outpatient imaging is kept apart as its own metric rather
than exposing `encounter_type` as a disaggregation on a general "all-settings" imaging
metric. No such general metric exists yet in this repo; `opd_imaging_request` is the first.

**Why `clinic` only, not the full OMOP 9202 (BL-003 in short).** `opd_visit` and
`opd_procedure` both scope "outpatient" to OMOP concept 9202, which covers `clinic`,
`imaging`, and `vaccination` encounter types alike (`map__omop_visit_type`). This metric
scopes to `clinic` only, by decision (MAUI-6806) -- see BL-003 for the reasoning and for
what is deliberately left out of scope by this choice.

**Answers one of three standing questions about outpatient imaging today:**

1. **By modality / area** -- `imaging_type` and `imaging_area`.
2. **Turnaround time** -- not currently surfaced. Out of scope for the current visual; the
   request-to-completion duration can be computed later from `period_start`/`period_end` if
   a consumer needs it (both remain on the model).
3. **Completed vs cancelled** -- not currently surfaced. `is_completed` (BL-010) cannot tell a
   cancelled request apart from one still pending/in progress. The current consumer does not
   need this split; see BL-010 and OQ-004 for the tradeoff and how to reintroduce it later.

**Who reads it.** The Tupaia outpatient department dashboard, via a data table over this
view in `tupaia-data-product`, once built (MAUI-6806).

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of imaging requests scoped to the outpatient clinic setting -- no external body registers this indicator |

No AIHW METeOR element is registered. AIHW's own diagnostic-imaging reporting (Medicare
Benefits Schedule-based) explicitly names request completion, cancellation, turnaround
time, and body-area breakdown as gaps it cannot report -- MBS data was not designed to
carry them. This metric is a BES composition over Tamanu's own `imaging_requests` object,
`definition_source: BES`, the same status `metric__procedure`/`metric__opd_procedure`
carry.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC at `error` severity -- a
duplicate would double-count a request in any consumer that sums `value_numeric`.

`subject_id` is the imaging request's own id, read as `clinical__procedure_occurrence`'s
`procedure_occurrence_id` (unchanged from `imaging_requests.id`, BL-010), matching the
registry's `subject_grain: imaging_request`. Like `opd_procedure`, there is no
encounter-segment stitching to find the subject itself -- one row per request already.
Segment logic here (BL-003) decides *inclusion and scope*, not identity.

## Output schema

D5 wide format, plus six disaggregation columns and one measure attribute.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `opd_imaging_request`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Imaging request id. `not_null` |
| `period_start` | timestamp | Request raised (BL-002) |
| `period_end` | timestamp | Marked complete. NULL while pending, in progress, or cancelled (BL-002) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The active clinic segment's own location's facility (BL-005). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | `clinical__procedure_occurrence`'s completion flag (BL-010). Never NULL. Does not distinguish `cancelled` from `pending`/`in_progress` |
| `imaging_type` | text | Readable modality label, falling back to `imaging_type_code` then `'Not recorded'` (BL-007). Never NULL |
| `imaging_type_code` | text | Tamanu's raw imaging-type value, or `'Not recorded'` (BL-007). Never NULL |
| `imaging_area` | text | Comma-joined body area/study area, or `'Not recorded'` (BL-007). Never NULL |
| `age_years` | integer | Age in whole years at the request, unbanded (BL-008). A measure, not a dimension |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention `metric__outpatient_visit` and
`metric__opd_procedure` use -- filter types, aggregation and any bands are the consumer's
vocabulary, not dbt's. This model therefore carries no `data_table_*` meta. Not yet built
as of this spec.

## Business logic

- **BL-001 (a dedicated metric, not a filter):** matches `metric__opd_procedure` BL-001 --
  kept apart from every other setting as its own metric, rather than mixed with them behind
  an `encounter_type` filter on a general metric. No general (all-settings) imaging metric
  exists in this repo to filter, so this is also the first imaging metric of any kind.

- **BL-002 (reporting period and status):** `period_start` is
  `clinical__procedure_occurrence.procedure_datetime` (Tamanu's imaging-request `datetime`,
  unchanged by BL-010). `period_end` is the completion timestamp -- `min(imaging_results.datetime)`
  for the request, the same rule `macros/datasets/imaging_requests.sql` uses for
  `ds__imaging_requests.completed_datetime` -- gated on `is_completed`, not surfaced merely
  because a matching `imaging_results` row exists: a preliminary or otherwise-stray result
  row can exist against a request that isn't (or is no longer) `completed`, and this model
  has no raw status to check against (BL-010), so it checks the boolean flag instead. This is
  **not** the same as `opd_procedure`'s hardcoded-NULL `period_end`: unlike a procedure, an
  imaging request has a real completion event worth reporting, so this metric emits it rather
  than omitting it.

  **`period_end` is left as recorded, unguarded against a completion before the request.**
  Confirmed against a real replica: at least one request has an `imaging_results` timestamp
  earlier than its own `requested_date` -- a data anomaly (mis-entered or backdated), not a
  genuine negative duration. The AC checking `period_end` is at or after `period_start` is a
  `warn`-severity data-quality check on real data, not a hard invariant this model enforces
  by rewriting Tamanu's own timestamps.

  Rows whose Tamanu status is `'deleted'` or `'entered_in_error'` are excluded entirely, the
  same treatment as a soft-deleted row -- this happens upstream, in
  `clinical__procedure_occurrence`'s own BL-002, not re-filtered here (BL-010).

- **BL-003 (outpatient scope: `clinic` only, not OMOP 9202 in full -- decision, MAUI-6806):**
  a request is included when the `clinical__visit_detail` segment active at its own
  `requested_date` has `visit_detail_source_value = 'clinic'` -- **not**
  `visit_detail_concept_id = 9202`, the concept `opd_visit`/`opd_procedure` filter on, which
  also admits `imaging` and `vaccination` encounter types.

  **Why narrower than the sibling metrics.** `encounter_type = 'imaging'` and
  `imaging_requests` are two independent Tamanu concepts that happen to share a name: the
  former is a property of the *encounter* (the whole visit was coded as an imaging-department
  attendance), the latter is an *order* placed during any encounter, of any type, with no
  relationship to the encounter's own type. `ImagingRequest.create` never reads or sets
  `encounter.encounterType` (confirmed against the Tamanu application source -- its
  `afterCreateHook`/`afterUpdateHook` only handle invoicing and notifications). Including
  `imaging`-typed encounters would have folded a second, structurally different question
  ("how much imaging happens on visits whose whole purpose was imaging") into a metric meant
  to answer "how much imaging does routine outpatient clinic care generate" -- kept separate,
  by decision, pending product input on whether `imaging`-typed encounters should be folded
  in later (OQ-001). `vaccination` is excluded for the same reason, though it is expected to
  contribute ~0 rows in practice.

  **The mechanism -- an as-of join, not the encounter's current type.** The active segment
  is found the same way `metric__opd_procedure` BL-003 finds one for a procedure: the latest
  `clinical__visit_detail` row for the request's encounter whose `visit_detail_start_datetime`
  is at or before the request's own timestamp, tied-broken on `visit_detail_id` descending on
  a same-instant tie. This is segment-grain, not encounter-grain -- an imaging request raised
  while a patient's encounter is still coded `clinic`, before a later admission or ED
  transfer, is scoped correctly regardless of what the encounter becomes afterward.

- **BL-004 (request time, not completion time -- departure from `opd_procedure`'s literal
  pattern):** the as-of join is evaluated at `requested_date`, not at the completion
  timestamp `opd_procedure` uses (`procedure_datetime` -- procedures only have one
  timestamp). Imaging has two, and only one is always populated: a `pending`, `in_progress`,
  or `cancelled` request has no completion event at all. Anchoring on completion time would
  silently exclude every such request from the as-of join (no timestamp to test against a
  segment), which would gut the "completed vs cancelled" comparison this metric exists to
  answer -- request time is available for every request, completed or not, so that is what
  the segment lookup uses.

- **BL-005 (facility attribution -- the clinic segment's own location, not the request's
  `location_group_id`):** `facility_id` is resolved through `bases/locations` on the
  `clinical__visit_detail` segment active at the request's own time -- the same segment
  BL-003 finds for clinic-scoping -- via that segment's own `care_site_id`. Not
  `imaging_requests.location_group_id`, and not `imaging_requests.location_id` the way
  `metric__opd_procedure` resolves facility from `procedures.location_id`.

  This replaced an earlier design that resolved facility from the request's own
  `location_group_id` via `bases/location_groups`. Confirmed against a real replica: none of
  that replica's `clinic`-scoped imaging requests had `location_group_id` populated, so the
  inner join to `location_groups` silently excluded every one of them -- the model built and
  every test passed, vacuously, against a result set with zero rows. The active segment's own
  `care_site_id` resolves facility for every one of those same rows, and BL-003 already
  computes that segment for clinic-scoping, so no join beyond `bases/locations` is needed.

  The join to `locations` is still **inner**: a clinic segment whose own `care_site_id`
  doesn't resolve to a facility is excluded rather than attributed to a NULL one -- the same
  "excluded rather than guessed" convention `metric__opd_procedure` uses for its own location
  join.

- **BL-006 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the shared `metrics:` block in `dbt_project.yml` --
  no new config needed for this model.

- **BL-007 (modality as name and code; area emitted raw):** `imaging_type` is the readable
  modality label and `imaging_type_code` is Tamanu's raw enum value underneath it -- the same
  name/code pair `metric__procedure` emits as `procedure`/`procedure_code`, so a card can rank
  by the readable label while still scoping to one modality by a code that survives a label
  change. `imaging_type` falls back to `imaging_type_code`, then `'Not recorded'`;
  `imaging_type_code` falls back to `'Not recorded'` directly -- neither is ever NULL, since
  Tupaia's array filter drops a NULL row. `imaging_area` is a comma-joined, alphabetically
  ordered list of body-part names from `imaging_request_areas` -> `reference_data.name`,
  falling back to the legacy free-text note (`notes` where `record_type = 'ImagingRequest'`
  and `note_type = 'areaToBeImaged'`) -- the identical rule
  `macros/datasets/imaging_requests.sql` uses for `ds__imaging_requests.imaging_area`.
  `imaging_area` is not grouped into any coarser classification (e.g. AIHW's five-category
  modality taxonomy) -- the same "emit as recorded" discipline `morbidity`'s
  `diagnosis`/`diagnosis_code` applies, since a deployment's own coding may not support a
  meaningful rollup.

- **BL-008 (age is the consumer's to band):** `age_years` is age in whole years at the
  request date (`{{ age_years(...) }}`), emitted raw and unbanded -- a measure, not a
  dimension, the same reasoning `metric__opd_procedure` BL-007 gives.

- **BL-010 (sourced from the clinical layer, not `bases/imaging_requests` directly):** this
  model reads `clinical__procedure_occurrence`, filtered to
  `procedure_type_source_value = 'imaging request'`, for the request's identity, timestamp,
  and modality -- the same clinical layer `metric__procedure`/`metric__opd_procedure` build
  on, rather than `bases/imaging_requests` directly. `procedure_occurrence_id` is
  `imaging_requests.id` unchanged, so the remaining `bases/`-level joins (`imaging_results`
  for completion, `imaging_request_areas`/`notes` for area) key on it exactly as before.
  `deleted`/`entered_in_error` requests are excluded upstream, by
  `clinical__procedure_occurrence`'s own BL-002, so this model does not re-filter status.

  **Cost: no full status lifecycle.** The clinical model carries only `is_completed`
  (boolean), not Tamanu's four-value `status`. `cancelled` and still-open
  (`pending`/`in_progress`) requests are therefore indistinguishable here -- both
  `is_completed = false`. The completed-vs-cancelled question named in § Purpose is not
  answered by this column; the current consumer does not disaggregate by status, so this is
  an accepted gap rather than an oversight (OQ-004). A future consumer needing that
  distinction reads `bases/imaging_requests.status` directly, the way this model did before
  this change.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__opd_imaging_request_grain`) |
| AC | `metric_id` is `not_null` and always `opd_imaging_request` | BL-002 | `not_null` + `accepted_values` |
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
| AC | The as-of join: tie-break on `visit_detail_id`, `clinic`-only scoping, and a pending/cancelled request (no completion event) still resolves via `requested_date` | BL-003, BL-004 | dbt unit test `test_metric__opd_imaging_request_segment_attribution` |

Test names are unnumbered (`ac_metric__opd_imaging_request_<column>_<check>`), matching
`metric__opd_procedure.yml`'s convention.

## Registry entry

One active row -- `opd_imaging_request`, `kind: metric`, `subject_grain: imaging_request`,
`status: draft`, `spec_path` pointing here, with `disaggregations:
facility_id,sex,is_completed,imaging_type,imaging_type_code,imaging_area`.

`imaging_type`, `imaging_type_code`, `imaging_area` are new to the allowlist in
`assert__metric_definitions__disaggregations`; `is_completed` is already admitted
(`metric__procedure`'s completion flag), and `facility_id`/`sex` are already admitted by
earlier metrics.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical/` | The request itself, via its imaging branch: identity, timestamp, modality, completion flag, grain anchor (BL-002, BL-007, BL-010) |
| `imaging_results` | `bases/` | Completion timestamp, `min(datetime)` per request (BL-002) |
| `imaging_request_areas` | `bases/` | Structured body-area links (BL-007) |
| `reference_data` | `bases/` | Area names for `imaging_request_areas.area_id` (BL-007) |
| `notes` | `bases/` | Legacy free-text area fallback (BL-007) |
| `clinical__visit_detail` | `clinical/` | Outpatient scope and facility: the segment active at the request's own timestamp, and its own `care_site_id` (BL-003, BL-004, BL-005) |
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
   `period_start` and `period_end` remain on the model, so a consumer can derive it, keeping
   the same "only for a completed request" gate `period_end` already applies (BL-002).
5. **Read BL-003 before reconciling against `opd_visit`/`opd_procedure`.** All three are
   segment-grain, OMOP-scoped decisions, but neither the segment point nor the scope itself
   match exactly -- `opd_visit` uses the encounter's *first* segment at 9202,
   `opd_procedure` the segment active at the procedure's *own* time at 9202, this metric
   the segment active at the request's own time at `clinic` only (narrower than 9202). A
   mismatch between this metric's count and either sibling's is expected, not a bug.
6. **Band `age_years` and/or group `imaging_type` itself**, if wanted -- neither is emitted
   here.

## Related

| Artefact | Relationship |
|---|---|
| `metric__opd_procedure` | Same as-of-segment pattern and OPD-scoping decision -- the reference this model was built from, anchored on request time instead of a single procedure timestamp (BL-004), scoped to `clinic` only instead of full OMOP 9202 (BL-003), and resolving facility from the active segment's own location rather than the procedure's own `location_id` (BL-005) |
| `metric__outpatient_visit` | Sibling metric in the outpatient product; broader OMOP 9202 definition, encounter-first-segment grain |
| `ds__imaging_requests` | Report-layer imaging dataset at request grain, with PII -- this model's `imaging_area`/completion-time rules reproduce its own, but its facility comes from the encounter's flat `location_id` rather than the as-of segment (BL-005) -- the two can disagree for a patient who moved location during the encounter |
| `imaging-requests-summary.sql` | Existing report computing a similar pending/completed funnel, but excluding cancelled entirely -- this metric's BL-002 explicitly departs from that exclusion |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

- **OQ-001:** Should `imaging`-typed encounters (and/or `vaccination`) be folded into this
  metric's scope later, moving it from `clinic`-only to the full OMOP 9202 definition
  `opd_visit`/`opd_procedure` use? Decided narrow for now (MAUI-6806); revisit once it's
  clear how much imaging activity, if any, the excluded encounter types actually carry at a
  real deployment.
- **OQ-002:** Should a coarser AIHW-aligned modality grouping (Ultrasound/CT/X-ray/Nuclear
  medicine/MRI) be added as a data-table-layer derived column in `tupaia-data-product`,
  alongside the raw `imaging_type`?
- **OQ-003:** Should `reason_for_cancellation` (already captured in `bases/imaging_requests`)
  be added as a sixth disaggregation, to answer *why* requests are cancelled?
- **OQ-004:** Should the full `pending`/`in_progress`/`completed`/`cancelled` status
  lifecycle be reintroduced as a disaggregation, once a consumer needs the completed-vs-
  cancelled split BL-010 currently gives up? Would mean rejoining
  `bases/imaging_requests.status` directly, alongside `clinical__procedure_occurrence`.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-03 | @gagank16 | Initial draft (MAUI-6806) |
| 2026-09-09 | @gagank16 | Sourced from clinical__procedure_occurrence instead of bases/imaging_requests directly (BL-010); facility resolved via the active segment's own location instead of the request's location_group_id, fixing a real zero-row bug (BL-005); status narrowed to is_completed, dropping the completed-vs-cancelled split for now (OQ-004); period_end gated on is_completed rather than surfaced merely because a result row exists, fixing a real correctness bug (BL-002); age_years switched to the already-available procedure_date column instead of re-casting procedure_datetime; removed turnaround_time__minutes, not needed by the current visual -- period_start/period_end remain, so it can be computed later if needed; added imaging_type as a readable label alongside the existing raw value, renamed to imaging_type_code (BL-007) |

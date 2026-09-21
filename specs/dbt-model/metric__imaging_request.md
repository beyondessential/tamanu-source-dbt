# dbt Model Spec: `metric__imaging_request` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__imaging_request` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-006) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6806 |

Canonical definition for `imaging_request`: one row per imaging request, in any encounter
setting. The direct imaging-request counterpart to `metric__procedure` -- modelled on its
setting-scoping pattern (`encounter_type` is the encounter's own whole-visit type, a
disaggregation rather than a restriction), the way `metric__opd_imaging_request` was
modelled on `metric__opd_procedure`'s as-of-segment pattern. This is the first
all-settings imaging metric in the repo; the two segment-precise siblings,
`metric__opd_imaging_request` (`clinic` only) and `metric__ipd_imaging_request`
(`admission` only), already existed or were built alongside this one.

## Purpose

Diagnostic imaging requests raised in any Tamanu encounter setting, one row per request.

| `metric_id` | Unit | Measures |
|---|---|---|
| `imaging_request` | count | Imaging requests raised in any encounter setting (always 1 per row) |

**Not segment-precise, by design.** `encounter_type` here is
`clinical__visit_occurrence.visit_source_value` -- the encounter's own whole-visit type --
not the `clinical__visit_detail` segment active at the request's own timestamp. A request
raised early in an encounter that is later reclassified (e.g. triage escalating to
admission) is tagged with the encounter's final type, not the type in effect at the moment
of the request. This mirrors exactly how `metric__procedure.encounter_type` already
behaves; a consumer wanting the segment-precise answer for the two settings that matter
today reads `metric__opd_imaging_request`/`metric__ipd_imaging_request` instead.

**Answers the same three standing questions about imaging as the OPD sibling, but
unscoped:**

1. **By modality / area** -- `imaging_type` and `imaging_area`.
2. **By setting** -- `encounter_type`, new to this metric (absent from the OPD-scoped
   sibling, which is already fixed to one setting).
3. **Turnaround time** -- not currently surfaced, same as the OPD sibling. Computable later
   from `period_start`/`period_end`.

**Who reads it.** Any Tupaia dashboard needing imaging-request volume across every
setting, or split by setting, via a data table over this view in `tupaia-data-product`, once
built.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of imaging requests in any encounter setting -- no external body registers this indicator |

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
`procedure_occurrence_id` (unchanged from `imaging_requests.id`), matching the registry's
`subject_grain: imaging_request`. As with the OPD/IPD siblings, there is no encounter-segment
stitching to find the subject itself -- one row per request already; encounter-type
attribution here decides *disaggregation*, not identity.

## Output schema

D5 wide format, plus seven disaggregation columns and one measure attribute -- one more
disaggregation (`encounter_type`) than `metric__opd_imaging_request`/
`metric__ipd_imaging_request` carry, since those are already scoped to a single setting.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `imaging_request`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Imaging request id. `not_null` |
| `period_start` | timestamp | Request raised (BL-002) |
| `period_end` | timestamp | Marked complete. NULL while pending, in progress, or cancelled (BL-002) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The encounter's own location's facility (BL-005). `not_null` |
| `encounter_type` | varchar(255) | The encounter's own whole-visit type (BL-003). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | `clinical__procedure_occurrence`'s completion flag. Never NULL. Does not distinguish `cancelled` from `pending`/`in_progress` |
| `imaging_type` | text | Readable modality label, falling back to `imaging_type_code` then `'Not recorded'` (BL-007). Never NULL |
| `imaging_type_code` | text | Tamanu's raw imaging-type value, or `'Not recorded'` (BL-007). Never NULL |
| `imaging_area` | text | Comma-joined body area/study area, or `'Not recorded'` (BL-007). Never NULL |
| `age_years` | integer | Age in whole years at the request, unbanded (BL-008). A measure, not a dimension |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention `metric__procedure` and
`metric__opd_imaging_request` use. This model therefore carries no `data_table_*` meta. Not
yet built as of this spec.

## Business logic

- **BL-001 (a general metric, disaggregated by setting rather than a metric per
  setting):** matches `metric__procedure` BL-... reasoning -- rather than one metric per
  encounter setting, `encounter_type` is emitted as a disaggregation so a consumer filters
  to one setting (or none) from this single view. `metric__opd_imaging_request` and
  `metric__ipd_imaging_request` continue to exist alongside this metric because they answer
  a genuinely different question (segment-precise attribution, and for the OPD one a
  narrower-than-9202 scope), not because this metric is incomplete without them.

- **BL-002 (reporting period and status):** identical to `metric__opd_imaging_request`
  BL-002. `period_start` is `clinical__procedure_occurrence.procedure_datetime`. `period_end`
  is the completion timestamp -- `min(imaging_results.datetime)` for the request -- gated on
  `is_completed`, not surfaced merely because a matching `imaging_results` row exists.
  `period_end` is left as recorded, unguarded against a completion timestamp before the
  request (a real, if rare, data anomaly on a live replica; the AC checking `period_end >=
  period_start` is `warn`-severity data quality, not a hard invariant this model enforces).
  Rows whose Tamanu status is `deleted` or `entered_in_error` are excluded upstream, in
  `clinical__procedure_occurrence`'s own BL-002, not re-filtered here (BL-010).

- **BL-003 (encounter-grain scoping, not segment-grain -- `encounter_type` is the whole
  visit's own type):** unlike `metric__opd_imaging_request`/`metric__ipd_imaging_request`,
  this metric applies no as-of `clinical__visit_detail` segment join at all.
  `encounter_type` is read straight from `clinical__visit_occurrence.visit_source_value` --
  the encounter's own type, joined directly on `visit_occurrence_id` -- the identical
  pattern `metric__procedure.encounter_type` already uses. This is a deliberate
  simplification, not an oversight: this metric's purpose is "how much imaging activity
  happens, disaggregated by what kind of visit it happened on," a question the encounter's
  own type answers perfectly well; segment-precise attribution is what the OPD/IPD-scoped
  siblings exist for. The inner join to `clinical__visit_occurrence` means a request whose
  encounter type is not covered by `map__omop_visit_type` is dropped rather than surfaced
  with a NULL `encounter_type` -- the same tradeoff `metric__procedure` accepts.

- **BL-004 (n/a -- no as-of join to clamp):** `metric__opd_imaging_request`'s BL-004 (the
  first-segment clamp for a request predating its encounter's earliest segment) does not
  apply here -- there is no segment join to clamp, by BL-003.

- **BL-005 (facility attribution -- the encounter's own location, not the request's own
  `location_id`):** `facility_id` is resolved through `bases/locations` on
  `clinical__visit_occurrence.care_site_id` (`encounters.location_id`), joined on the same
  `visit_occurrence_id` used for `encounter_type` (BL-003). **Not**
  `clinical__procedure_occurrence.location_id` the way `metric__procedure` resolves facility
  for the procedure branch -- for the imaging branch specifically, that column is
  `imaging_requests.location_id`, which the clinical model's own header comment documents as
  "deprecated in Tamanu and effectively unpopulated." Joining it the way `metric__procedure`
  does would silently exclude nearly every row via the inner join to `locations` -- the same
  class of real zero-row bug `metric__opd_imaging_request`'s own BL-005 found and fixed
  (there, against `location_group_id`) before this metric was built, so it is avoided here
  from the outset rather than discovered against a replica a second time.

  The join to `locations` is still **inner**: an encounter whose own `care_site_id` doesn't
  resolve to a facility is excluded rather than attributed to a NULL one -- the same
  "excluded rather than guessed" convention `metric__procedure` and
  `metric__opd_imaging_request` both use for their own location joins.

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
  re-filter status. The clinical model carries only `is_completed` (boolean), not Tamanu's
  four-value `status`, so `cancelled` and still-open requests remain indistinguishable here,
  same accepted gap as the OPD sibling.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__imaging_request_grain`) |
| AC | `metric_id` is `not_null` and always `imaging_request` | BL-002 | `not_null` + `accepted_values` |
| AC | Every `metric_id` exists in `metric_definitions.metric_id` | BL-002 | `relationships` (`error`) |
| AC | `period_start` is `not_null` | BL-002 | `not_null` |
| AC | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC | `value_numeric` is `not_null` and always `1` | BL-001 | `not_null` + `accepted_values` |
| AC | `facility_id` is `not_null` | BL-005 | `not_null` |
| AC | `encounter_type` is `not_null` | BL-003 | `not_null` |
| AC | `subject_id` is `not_null` | grain | `not_null` |
| AC | `is_completed` is `not_null` | BL-010 | `not_null` |
| AC | `imaging_type` is `not_null` | BL-007 | `not_null` |
| AC | `imaging_type_code` is `not_null` | BL-007 | `not_null` |
| AC | `imaging_area` is `not_null` | BL-007 | `not_null` |
| AC | `period_end` is populated only where `is_completed` | BL-002 | `dbt_utils.expression_is_true` |

Test names are unnumbered (`ac_metric__imaging_request_<column>_<check>`), matching
`metric__opd_imaging_request.yml`'s convention.

## Registry entry

One active row -- `imaging_request`, `kind: metric`, `subject_grain: imaging_request`,
`status: draft`, `spec_path` pointing here, with `disaggregations:
facility_id,encounter_type,sex,is_completed,imaging_type,imaging_type_code,imaging_area`.

`encounter_type` is already admitted to the allowlist in
`assert__metric_definitions__disaggregations` (`metric__procedure`'s own setting
disaggregation); `imaging_type`, `imaging_type_code`, `imaging_area`, `is_completed`,
`facility_id`, `sex` are all already admitted by `metric__opd_imaging_request`/
`metric__procedure`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical/` | The request itself, via its imaging branch: identity, timestamp, modality, completion flag, grain anchor (BL-002, BL-007, BL-010) |
| `clinical__visit_occurrence` | `clinical/` | `encounter_type` disaggregation and facility: the encounter's own type and `care_site_id` (BL-003, BL-005) |
| `imaging_results` | `bases/` | Completion timestamp, `min(datetime)` per request (BL-002) |
| `imaging_request_areas` | `bases/` | Structured body-area links (BL-007) |
| `reference_data` | `bases/` | Area names for `imaging_request_areas.area_id` (BL-007) |
| `notes` | `bases/` | Legacy free-text area fallback (BL-007) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-008) |
| `locations` | `bases/` | Facility id of the encounter's own `care_site_id` (BL-005) |
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
3. **Not rely on `is_completed` to mean "not cancelled."** Same caveat as
   `metric__opd_imaging_request`.
4. **Filter `encounter_type` itself, if a single setting is wanted.** This metric does not
   pre-scope to any setting -- a consumer wanting "outpatient clinic imaging requests" can
   either filter this metric to `encounter_type = 'clinic'` (encounter-grain) or read
   `metric__opd_imaging_request` instead (segment-grain); the two are not guaranteed to
   agree for an encounter whose type changed mid-visit.
5. **Compute turnaround time itself, if needed.** Not emitted; both `period_start` and
   `period_end` remain on the model.
6. **Band `age_years` and/or group `imaging_type` itself**, if wanted -- neither is emitted
   here.

## Related

| Artefact | Relationship |
|---|---|
| `metric__procedure` | The reference pattern this model is built from: encounter-grain `encounter_type` disaggregation, no as-of segment join, no restriction on which encounters are included |
| `metric__opd_imaging_request` | Segment-precise, `clinic`-only sibling; shares this model's imaging-domain joins (completions, areas) but not its encounter-grain `encounter_type`/facility resolution |
| `metric__ipd_imaging_request` | Segment-precise, `admission`-only sibling; same relationship to this model as the OPD sibling |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

- **OQ-001:** Should a coarser AIHW-aligned modality grouping be added as a data-table-layer
  derived column in `tupaia-data-product`, alongside the raw `imaging_type`? Same open
  question as `metric__opd_imaging_request`'s OQ-002.
- **OQ-002:** Should the full `pending`/`in_progress`/`completed`/`cancelled` status
  lifecycle be reintroduced as a disaggregation? Same open question as
  `metric__opd_imaging_request`'s OQ-004.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-11 | @gagank16 | Initial draft (MAUI-6806) -- first all-settings imaging-request metric in the repo, built alongside metric__ipd_imaging_request |

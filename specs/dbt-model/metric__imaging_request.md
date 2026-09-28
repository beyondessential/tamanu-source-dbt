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
setting-scoping pattern, where `encounter_type` is a disaggregation rather than a
restriction. Outpatient imaging is `encounter_type = 'clinic'` and inpatient is
`'admission'`. Emergency imaging has its own metric, `metric__ed_imaging_request`, on OMOP
9203.

## Purpose

Diagnostic imaging requests raised in any Tamanu encounter setting, one row per request.

| `metric_id` | Unit | Measures |
|---|---|---|
| `imaging_request` | count | Imaging requests raised in any encounter setting (always 1 per row) |

**Attributed to the setting the request was raised in.** `encounter_type` is the
`clinical__visit_detail` segment active at the request's own timestamp, read off the
`visit_detail_id` that `clinical__procedure_occurrence` resolves (its BL-005) -- not the
encounter's whole-visit type. A request raised during triage on an encounter later admitted
reads as `triage`, not `admission`.

**Answers three standing questions about imaging, in any setting:**

1. **By modality / area** -- `imaging_type` and `imaging_area`.
2. **By setting** -- `encounter_type`, so a consumer scopes to one setting from this
   single view.
3. **Turnaround time** -- not currently surfaced. Computable later
   from `period_start`/`period_end`.

**Who reads it.** Any Tupaia dashboard needing imaging-request volume across every
setting, or split by setting, via a data table over this view in `tupaia-data-product`, once
built.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of imaging requests in any encounter setting -- no external body registers this indicator |

No AIHW METeOR element is registered: AIHW's own diagnostic-imaging reporting (Medicare Benefits Schedule-based)
does not report completion, cancellation, turnaround time, or body-area breakdown. This
metric is a BES composition over Tamanu's own `imaging_requests` object,
`definition_source: BES`, the same status `metric__procedure` carries.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC at `error` severity -- a
duplicate would double-count a request in any consumer that sums `value_numeric`.

`subject_id` is the imaging request's own id, read as `clinical__procedure_occurrence`'s
`procedure_occurrence_id` (unchanged from `imaging_requests.id`), matching the registry's
`subject_grain: imaging_request`. There is no encounter-segment
stitching to find the subject itself -- one row per request already; encounter-type
attribution here decides *disaggregation*, not identity.

## Output schema

D5 wide format, plus eight disaggregation columns and one measure attribute.
`encounter_type` is among them, since this metric applies no setting restriction.

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
| `facility_id` | varchar(255) | The resolved segment's own location's facility (BL-005). `not_null` |
| `encounter_type` | varchar(255) | The setting the request was raised in -- the resolved segment's own type (BL-003). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | `clinical__procedure_occurrence`'s completion flag. Never NULL. Does not distinguish `cancelled` from `pending`/`in_progress` |
| `imaging_type` | text | Readable modality label, falling back to `imaging_type_code` then `'Not recorded'` (BL-007). Never NULL |
| `imaging_type_code` | text | Tamanu's raw imaging-type value, or `'Not recorded'` (BL-007). Never NULL |
| `imaging_area` | text | Comma-joined body area/study area, or `'Not recorded'` (BL-007). Never NULL |
| `age_years` | integer | Age in whole years at the request, unbanded (BL-008). A measure, not a dimension |
| `department` | text | The department of the segment the request was raised in, resolved to a name (BL-011). Never NULL |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention `metric__procedure` uses. This model therefore carries no `data_table_*` meta. Not
yet built as of this spec.

## Business logic

- **BL-001 (a general metric, disaggregated by setting rather than a metric per
  setting):** `encounter_type` is emitted as a disaggregation, so a consumer filters to one
  setting, or none, from this single view. Outpatient imaging is `encounter_type = 'clinic'`
  -- narrower than OMOP 9202, which also admits `imaging`- and `vaccination`-typed
  encounters (MAUI-6806). Inpatient is `'admission'`. `metric__ed_imaging_request` reports
  the emergency phase over these same rows grouped as OMOP 9203, so it is a subset of this
  metric and the two are never summed.

- **BL-002 (reporting period and status):** `period_start` is `clinical__procedure_occurrence.procedure_datetime`. `period_end`
  is the completion timestamp -- `min(imaging_results.datetime)` for the request -- gated on
  `is_completed`, not surfaced merely because a matching `imaging_results` row exists.
  `period_end` is left as recorded, unguarded against a completion timestamp before the
  request (a real, if rare, data anomaly on a live replica; the AC checking `period_end >=
  period_start` is `warn`-severity data quality, not a hard invariant this model enforces).
  Rows whose Tamanu status is `deleted` or `entered_in_error` are excluded upstream, in
  `clinical__procedure_occurrence`'s own BL-002, not re-filtered here (BL-010).

- **BL-003 (the setting the request was raised in):** `encounter_type` is the
  `clinical__visit_detail` segment active at the request's own timestamp, reached through
  the `visit_detail_id` that `clinical__procedure_occurrence` resolves once for every
  procedure and imaging request (its BL-005). This model does not derive the segment itself:
  the as-of rule and the first-segment clamp live there, so every metric over that model
  agrees on which segment a request belongs to, and a fix to that rule reaches all of them
  through the FK.

  A request raised during triage on an encounter later admitted therefore reads as `triage`,
  not `admission` -- what was true when the request was raised, rather than what the
  encounter became. The inner join means a request whose segment did not resolve (a NULL FK,
  where the encounter's `encounter_type` is absent from `map__omop_visit_type`) is dropped
  rather than surfaced with a NULL `encounter_type` -- the same tradeoff `metric__procedure`
  accepts.

- **BL-004 (the clamp is upstream, and does not widen this metric):**
  `clinical__procedure_occurrence` clamps a request raised before its encounter's earliest
  segment onto that earliest segment, so it resolves rather than going unattributed (that
  model's BL-005). This metric applies no scope restriction, so the clamp only ever affects
  which `encounter_type`/`facility_id` such a request is attributed to, never whether it is
  counted.

- **BL-005 (facility attribution -- the segment's own location, not the request's own
  `location_id`):** `facility_id` is resolved through `bases/locations` on the resolved
  segment's `care_site_id`, the same source `metric__procedure` resolves facility from, so
  a procedure and an imaging request belonging to one segment agree on facility. **Not**
  `clinical__procedure_occurrence.location_id`, which for the imaging branch is
  `imaging_requests.location_id` -- documented in the clinical model's own header as
  "deprecated in Tamanu and effectively unpopulated", so an inner join to `locations` on it
  would silently exclude nearly every row.

  Because it comes from the segment rather than the encounter, `facility_id` is where the
  patient was when the request was raised, not wherever the encounter later ended up -- a
  patient transferred mid-encounter keeps each request attributed to the facility it was
  raised at.

  The join to `locations` is still **inner**: a segment whose `care_site_id` doesn't resolve
  to a facility is excluded rather than attributed to a NULL one -- the same "excluded rather
  than guessed" convention `metric__procedure` uses.

- **BL-006 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the shared `metrics:` block in `dbt_project.yml` --
  no new config needed for this model.

- **BL-007 (modality as name and code; area emitted raw):** `imaging_type`/`imaging_type_code` as readable
  label and raw code, `imaging_area` as a comma-joined, alphabetically ordered list of
  body-part names from `imaging_request_areas` -> `reference_data.name`, falling back to the
  legacy free-text note. Only the current revision of each note chain counts, ranked before
  the `note_type` filter since a revision can change a note's type, and ordered by
  `datetime` then `created_datetime` then `id` so a same-second tie gives a stable string.
  None of the three is ever NULL.

- **BL-008 (age is the consumer's to band):** `age_years` is age in whole years at the
  request date, emitted raw and unbanded -- a measure, not a dimension.

- **BL-010 (sourced from the clinical layer, not `bases/imaging_requests` directly):** reads
  `clinical__procedure_occurrence`, filtered to `procedure_type_source_value = 'imaging
  request'`. `deleted`/`entered_in_error` requests are excluded upstream; this model does not
  re-filter status. The clinical model carries only `is_completed` (boolean), not Tamanu's
  four-value `status`, so `cancelled` and still-open requests remain indistinguishable
  here.

- **BL-011 (department):** the resolved segment's own `department_id`, resolved to a name
  through `departments` so a consumer scopes to one department (e.g. Dental) via
  `metric_filters` on a readable value, the same convention modality identity (BL-007) uses
  rather than an opaque Tamanu id. `bases/locations` carries no `department_id`, so it comes
  off the segment directly. Never NULL -- falls back to `'Not recorded'`.

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
| AC | `department` is `not_null` | BL-011 | `not_null` |
| AC | `period_end` is populated only where `is_completed` | BL-002 | `dbt_utils.expression_is_true` |

Test names are unnumbered (`ac_metric__imaging_request_<column>_<check>`), matching
`metric__procedure.yml`'s convention.

## Registry entry

One active row -- `imaging_request`, `kind: metric`, `subject_grain: imaging_request`,
`status: draft`, `spec_path` pointing here, with `disaggregations:
facility_id,encounter_type,sex,is_completed,imaging_type,imaging_type_code,imaging_area,department`.

`encounter_type` is already admitted to the allowlist in
`assert__metric_definitions__disaggregations` (`metric__procedure`'s own setting
disaggregation); `imaging_type`, `imaging_type_code`, `imaging_area`, `is_completed`,
`facility_id`, `sex` are all already admitted by `metric__procedure`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical/` | The request itself, via its imaging branch: identity, timestamp, modality, completion flag, grain anchor (BL-002, BL-007, BL-010) |
| `clinical__visit_detail` | `clinical/` | `encounter_type`, facility and department: the resolved segment's own type, `care_site_id` and `department_id` (BL-003, BL-005, BL-011) |
| `imaging_results` | `bases/` | Completion timestamp, `min(datetime)` per request (BL-002) |
| `imaging_request_areas` | `bases/` | Structured body-area links (BL-007) |
| `reference_data` | `bases/` | Area names for `imaging_request_areas.area_id` (BL-007) |
| `notes` | `bases/` | Legacy free-text area fallback (BL-007) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-008) |
| `locations` | `bases/` | Facility id of the resolved segment's `care_site_id` (BL-005) |
| `departments` | `bases/` | Department name for the resolved segment (BL-011) |
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
3. **Not rely on `is_completed` to mean "not cancelled."** A cancelled request and a
   still-open one are both `false`, indistinguishable by this column alone.
4. **Filter `encounter_type` itself, if a single setting is wanted.** This metric does not
   pre-scope to any setting -- a consumer wanting outpatient clinic imaging requests
   filters `encounter_type = 'clinic'`, and inpatient `'admission'`.
5. **Compute turnaround time itself, if needed.** Not emitted; both `period_start` and
   `period_end` remain on the model.
6. **Band `age_years` and/or group `imaging_type` itself**, if wanted -- neither is emitted
   here.

## Related

| Artefact | Relationship |
|---|---|
| `metric__procedure` | The reference pattern this model is built from: `encounter_type` as a disaggregation rather than a restriction, read off the same resolved segment FK |
| `metric__ed_imaging_request` | Emergency imaging on OMOP 9203, sharing this model's imaging-domain joins (completions, areas) and reading the same resolved segment, restricted to one setting |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

- **OQ-001:** Should a coarser AIHW-aligned modality grouping be added as a data-table-layer
  derived column in `tupaia-data-product`, alongside the raw `imaging_type`?
- **OQ-002:** Should the full `pending`/`in_progress`/`completed`/`cancelled` status
  lifecycle be reintroduced as a disaggregation?

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-11 | @gagank16 | Initial draft (MAUI-6806) -- first all-settings imaging-request metric in the repo |
| 2026-09-28 | @gagank16 | Single imaging-request metric: the OPD and IPD scoped metrics retired behind an `encounter_type` filter, `department` added (MAUI-6909) |

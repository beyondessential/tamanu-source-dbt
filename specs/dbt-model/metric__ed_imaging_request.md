# dbt Model Spec: `metric__ed_imaging_request` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ed_imaging_request` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-006) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `ed_imaging_request`: one row per imaging request raised during the
emergency phase of an encounter. The emergency-side counterpart of
`metric__opd_imaging_request`, built from it directly -- same as-of-segment pattern, same
output shape, scoped to OMOP concept 9203 instead of the `clinic` source value.

## Purpose

Diagnostic imaging requests raised during emergency care, one row per request.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_imaging_request` | count | Imaging requests raised in an ED phase (always 1 per row) |

**Who reads it.** The Tupaia Emergency Department dashboard's imaging table (MAUI-6907), via a
data table over this view in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of imaging requests scoped to the emergency setting -- no external body registers this indicator |

No AIHW METeOR element is registered. AIHW's own diagnostic-imaging reporting (Medicare
Benefits Schedule-based) explicitly names request completion, cancellation, turnaround time and
body-area breakdown as gaps it cannot report. This is a BES composition over Tamanu's own
`imaging_requests` object, `definition_source: BES`, the same status
`metric__opd_imaging_request` carries.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a request in any consumer that sums `value_numeric`.

`subject_id` is the imaging request's own id, read as `clinical__procedure_occurrence`'s
`procedure_occurrence_id` (unchanged from `imaging_requests.id`, BL-010), matching the
registry's `subject_grain: imaging_request`. There is one row per request already; the segment
logic (BL-003) decides *inclusion*, not identity.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_imaging_request`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | The Tamanu imaging request id. `not_null` |
| `period_start` | timestamp | When the request was raised (BL-002) |
| `period_end` | timestamp | The completion time, NULL unless completed (BL-002) |
| `period_granularity` | text | Constant `'minute'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- unused by this metric |
| `facility_id` | varchar(255) | The qualifying segment's own location's facility (BL-005). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `is_completed` | boolean | Whether the request was marked complete (BL-010). Never NULL |
| `imaging_type_code` | text | Raw Tamanu modality value (BL-007). Never NULL |
| `imaging_type` | text | Readable modality label (BL-007). Never NULL |
| `imaging_area` | text | Aggregated body area (BL-007). Never NULL |
| `age_years` | integer | Age in whole years at the request, unbanded (BL-008). A measure, not a dimension |
| `department` | text | The qualifying segment's own department, resolved to a name (BL-011). Never NULL |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention every other `metric__` model in this project uses --
filter types, aggregation and any bands are the consumer's vocabulary, not dbt's. This model
therefore carries no `data_table_*` meta.

## Business logic

- **BL-001 (a dedicated metric, not a filter):** emergency imaging is its own metric rather
  than an `encounter_type` disaggregation on a general all-settings imaging metric, following
  `metric__opd_imaging_request`'s own precedent (MAUI-6806). It is also the only scoping that
  is correct here: `encounter_type` is the encounter's *current* type, so an attendance that
  began in the ED and was later admitted is retyped `admission` and would be dropped, while
  `metric__emergency_visit` counts it -- see `metric__ed_procedure` BL-001 for the same
  argument in full.

- **BL-002 (reporting period and status):** `period_start` is the request's own raised
  timestamp and `period_end` is the earliest recorded result, gated on `is_completed` -- an
  `imaging_results` row can exist against a still-open or cancelled request (a preliminary
  result entered before cancellation), so an ungated completion time would report a request as
  closed that is not. `period_granularity` is `'minute'`.

- **BL-003 (emergency scope: the segment active when the request was raised):** a request is
  included when the `clinical__visit_detail` segment it resolves to carries
  `visit_detail_concept_id = 9203` (OMOP 'Emergency Room Visit'), which covers the `emergency`,
  `triage` and `observation` phases (`map__omop_visit_type`) -- the same population
  `int__emergency_visits` takes its intake segment from.

  Scoped on the concept rather than on a single `visit_detail_source_value`, unlike the
  clinic-only opd counterpart: there, `clinic` had to be separated from the `imaging` and
  `vaccination` types that share OMOP 9202 (MAUI-6806), because an imaging-typed *encounter*
  and an imaging *request* are independent concepts. No such ambiguity exists at 9203 -- all
  three phases it covers are emergency care.

  **Boarding is the admission phase.** Once the encounter is retyped as an admission its segment
  is 9201, even while the patient is still in the ED awaiting a bed. A request raised then is not
  counted here, and no all-settings imaging metric exists, so it is counted in no imaging
  metric. For a boarding patient this metric's span therefore ends before the stay
  `metric__emergency_stay` measures, which runs to physical departure (its BL-018).

- **BL-004 (anchored at request time, not completion time):** the as-of segment match is
  evaluated against the request's own `requested_date`, with the first-segment clamp for a
  request raised before any segment began. Anchoring on the request rather than on a completion
  event is what lets a still-open or cancelled request resolve at all. The match itself is
  resolved once, upstream, by `clinical__procedure_occurrence` (its BL-005); this model does not
  re-derive it.

- **BL-005 (facility attribution):** `facility_id` is the qualifying segment's own
  `care_site_id`, not the request's `location_group_id`. The join is **inner**: a request whose
  segment location does not resolve is excluded rather than attributed to a NULL facility.

- **BL-006 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the shared `metrics:` block in `dbt_project.yml`.

- **BL-007 (modality as name and code; area emitted raw):** `imaging_type_code` and
  `imaging_type` are the raw Tamanu modality value and its readable label; `imaging_area` is the
  structured body area, falling back to the legacy free-text `areaToBeImaged` note where no
  structured area exists. All three are coalesced to `'Not recorded'` -- never NULL, since
  Tupaia's array filter drops NULL rows.

- **BL-008 (age is the consumer's to band):** `age_years` is age in whole years at the request,
  emitted raw and unbanded. A measure, not a dimension: absent from the registry's
  disaggregations.

- **BL-009 (registration and count):** `metric_id` is the constant `'ed_imaging_request'`,
  registered in `documentations/metrics/emergency.yml`. There is one row per request, and
  `value_numeric` is the constant `1`, so a consumer sums it to count requests at any grain.

- **BL-010 (sourced from the clinical layer, not `bases/imaging_requests` directly):** the
  population is `clinical__procedure_occurrence`'s imaging branch
  (`procedure_type_source_value = 'imaging request'`), which already excludes deleted and
  entered-in-error rows (its own BL-002), so this model does not re-filter status.
  `is_completed` is that model's own completion flag: a cancelled request and a still-open one
  are both false and indistinguishable by this column alone.

- **BL-011 (department attribution):** `department` is the qualifying segment's own
  `department_id`, resolved to a name through `departments` so a consumer can scope to one
  department via `metric_filters` on a readable value. Left join and coalesced to
  `'Not recorded'`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-009 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `ed_imaging_request` | BL-009 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-009 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'minute'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-009 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-005 | `not_null` |
| AC-008 | `imaging_type`, `imaging_type_code`, `imaging_area`, `is_completed`, `department` are `not_null` | BL-007, BL-010, BL-011 | `not_null` |
| AC-009 | Only 9203 segments are counted, including on an encounter later retyped as an admission, and a request in the boarding (admission) segment is not; `period_end` is gated on `is_completed` | BL-002, BL-003 | unit test `test_metric__ed_imaging_request_scope_and_completion` |

## Registry entry

Registered in `documentations/metrics/emergency.yml` as `ed_imaging_request`, `kind: metric`,
`unit: count`, `subject_grain: imaging_request`, with disaggregations `facility_id`, `sex`,
`is_completed`, `imaging_type`, `imaging_type_code`, `imaging_area`, `department`.

## Dependencies

| Model | Why |
|---|---|
| `clinical__procedure_occurrence` | The imaging-request population, and the resolved `visit_detail_id` (BL-003, BL-010) |
| `clinical__visit_detail` | The segment whose OMOP concept decides inclusion (BL-003) |
| `clinical__person` | Sex and birth date (BL-008) |
| `locations` | Facility resolution (BL-005) |
| `departments` | Department name resolution (BL-011) |
| `imaging_results` | The completion timestamp (BL-002) |
| `imaging_request_areas`, `reference_data`, `notes` | Body-area resolution, structured then free-text (BL-007) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia ED dashboard | The imaging table, ranked high to low (MAUI-6907) |

## Related

| Artefact | Relationship |
|---|---|
| `metric__opd_imaging_request` | The model this was built from -- identical shape, scoped to 9203 instead of the `clinic` source value; BL-003 explains why the scoping predicate differs in kind and not just in value |
| `metric__ed_procedure` | Sibling ED metric over the procedure branch of the same clinical model, with the same 9203 scope |
| `metric__emergency_visit` | The attendance population these requests sit within |
| `metric__emergency_stay` | Measures the ED stay to physical departure, including boarding; this metric's emergency phase ends at the admission retype (BL-003) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

- **OQ-001:** Should the full `pending`/`in_progress`/`completed`/`cancelled` status lifecycle
  be surfaced as a disaggregation, rather than the `is_completed` flag BL-010 inherits? Carried
  over unresolved from `metric__opd_imaging_request` OQ-004; the current visual does not need
  the split.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-24 | Claude | Initial draft (MAUI-6907) |

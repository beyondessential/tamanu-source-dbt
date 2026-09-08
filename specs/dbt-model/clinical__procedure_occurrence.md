# dbt Model Spec: `clinical__procedure_occurrence` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__procedure_occurrence` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware -- `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

The OMOP-lite `PROCEDURE_OCCURRENCE` domain. Originally one row per recorded procedure
(`bases/procedures`); this change adds a second source, imaging requests
(`bases/imaging_requests`), unioned in rather than given a separate model. OMOP has no
dedicated domain for medical imaging: the CDM specification describes
`PROCEDURE_OCCURRENCE` as covering "activities or processes ordered by, or carried out by, a
healthcare provider on the patient with a diagnostic or therapeutic purpose," and by the
Standardized Vocabulary's own domain assignment an imaging study is classified under
Procedure, not a separate domain -- confirmed directly by OHDSI's own Medical Imaging
Working Group: "the OMOP CDM currently represents images as only imaging procedures" (their
proposed extension, adding dedicated `Image_occurrence`/`Image_feature` tables, exists
precisely because this is a known limitation of the CDM as it stands). Imaging carries no
quantitative result, so it does not belong in `MEASUREMENT` either.

## Purpose

**What this artefact measures.** One row per recorded procedure or imaging request, in
OMOP `PROCEDURE_OCCURRENCE` shape: native id PK, the type as recorded, a single event
timestamp, and the person/visit/provider foreign keys that anchor it in the OMOP graph.
`procedure_type_source_value` says which of the two sources a row came from.

**Clinical context.** Tamanu records a procedure as `procedures` (date, location,
completion flag, a reference-data procedure type) and an imaging study as `imaging_requests`
(a distinct object with its own lifecycle -- `pending -> in_progress -> completed`, or
`-> cancelled`). Both are, in OMOP terms, procedures: an act carried out on a patient with a
diagnostic or therapeutic purpose. Neither produces a discrete measured value on its own, so
neither belongs in `MEASUREMENT`.

**Why unioned rather than a separate `clinical__imaging_occurrence` model (BL-001).** OMOP
itself draws no distinction between the two beyond what `procedure_type_source_value`
already carries here -- both are "this act happened, here, at this time, done/ordered by
this person," differing only in what a code/name pair means and where the source data
lives. Inventing a second OMOP domain table for imaging would be inventing a distinction
OMOP itself does not draw. Splitting them into two tables would also mean any future
consumer wanting "all clinical procedure activity" would need to know to union two models
itself; keeping them in one table with a discriminator does that once, here.

**Who reads it.** `metric__procedure` (general, all settings) and `metric__opd_procedure`
(outpatient-scoped) already consume the procedure branch; `metric__opd_imaging_request` is
the first consumer of the imaging branch.

## Grain

**One row per procedure or imaging request.** `bases/procedures.id` and
`bases/imaging_requests.id` are each unique within their own source table and drawn from
disjoint UUID spaces, so their union cannot collide -- `procedure_occurrence_id` stays
unique across both branches without qualification.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `procedure_occurrence_id` | varchar(255) | `procedures.id` or `imaging_requests.id`. Native id PK -- no remap to OMOP integer ids (D1) |
| `person_id` | varchar(255) | Reached through the encounter (both branches). FK to `clinical__person.person_id` |
| `procedure_date` | date | Date component of `procedure_datetime` |
| `procedure_datetime` | timestamp | When performed (procedure branch), or when requested -- not completed -- (imaging branch, BL-002) |
| `procedure_type_concept_id` | integer | Constant `32817` ("EHR administrative record") for both branches -- provenance, not what kind of act this is |
| `procedure_type_source_value` | text | `'procedure'` or `'imaging request'` -- the branch discriminator (BL-001) |
| `provider_id` | varchar(255) | Who performed it (procedure branch), or who requested it -- not who completed it -- (imaging branch, BL-003). FK to `ref__provider.provider_id` |
| `visit_occurrence_id` | varchar(255) | The encounter. FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `location_id` | varchar(255) | The row's own location, raw. Deprecated and effectively unpopulated for imaging -- superseded by `imaging_requests.location_group_id` (BL-004) |
| `procedure_source_value` | text | Reference-data code (procedure branch), or raw Tamanu `imaging_type` (imaging branch) |
| `procedure_source_name` | text | Reference-data name (procedure branch), or the modality's readable label (imaging branch) |
| `is_completed` | boolean | The row's own completion flag or status, never NULL (BL-002) |

`procedure_concept_id`/`procedure_source_concept_id` (OMOP standard SNOMED/CPT) are **not**
emitted -- deferred to the future `vocab__` layer, the same convention
`clinical__condition_occurrence` uses for `condition_concept_id`.

## Business logic

- **BL-001 (one table, two branches, one discriminator):** the imaging branch is a
  `union all`, not a new model -- see § Purpose for why. `procedure_type_source_value` is
  the only new column the addition requires; every existing column keeps its meaning for
  the procedure branch unchanged.

  **Migration note for existing consumers.** Before this change, every row here was a
  recorded procedure, so `metric__procedure` (and any other consumer added since) selected
  from this model with no branch filter. That is no longer safe: `metric__procedure` was
  updated in this same change to add `where procedure_type_source_value = 'procedure'`
  explicitly, rather than rely on the accidental fact that `imaging_requests.location_id` is
  usually NULL and so happened to be excluded by its own facility join anyway. Any other
  consumer that reads this model without a branch filter needs the identical fix before it
  is safe to build against a version of this model carrying the imaging branch --
  concretely, `metric__opd_procedure` (`feature/maui-6862-omop-outpatients-opd-procedure-
  dataset-and-visuals`, not yet merged as of this change) will need the same filter added
  when it is rebased onto this.
- **BL-002 (imaging carries no completion-side fact):** the imaging branch does not join
  `imaging_results` at all. `procedure_datetime` is `imaging_requests.datetime` (the
  request), and `is_completed` is `imaging_requests.status = 'completed'` -- the record's own
  recorded status, not a fact derived from whether a result exists. A consumer needing the
  completion timestamp, turnaround time, or the full pending/in-progress/cancelled lifecycle
  reads `bases/imaging_requests`/`bases/imaging_results` directly, the same way
  `metric__opd_imaging_request` does; this model does not carry those facts.
- **BL-003 (provider is the point of origin, not completion):** the imaging branch's
  `provider_id` is `requested_by_id`, mirroring `procedure_datetime`'s own request-time
  anchor (BL-002) -- consistent within the row rather than mixing a request-side timestamp
  with a completion-side clinician.
- **BL-004 (location is raw for both branches -- and deprecated for imaging):** neither
  branch resolves a facility -- `location_id` is the row's own value, untranslated. The
  procedure branch's is understood to be reliable (it exists to capture a procedure
  performed somewhere other than the ward). The imaging branch's is carried on the same
  basis for consistency, but it is not merely unreliable -- `imaging_requests.location_id`
  is a deprecated column in Tamanu, superseded by `location_group_id`: the application ships
  a dedicated one-time command (`migrateImagingRequestsToLocationGroups`) that backfills
  `location_group_id` from any pre-existing `location_id` value, and the current imaging
  request UI has no field that writes `location_id` at all. A consumer resolving facility
  for imaging should read `location_group_id` (via `location_groups.facility_id`, which the
  application enforces as mandatory) from `bases/imaging_requests` directly, not this
  column -- `metric__opd_imaging_request` does exactly that, not falling back to the visit
  segment.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC | `procedure_occurrence_id` is `not_null` and `unique` | grain | dbt `not_null` + `unique` |
| AC | Every `person_id` exists in `clinical__person.person_id` | -- | dbt `relationships` |
| AC | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | -- | dbt `relationships` |
| AC | Every non-null `provider_id` exists in `ref__provider.provider_id` | BL-003 | dbt `relationships` |
| AC | `procedure_date`/`procedure_datetime` are `not_null` | -- | dbt `not_null` |
| AC | `procedure_type_source_value` is `not_null` and one of `procedure`, `imaging request` | BL-001 | `not_null` + `accepted_values` |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived elements --
only `metric__`/`derived__` artefacts get a `metric_definitions` row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `procedures` | `bases/` | Procedure branch: date, location, clinician, completion, type FK |
| `imaging_requests` | `bases/` | Imaging branch: requested date, location, requesting clinician, status, modality (BL-002, BL-003) |
| `encounters` | `bases/` | Person (`patient_id`) anchor, both branches |
| `reference_data` | `bases/` | Procedure type code/name (procedure branch only -- imaging has no reference-data lookup) |
| `clinical__person` | `clinical/` | `person_id` FK target |
| `clinical__visit_occurrence` | `clinical/` | `visit_occurrence_id` FK target |
| `ref__provider` | `ref/` | `provider_id` FK target |

## Consumers

| Consumer | Use |
|---|---|
| `metric__procedure` | General procedure metric, all settings (procedure branch) |
| `metric__opd_procedure` | Outpatient-scoped procedure metric (procedure branch) |
| `metric__opd_imaging_request` | Outpatient-scoped imaging request metric (imaging branch) |

## Open questions

- **OQ-1:** `procedure_concept_id` (standard SNOMED/CPT) awaits the `vocab__` layer to map
  the retained source values, for both branches.
- **OQ-2:** `imaging_requests.location_id` is deprecated (BL-004); this model does not carry
  `location_group_id`, the field that superseded it, since OMOP's `PROCEDURE_OCCURRENCE` has
  no location-group concept and the procedure branch would only ever have it NULL. Worth
  revisiting if a second consumer also needs facility resolved for imaging and duplicating
  the `location_groups` join becomes a real cost -- for now each consumer (just
  `metric__opd_imaging_request`) reads `location_group_id` from `bases/imaging_requests`
  itself.

## Change log

| Date | Author | Change |
|---|---|---|
| ~2026-08 | Maui team | Initial (`procedures` only) |
| 2026-09 | @gagank16 | Added the imaging branch and `procedure_type_source_value` discriminator |

# Report Spec: `encounter-summary`

## Identity

| Field | Value |
|---|---|
| **Name** | `encounter-summary-by-start-date`, `encounter-summary-by-end-date` (+ sensitive twins) |
| **Macros** | `encounter_summary_report(date_field, is_sensitive)` — presentation; `encounter_summary_core(date_field, is_sensitive)` — resolution |
| **Type** | Tamanu report (reporting schema) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-02 |

One row per encounter, with the patient, the encounter's movement history, and its
clinical aggregates flattened into a single wide row.

## Purpose

`encounter_summary_core()` resolves the rows; `encounter_summary_report()` formats them.
The split is what lets a deployment repo extend the report — adding columns from its own
joins — by calling the core and writing its own projection, instead of maintaining a copy
of the body.

## Grain

One row per encounter in the requested sensitivity partition whose `date_field` falls in
the report window. `date_field` is `start_datetime` or `end_datetime`; the `end_datetime`
variant additionally requires a non-null `end_datetime`, so open encounters are absent.

## Inputs

| Argument | Purpose |
|---|---|
| `date_field` | `start_datetime` or `end_datetime` — which date the report window filters on |
| `is_sensitive` | Facility partition. `false` = non-sensitive facilities only |

Parameters: `fromDate`, `toDate`, `facilityId`, `patientBillingTypeId`,
`supervisingClinicianId`, `departmentId`, `locationGroupId`.

## The core's output contract

The core emits resolved values, mostly raw: naive timestamps, aggregates as arrays or
text. Each caller applies its own `translate_label`, `to_char` and timezone shift.

- **BL-001:** `encounter_id` and `patient_id` are emitted. They are the join keys an
  extending caller needs; the formatted report output exposes neither, and its patient
  `display_id` is patient-grain, so joining on it fans out across a patient's encounters.
- **BL-002:** The core's **projection** applies no `to_char` and no
  `to_user_selected_timezone`, so a caller's chosen presentation is not competing with
  one already applied. This governs the select list only — the CTEs do use both, and the
  compiled core carries nine `:timezone` placeholders as a result.
- **BL-003:** The core applies no `order by`. A caller wraps it in a subquery, where
  ordering is not guaranteed to survive, so ordering is the caller's responsibility.
- **BL-004:** `department_ids` and `location_group_ids` are emitted. The `departmentId`
  and `locationGroupId` filters test membership of arrays built by the aggregation, so
  they cannot be applied before it, and a caller filtering the same way needs them.
- **BL-005:** The `parameter()` filters live in the core — in the scope CTE and the outer
  `where`. The core is therefore report-layer, and lives under `macros/reports/`.
- **BL-006:** Seven outputs leave the core already formatted, in the viewer's timezone,
  applied inside the CTEs: `discharge_department_datetime`,
  `discharge_location_datetime`, `discharge_location_group_datetime`; the
  `department_datetimes`, `location_datetimes` and `location_group_datetimes` arrays; and
  the dates embedded in the `procedures` and `notes` text. A caller needing a different
  format for any of these has no raw column to select, and must change the CTEs.
- **BL-007:** The history consolidation **left**-joins `users` on
  `encounter_history.updated_by_id`, which is nullable at source unlike `department_id`,
  `location_id` and `examiner_id`, so a history row with no actor is kept and its
  clinician resolves to null.
- **BL-008:** The date range is filtered **twice**. The exact predicate compares the
  column after `to_user_selected_timezone()`; a second, wider predicate compares
  `encounters.start_date_iso` / `end_date_iso`, the stored `character(19)` columns, with
  the bounds widened two days at each end. The first decides the result, the second
  decides how much of the table is read. Neither is redundant: without the exact one the
  range is wrong, without the wide one nothing prunes.

  The exact predicate cannot prune, and the reason is structural rather than a missing
  index. Under `dbt compile` it expands to two `at time zone` conversions whose target
  zone is the `:timezone` bind, so no index — not even an expression index — can match
  it, and the planner has no statistics for the expression either. The bad row estimate
  that follows is the more expensive half: the scope CTE is materialised (it is
  referenced ten times, so Postgres 12+ never inlines it) and every clinical aggregate
  CTE downstream inherits the estimate as a hash join over a full table scan.

  **The candidate bounds fix the scan, not the estimate.** The exact predicates remain,
  remain unestimable, and the scope CTE is still costed at a fraction of its true size —
  measured on a populated fixture, 3 rows against 183 actual, and 6 against 783. That is
  why BL-009 could not simply wait for the aggregate CTEs to re-plan themselves.

  **Two days, not one.** `audit-outpatient-appointments` BL-039 widens its timestamptz
  bound by a day. That is not enough here: `to_user_selected_timezone()` can move a value
  by up to 26 hours where the deployment's central zone and the viewer's are far apart
  (Pacific/Kiritimati at UTC+14 read from UTC-11), and the direction it fails in drops
  rows silently. Measured at one day, that zone pair loses rows; at two, none.

  **The by-end-date variant needs a disjunction.** `end_datetime` is `end_date` except
  where an encounter records an end before its own start, where the base model reports the
  start instead. So `end_datetime <= to` implies `end_date <= to` outright, but the lower
  bound has to admit either column, or every end-before-start encounter silently vanishes
  from the report. Both arms are bounded at both ends; leaving the `start_date` arm open
  above is still correct but turns it into an open-ended index scan.

- **BL-009:** `notes_raw` is split into one branch per `record_type`, unioned, rather than
  a single pass over `notes` joined on `coalesce(ir.encounter_id, n.record_id)`. The
  coalesce is an expression, so it could reach no index on `notes.record_id`, which left
  `notes` — the largest clinical table on a hospital deployment — read in full on every
  run. It was the only aggregate CTE with this problem; every other one already joins
  `encounters_in_scope` on a bare `encounter_id`.

  Each branch reaches `notes_record_id_idx`, a hash index and therefore equality-only,
  which is all either branch asks of it. The imaging branch reaches its encounter through
  `imaging_requests_encounter_id`. No new index, so no Tamanu migration.

  This depends on BL-008 rather than standing beside it: the nested loop is chosen only
  because the encounters scan is cheap. It is also why the union matters more than a plan
  hint would — it leaves the planner both options, so a scope set large enough to favour a
  hash join still gets one.

  **The imaging branch inner-joins where the coalesce had a fallback arm.** A note whose
  `record_id` resolved to no `imaging_request` was previously compared against
  `encounter_id` directly. That arm is reachable, since `ref('imaging_requests')` drops
  requests on the test patient or on deleted encounters. For it to return a row an imaging
  request id would have to equal an encounter id; when that is forced to happen, the row
  enters `notes_raw` but reaches neither consumer, so the report output is identical
  either way (AC-011).
- **BL-010:** The three note aggregates order by `datetime, id`, not `datetime` alone. Two
  notes recorded in the same second otherwise order arbitrarily and the aggregated string
  follows whatever physical order the plan produces. This is pre-existing and independent
  of BL-009, but BL-009 changes the plan, so leaving it would have let a report column
  reshuffle for no reason the reader could see. The same latent tie exists in the
  diagnosis, prescription, vaccination, procedure and lab aggregates and is **not** fixed
  here — see OQ-005.

## Output

Patient: `display_id`, `first_name`, `last_name`, `date_of_birth`, `sex`, `ethnicity`,
`billing_type`, `division`, `subdivision`, `village`.

Encounter: `encounter_id`, `patient_id`, `start_datetime`, `end_datetime`, `facility`,
`reason_for_encounter`, `encounter_type_emergency`, `encounter_type_inpatient`,
`encounter_type_outpatient`.

Discharge: `discharge_disposition`, `discharge_department`, `discharge_location_group`,
`discharge_location`, and the three `discharge_*_datetime` columns (BL-006).

Triage: `triage_score`, `triage_arrival_mode`, `triage_datetime`,
`triage_closed_datetime` — raw component timestamps, so a caller formats the waiting time
itself.

Clinicians: `encountering_clinician`, `supervising_clinician`.

Movement history: `departments`, `location_groups`, `locations` and their matching
`*_datetimes` arrays (BL-006), plus `department_ids` and `location_group_ids` (BL-004).

Clinical aggregates: `diagnoses`, `diagnosis_codes`, `medications`, `vaccinations`,
`procedures`, `lab_requests`, `imaging_requests`, `notes`.

The projection is a superset of what any single caller needs, so each caller keeps its
own downstream column names.

## Companion macro

`encounter_scope_common_filters()` (`macros/reports/encounter_scope_common_filters.sql`)
emits the facility, patient-billing-type and supervising-clinician filters that the
encounter-scoped reports apply identically. It calls `parameter()`, so it is report-only.

Date ranges and report-specific flags are excluded from it: they differ between callers.

## Relationship to `ds__admissions`

`admissions_dataset` opens with a CTE of the same name and shape as this core's
`encounter_history_consolidated`. The two are **deliberately not merged**; the seven
load-bearing differences are enumerated once, under *Relationship to
`encounter_summary_core`* in `specs/dbt-model/ds__admissions.md`.

The difference that shows up in output is grain. This core consolidates **every** history
row, so it reports the encounter as a whole and its `start_datetime` is the encounter's
own start. `ds__admissions` consolidates only `admission`-phase rows, so an encounter
admitted from an outpatient presentation is dated from the **conversion** there and from
the presentation here. Both are correct for the question each model answers; the two are
not expected to agree and should not be reconciled.

## Acceptance criteria

| ID | Criterion | Clause | Asserted by |
|---|---|---|---|
| AC-001 | The report output is identical whether the body is inlined or resolved through the core. | BL-002, BL-003 | Row-level `except all` both directions, per change; recorded on the PR |
| AC-002 | The core emits `encounter_id` and `patient_id`. | BL-001 | Structural — the four report models drop both columns, so no report-level test can assert it. A caller selecting from the core is the only observer. |
| AC-003 | No `:` bind placeholder originates in the core's projection. | BL-002 | Manual compile check. The core as a whole does carry placeholders, from its CTEs and `parameter()` filters. |
| AC-004 | `Division` and `Sub-division` resolve to the patient's `reference_data` names. | — | `test_encounter_summary_by_start_date_date_range_basic` |
| AC-005 | With `is_sensitive = false` no sensitive facility's encounter appears, and vice versa. | — | `test_encounter_summary_by_start_date_excludes_sensitive_facilities` |
| AC-006 | An encounter whose every history row has a null actor still appears, with a null clinician. | BL-007 | `test_encounter_summary_null_actor_history` (enc_001) |
| AC-007 | Adding the candidate bounds changes no row, for any date field, window or viewer timezone. | BL-008 | 96 scenarios (6 windows × 8 timezones × 2 date fields, including both DST transitions and the UTC+14/UTC-11 pair) compared by `except` both directions on a 300k-row fixture; zero divergences. Recorded on the PR — the compile-only branch is unreachable from dbt, so no unit test can assert it. |
| AC-008 | An encounter whose recorded end precedes its own start is still returned by the by-end-date report. | BL-008 | `test_enc_summary_end_before_start` — verified to fail when the `start_date` arm of the disjunction is removed |
| AC-009 | The candidate bounds are served by `encounters_start_date` / `encounters_end_date`. | BL-008 | `EXPLAIN (ANALYZE, BUFFERS)` on a populated fixture: by-start-date seq scan → index scan, 3703 → 28 buffers; by-end-date seq scan → BitmapOr of two bounded index scans, 3703 → 44 buffers; identical row counts. Not unit-testable — needs a populated replica. Re-measure on prod before closing MAUI-6917. |
| AC-010 | Splitting `notes_raw` changes no row of `notes_raw`, `encounter_notes` or the imaging aggregate. | BL-009 | 6 windows on a 1.32M-note fixture, `except` both directions at all three layers; the only difference is AC-011's forced collision. Recorded on the PR. |
| AC-011 | An `ImagingRequest` note whose `record_id` collides with an encounter id changes no report output. | BL-009 | Same harness, with the colliding row planted deliberately: it appears in old `notes_raw` only, and reaches neither consumer, so both downstream aggregates match. |
| AC-012 | An encounter note reaches its encounter; the revision dedup keeps the latest; system notes are excluded. | BL-009 | `test_enc_summary_encounter_notes` — fails when the encounter branch is removed, passes when the imaging branch is |
| AC-013 | An imaging request's notes reach its encounter through `imaging_requests`. | BL-009 | `test_enc_summary_imaging_notes` — fails when the imaging branch is removed, passes when the encounter branch is |
| AC-014 | `notes` is no longer read in full. | BL-009 | `EXPLAIN (ANALYZE)` on the same fixture, best of 5 warm: 7d 1418→12ms, 1mo 984→49ms, 3mo 964→119ms, 12mo 1080→378ms. Under worst-case physical layout (`record_id` correlation −0.003) the 12-month case is ~9% slower and every narrower window is 2.6–41× faster. Not unit-testable; re-measure on a replica. |

## Open questions

- **OQ-005** *(owner: Maui team; due: when the encounter summary is next profiled)* —
  BL-010 gives the three note aggregates a deterministic tiebreaker. The diagnosis,
  prescription, vaccination, procedure and lab aggregates have the same latent tie and did
  not get one, because this change does not perturb their input order and widening the
  diff further was not worth it. They remain non-deterministic on tied timestamps.

## Change log

| Date | Change |
|---|---|
| 2026-09-02 | Split `encounter_summary_report` into `encounter_summary_core` (resolution) and a presentation wrapper. Division and Sub-division added where the branch did not already carry them. |
| 2026-09-03 | `admissions_dataset` adopted this report's location-group dedup semantic; no change to this report. |
| 2026-09-18 | BL-008: date range filtered against the stored ISO-9075 columns as well as the converted ones, so the scan prunes (MAUI-6917). `models/bases/encounters.sql` grows `start_date_iso` / `end_date_iso` to carry them. Output unchanged. |
| 2026-09-20 | BL-009: `notes_raw` split per `record_type` so the notes join can reach an index (MAUI-6917); BL-010: deterministic ordering for the three note aggregates. BL-008's claim to have fixed the planner's row estimate corrected — it fixed the scan only. Output unchanged. |
| 2026-09-21 | Forward-ported BL-008/009/010 from `2.54` (#1382, #1391). Numbered to avoid BL-007 and AC-006, which `main` already used for the history-actor left join, so the two lines stayed mergeable. |

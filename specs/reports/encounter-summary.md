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
Every join that could fan out is held to one row per encounter: the discharge by the
`discharges` base model, the triage by BL-021.

## Inputs

| Argument | Purpose |
|---|---|
| `date_field` | `start_datetime` or `end_datetime` — which date the report window filters on |
| `is_sensitive` | Facility partition. `false` = non-sensitive facilities only |

Parameters: `fromDate`, `toDate`, `facilityId`, `patientBillingTypeId`,
`supervisingClinicianId`, `departmentId`, `locationGroupId`, `encounterTypeGroup`
(one of `outpatient`, `emergency`, `inpatient`).

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
- **BL-006:** Eight outputs leave the core already formatted inside the CTEs, so a caller
  needing another format has no raw column to select and must change the CTEs: the three
  `discharge_*_datetime` columns, the three `*_datetimes` arrays, and the dates embedded in
  the `procedures` and `notes` text. All but the procedures date are also shifted to the
  viewer's timezone; `procedures.date` is a `date`, so it is formatted as stored.
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
  referenced twelve times, so Postgres 12+ never inlines it) and every clinical aggregate
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
- **BL-010:** The three note aggregates order by `datetime, created_datetime, id`, not
  `datetime` alone. Two notes recorded in the same second otherwise order arbitrarily and the
  aggregated string follows whatever physical order the plan produces. `created_datetime`
  keeps same-second notes in the order they were entered. This is pre-existing and independent
  of BL-009, but BL-009 changes the plan, so leaving it would have let a report column
  reshuffle for no reason the reader could see. The same latent tie exists in the
  diagnosis, prescription, vaccination and procedure aggregates and is **not** fixed
  here — see OQ-005. (The lab aggregate's is fixed by BL-012.)
- **BL-011:** Every note aggregate reads each note's current revision, as
  `notes__revision_rank` defines it. Tamanu never edits a note in place: an edit inserts a row
  whose `revised_by_id` points at the chain's root. The current revision is the latest by
  `datetime`, with `created_datetime` breaking a same-second tie. The ranking runs over every
  note in scope before any `note_type` filter, since a revision can change a note's type. This
  covers the encounter notes and both imaging aggregates, so an edited imaging note contributes
  only its current text.
- **BL-012:** `lab_requests` lists what each live request holds, as Tamanu does: each panel
  request by its panel's name, plus the tests `int__lab_test_panel_attribution` leaves without
  a panel (Tamanu 2.66 lets one request hold both). Items order by `collected_datetime`, then
  name, so a request's several items have a deterministic order.

### Resolution rules

These were tested before they were written down. They describe behaviour the report has
had since it was split into a core and a wrapper; recording them changed no output.

- **BL-013:** An encounter with no consolidated history row — its history missing, or
  entirely unresolved (BL-014) — is **dropped** by the final select's inner join to
  `encounter_changes`, with no warning.
- **BL-014:** A history row whose department or location does not resolve — missing, or
  soft-deleted, which counts as deleted — is **dropped** by the consolidation's inner joins
  to the base models, so its change is absent from every movement-history column (the
  actor join is the exception, BL-007). An encounter left with no resolved row falls to
  BL-013, and the `logical__encounter_summary_by_*` checks drop the same rows.
- **BL-015:** `diagnoses` and `diagnosis_codes` leave out diagnoses whose `certainty` is
  `disproven` or `error`, as Tamanu does. They order primary first, then by `datetime`.
- **BL-016:** `notes` leaves out `system` notes. The filter runs after BL-011's revision
  ranking, so a note whose current revision is a system note is left out entirely.
- **BL-017:** The location-group history records a group only when it **changes** from
  the previous history row's (`lag()` by `datetime`), plus the creation row, so a move
  between two rooms of one ward is not a new area. The same rule drives `location_groups`,
  `location_group_datetimes`, `location_group_ids` and `discharge_location_group_datetime`.
- **BL-018:** `encountering_clinician` is the actor of the encounter's **creation** row
  (null `change_type`, earliest `datetime`), not `examiner_id`, which is
  `supervising_clinician`; a creation row with no actor gives null (BL-007).
- **BL-019:** Each `discharge_*_datetime` is the `datetime` of the last history row that
  changed that dimension. With no such change it **falls back** to the creation row's
  `datetime`, the time the patient was first assigned, not to null.
- **BL-020:** The wrapper applies four presentation rules of its own:
    - **Length of stay** is the number of calendar days between start and end, taken in
      the viewer's timezone, and **at least 1**: a same-day encounter is 1 day, not 0. It
      is null for an open encounter.
    - **Age** is whole years at the encounter's **start**, not at the run date.
    - **Notes** longer than 32,000 characters are cropped to 32,000 and prefixed with a
      notice that the cell was cropped. 32,767 is Excel's cell limit, and the notice and
      separator must fit.
    - **Triage waiting time** is `hh:mm:ss` between triage and its close, and null unless
      the close is after the triage.

### Aggregate scope

- **BL-021:** The triage is the encounter's **earliest**, by `(triage_datetime, id)`. Tamanu
  has no unique constraint on `triages.encounter_id`, so without this a second triage would
  duplicate the encounter's row; earliest mirrors the `discharges` base model.
- **BL-022:** `imaging_requests` lists only live requests: `cancelled`, `deleted` and
  `entered_in_error` are left out (Tamanu's imaging statuses use underscores, unlike lab's).
- **BL-023:** `medications` lists **every** prescription on the encounter in prescription
  order, discontinued ones included, each with its discontinued flag and reason.
- **BL-024:** `vaccinations` lists only `GIVEN` administrations, including those given
  elsewhere, since the text carries no status. `NOT_GIVEN` and `RECORDED_IN_ERROR` are left
  out, and so is `HISTORICAL`, which Tamanu assigns to a `NOT_GIVEN` record once the same
  scheduled dose is later given (`patientVaccine.js`) — it is a superseded refusal, not a
  past dose.

### Encounter type group filter

- **BL-025:** An encounter is `outpatient` or `emergency` when its first `encounter_history`
  row, by `datetime` then `id`, maps to visit concept 9202 or 9203 in `map__omop_visit_type`,
  and `inpatient` when any of its rows maps to 9201. An encounter can be both `emergency` and
  `inpatient`, and a `surveyResponse` encounter is in no group.
- **BL-026:** `encounterTypeGroup` keeps an encounter that belongs to the selected group. With
  nothing selected, no encounter is filtered out.
- **BL-027:** `encounter_history` is read once per run, in `history_in_scope`, which both the
  history consolidation and BL-025's classification read from.

## Relationship to the visit metrics

BL-025 makes the filter classify an encounter exactly as `metric__outpatient_visit`,
`metric__emergency_visit` and `metric__inpatient_admission` do, which are the sources of the
Tupaia outpatient, emergency and inpatient counts. A filtered row count still differs from
those metrics where the two scope encounters differently:

- The report window filters on the encounter's `date_field`. `metric__inpatient_admission` is
  dated by the start of the admission segment, so an encounter admitted after the day it
  started falls in different periods.
- The standard report excludes sensitive facilities and the sensitive one includes only them.
  The metrics apply no sensitivity partition.
- The metrics take the facility from the qualifying segment's location. The report takes it
  from the encounter.
- An encounter with no `encounter_history` rows, such as a migrated encounter loaded without
  them, is absent from the report. The metrics classify it from the encounter's own
  `encounter_type`.

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
| AC-005 | With `is_sensitive = false` no sensitive facility's encounter appears, and vice versa. | — | `test_encounter_summary_start_excludes_sensitive` (the `false` direction) and `test_encounter_summary_start_sensitive_variant` (the `true` direction). Both give the other facility's encounter an `encounter_history` row, so it reaches the partition rather than being dropped by BL-013; each fails when the partition predicate in `encounters_core` is removed. |
| AC-006 | An encounter whose every history row has a null actor still appears, with a null clinician. | BL-007 | `test_encounter_summary_null_actor_history` (enc_001) |
| AC-007 | Adding the candidate bounds changes no row, for any date field, window or viewer timezone. | BL-008 | 96 scenarios (6 windows × 8 timezones × 2 date fields, including both DST transitions and the UTC+14/UTC-11 pair) compared by `except` both directions on a 300k-row fixture; zero divergences. Recorded on the PR — the compile-only branch is unreachable from dbt, so no unit test can assert it. |
| AC-008 | An encounter whose recorded end precedes its own start is still returned by the by-end-date report. | BL-008 | `test_enc_summary_end_before_start` — verified to fail when the `start_date` arm of the disjunction is removed |
| AC-009 | The candidate bounds are served by `encounters_start_date` / `encounters_end_date`. | BL-008 | `EXPLAIN (ANALYZE, BUFFERS)` on a populated fixture: by-start-date seq scan → index scan, 3703 → 28 buffers; by-end-date seq scan → BitmapOr of two bounded index scans, 3703 → 44 buffers; identical row counts. Not unit-testable — needs a populated replica. Re-measure on prod before closing MAUI-6917. |
| AC-010 | Splitting `notes_raw` changes no row of `notes_raw`, `encounter_notes` or the imaging aggregate. | BL-009 | 6 windows on a 1.32M-note fixture, `except` both directions at all three layers; the only difference is AC-011's forced collision. Recorded on the PR. |
| AC-011 | An `ImagingRequest` note whose `record_id` collides with an encounter id changes no report output. | BL-009 | Same harness, with the colliding row planted deliberately: it appears in old `notes_raw` only, and reaches neither consumer, so both downstream aggregates match. |
| AC-012 | An encounter note reaches its encounter; the revision dedup keeps the latest; system notes are excluded. | BL-009 | `test_enc_summary_encounter_notes` — fails when the encounter branch is removed, passes when the imaging branch is |
| AC-013 | An imaging request's notes reach its encounter through `imaging_requests`. | BL-009 | `test_enc_summary_imaging_notes` — fails when the imaging branch is removed, passes when the encounter branch is |
| AC-014 | `notes` is no longer read in full. | BL-009 | `EXPLAIN (ANALYZE)` on the same fixture, best of 5 warm: 7d 1418→12ms, 1mo 984→49ms, 3mo 964→119ms, 12mo 1080→378ms. Under worst-case physical layout (`record_id` correlation −0.003) the 12-month case is ~9% slower and every narrower window is 2.6–41× faster. Not unit-testable; re-measure on a replica. |
| AC-015 | Each note aggregate reads a note's current revision: an edit replaces the text it revised, a same-second edit resolves on `created_datetime`, and an edited imaging note contributes only its current text. | BL-010, BL-011 | `test_enc_summary_encounter_notes`, `test_enc_summary_imaging_notes` |
| AC-016 | A pre-2.66 single-panel request lists only its panel; a request holding a panel and an individual test lists both, alphabetically; a cancelled request lists nothing. | BL-012 | `test_encounter_summary_lab_requests` |
| AC-017 | An encounter with no history row, or whose only row does not resolve, is not reported. | BL-013 | `test_encounter_summary_history_consolidation` (enc_002, enc_003) — fails when `encounter_changes` is left-joined |
| AC-018 | A history change to a department or location that does not resolve leaves no trace in the movement history or discharge times. | BL-014 | `test_encounter_summary_history_consolidation` (enc_001) — fails when the history's `departments` / `locations` joins are left joins |
| AC-019 | `disproven` and `error` diagnoses are left out; the rest order primary first, then by time. | BL-015 | `test_encounter_summary_excludes_disproven_and_error_diagnoses` — fails when the certainty filter is removed |
| AC-020 | A `system` note does not appear in `notes`. | BL-016 | `test_enc_summary_encounter_notes` — fails when the filter is removed |
| AC-021 | A move between two locations of one group adds a location but not an area, and leaves the area's discharge time at the creation row. | BL-017 | `test_encounter_summary_history_consolidation` (enc_001) — fails when the dedup is removed |
| AC-022 | The clinician is the creation row's actor, not a later actor. | BL-018 | `test_encounter_summary_history_consolidation` (enc_001) — fails when any row's actor is taken |
| AC-023 | A discharge time with no matching change is the creation row's time, and with changes is the last change's time. | BL-019 | `test_enc_summary_discharge_datetime_fallback`, `test_enc_summary_discharge_datetime_with_changes`. Removing the fallback fails most encounter summary fixtures, since most have no changes. |
| AC-024 | Length of stay is at least 1 and null for an open encounter; age is taken at the start; notes are cropped at 32,000 characters. | BL-020 | Partly. Length of stay: `test_enc_summary_discharge_datetime_fallback` and three others fail at a floor of 0. Age: every fixture asserts a value, but none is built so that age at start and age at end differ. Crop: only the short side — `test_enc_summary_encounter_notes` fails if the threshold drops, but no fixture holds a note over 32,000 characters, so the crop itself is not asserted. |
| AC-025 | An encounter with two triages is one row, carrying the earlier triage. | BL-021 | `test_encounter_summary_aggregate_scope` — fails without the dedup |
| AC-026 | Cancelled, deleted and entered-in-error imaging requests are not listed. | BL-022 | `test_encounter_summary_aggregate_scope` — fails without the status filter |
| AC-027 | A discontinued prescription is listed, flagged, in prescription order. | BL-023 | `test_encounter_summary_aggregate_scope` |
| AC-028 | Only `GIVEN` vaccines are listed. | BL-024 | `test_encounter_summary_aggregate_scope` — fails without the status filter |
| AC-029 | `emergency` keeps an encounter that started as an emergency type, including one later admitted, and drops one that started in clinic and ended as an emergency. A same-datetime tie resolves on the history `id`. | BL-025, BL-026 | `test_encounter_summary_encounter_type_filter_emergency` |
| AC-030 | `inpatient` keeps any encounter with an admission row. | BL-025, BL-026 | `test_encounter_summary_encounter_type_filter_inpatient` |
| AC-031 | `outpatient` keeps an encounter that started as an outpatient type, whatever its type at discharge. | BL-025, BL-026 | `test_encounter_summary_encounter_type_filter_outpatient` |
| AC-032 | With no group selected every encounter is returned, including one in no group. | BL-026 | `test_encounter_summary_encounter_type_filter_unset` |
| AC-033 | With no group selected the output is unchanged by BL-025–BL-027, and the plan reads `encounter_history` once with or without a group selected. | BL-026, BL-027 | Row-level `except all` both directions against the release database, both date fields, 7-day, 3-month and full windows, every group; `EXPLAIN (ANALYZE)` counts the `encounter_history` scans. Recorded on the PR. |

## Open questions

- **OQ-005** *(owner: Maui team; due: when the encounter summary is next profiled)* —
  Several orderings are not deterministic. BL-010 gives the three note aggregates a
  tiebreaker, and BL-012 the lab aggregate. The rest are unchanged:
    - `encounter_imaging_requests` has **no** `order by` at all. Requests on one encounter
      concatenate in whatever order the plan produces, so the column can differ between runs
      with no change to the data. This is the most exposed.
    - The `procedures` aggregate orders by `procedures.date`, a `date`. Two procedures on the
      same day tie, which is the ordinary case, not an edge case.
    - The diagnosis, prescription and vaccination aggregates order by a timestamp alone, so
      they tie only on same-second rows.
    - The history aggregates in `encounter_changes` (the movement-history strings, their
      `*_datetimes` and id arrays, and the encounter-type progressions) order by `datetime`
      alone. A same-second pair of history rows can swap. The `lag()` and `row_number()` in
      `encounter_history_consolidated` order the same way, so the same tie can also change
      the location-group dedup (BL-017).
    - The wrapper's `order by <date_field> desc` has no tiebreak, so encounters sharing a
      timestamp come out in any order.

  None of these was fixed when BL-010 and BL-012 were, because those changes did not
  perturb these inputs and widening the diff was not worth it. Each fix is a deterministic
  `order by` tiebreak (for example `id`). It changes no row's content, but it can change
  the order within a cell, so it is a visible change and wants its own PR.

## Change log

| Date | Change |
|---|---|
| 2026-09-02 | Split `encounter_summary_report` into `encounter_summary_core` (resolution) and a presentation wrapper. Division and Sub-division added where the branch did not already carry them. |
| 2026-09-03 | `admissions_dataset` adopted this report's location-group dedup semantic; no change to this report. |
| 2026-09-18 | BL-008: date range filtered against the stored ISO-9075 columns as well as the converted ones, so the scan prunes (MAUI-6917). `models/bases/encounters.sql` grows `start_date_iso` / `end_date_iso` to carry them. Output unchanged. |
| 2026-09-20 | BL-009: `notes_raw` split per `record_type` so the notes join can reach an index (MAUI-6917); BL-010: deterministic ordering for the three note aggregates. BL-008's claim to have fixed the planner's row estimate corrected — it fixed the scan only. Output unchanged. |
| 2026-09-21 | Forward-ported BL-008/009/010 from `2.54` (#1382, #1391). Numbered to avoid BL-007 and AC-006, which `main` already used for the history-actor left join, so the two lines stayed mergeable. |
| 2026-09-27 | BL-011: every note aggregate reads each note's current revision (`notes__revision_rank`), so an edited imaging note no longer contributes the text it replaced. BL-010: same-second notes order by `created_datetime`. |
| 2026-10-15 | BL-012: `lab_requests` follows Tamanu 2.66's one-to-many panel structure — each panel request by name plus the tests not attributed to a panel — and orders ties by name (MAUI-6163). |
| 2026-10-15 | MAUI-7011, from the 2.66 conformance review. BL-006 corrected: eight formatted outputs, not seven, and the procedures date is formatted but not shifted. BL-013–BL-020 record resolution and presentation rules that were tested but unwritten, with `test_encounter_summary_history_consolidation` added for the four no test asserted. AC-005 now cites the test names, and its `false`-direction fixture gives the sensitive encounter a history row so it no longer passes vacuously. OQ-005 now lists every non-deterministic ordering. The `logical__encounter_summary_by_*` checks no longer inner-join the history actor, which contradicted BL-007. Output unchanged. |
| 2026-10-15 | MAUI-7011 follow-up. **Output changes:** `vaccinations` lists only `GIVEN` administrations (BL-024) — in the 2.66 release DB 519 of 1,057 records were `NOT_GIVEN` and read as given; and an encounter with several triages is one row (BL-021), which changes nothing where triages are already unique. BL-022 and BL-023 record existing imaging and medication behaviour. BL-014 states that soft-deleted departments and locations count as deleted, and the logical checks now drop those history rows too. BL-008's count of scope-CTE references corrected (now twelve). |
| 2026-10-28 | BL-025/BL-026: `encounterTypeGroup` filter, classified as the visit metrics behind the Tupaia counts classify an encounter rather than by its type at discharge (MAUI-7063). BL-027: `encounter_history` read once and shared. Numbered to avoid BL-012–BL-024 and AC-016–AC-028, already used by `main`. |

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

## Acceptance criteria

| ID | Criterion | Clause | Asserted by |
|---|---|---|---|
| AC-001 | The report output is identical whether the body is inlined or resolved through the core. | BL-002, BL-003 | Row-level `except all` both directions, per change; recorded on the PR |
| AC-002 | The core emits `encounter_id` and `patient_id`. | BL-001 | Structural — the four report models drop both columns, so no report-level test can assert it. A caller selecting from the core is the only observer. |
| AC-003 | No `:` bind placeholder originates in the core's projection. | BL-002 | Manual compile check. The core as a whole does carry placeholders, from its CTEs and `parameter()` filters. |
| AC-004 | `Division` and `Sub-division` resolve to the patient's `reference_data` names. | — | `test_encounter_summary_by_start_date_date_range_basic` |
| AC-005 | With `is_sensitive = false` no sensitive facility's encounter appears, and vice versa. | — | `test_encounter_summary_by_start_date_excludes_sensitive_facilities` |

## Open questions

- **OQ-002** *(owner: Maui team; due: before the next behavioural change to
  `ds__admissions`)* — this report's location-group dedup treats a null group as a real
  state, so a transition into a null group is recorded as a change. `admissions_dataset`
  uses `location_group_id != prev_location_group_id or prev_location_group_id is null`,
  which drops that transition. Both include the creation row, so that is the only
  divergence. Aligning them means changing `admissions_dataset`, which alters the
  admissions line list rather than this report.

Resolved: OQ-001 (the history actor is left-joined), OQ-003 (the unread columns and the
redundant `users` join are gone), OQ-004 (the sensitive variant has a unit test).

## Change log

| Date | Change |
|---|---|
| 2026-09-02 | Split `encounter_summary_report` into `encounter_summary_core` (resolution) and a presentation wrapper. Division and Sub-division added where the branch did not already carry them. |

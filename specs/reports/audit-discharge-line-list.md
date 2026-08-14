# Report Spec: `audit-discharge-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `audit-discharge-line-list` |
| **Type** | Tamanu report (shared macro in `macros/reports/`, standard + sensitive wrappers in `models/reports/`), plus the `ds__discharge_audit` dataset and the `discharges_change_logs` base model |
| **Layer** | `base`, `ds`, `report` |
| **Materialisation** | base `view`, dataset `view`, report `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | TBC |
| **Repo** | `tamanu-source-dbt`, version branch `2.54` |
| **Created** | 2026-08-14 |

## Purpose

Tamanu records two different discharge times: the clinical discharge date and time
entered on the discharge form (`encounters.end_date`, which is what every existing report
shows), and the moment the discharge was actually recorded in the system. No report exposes
the second one.

Kiribati MoH is clearing a backlog of undischarged patients and unfilled medical coding
forms, and needs to see discharge activity by the date staff did the work rather than the
date they entered. The need is generic — any deployment monitoring discharge completeness
wants it — so the report is standard rather than deployment-specific.

**Consumer:** Tamanu reporting UI. Kiribati MoH operational monitoring in the first
instance.

## Grain

One row per discharge record, which is one row per discharged encounter: `discharges` is
deduplicated to one row per encounter by the `discharges` base model. Discharges belonging to
a deleted or merged patient are out of scope.

## Inputs

### Parameters

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | (UI default 30 days) | Lower bound on `discharge_recorded_datetime` (viewer-timezone aware) |
| `toDate` | date | (UI default 30 days) | Upper bound on `discharge_recorded_datetime`, inclusive of the whole day |
| `facilityId` | uuid | null | Optional restriction to a single facility |
| `departmentId` | uuid | null | Optional restriction to a single department |
| `encounterType` | text[] | null | Optional restriction to one or more encounter types |
| `dischargeType` | text (`manual` / `automatic`) | null | Optional restriction to user-recorded or system-generated discharges |

### Macro argument

| Argument | Values | Purpose |
|---|---|---|
| `is_sensitive` | `false` (standard) / `true` (sensitive) | Selects the facility partition. |

### Upstream models

| Reference | Why we need it |
|---|---|
| `ref('discharges')` | The discharge record: disposition, discharging clinician, note, creation time |
| `ref('discharges_change_logs')` | Recording timestamp, recording user, later-edit count |
| `ref('encounters')` | Encounter dates and type |
| `ref('locations')`, `ref('facilities')`, `ref('departments')` | Where the encounter sat, and the sensitive-facility partition |
| `ref('patients')`, `ref('reference_data')`, `ref('users')` | Demographics, village and disposition labels, user display names |

## Output schema

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId` | text | Patient display ID |
| `patientFirstName` | text | Patient given name |
| `patientLastName` | text | Patient family name |
| `patientDateOfBirth` | text | Date of birth, formatted |
| `patientSex` | text | Patient sex |
| `patientVillage` | text | Patient village |
| `encounterType` | text | Encounter type label |
| `facility` | text | Facility of the encounter's location |
| `department` | text | Department recorded on the encounter |
| `location` | text | Location recorded on the encounter |
| `encounterStartDateTime` | text | Encounter start, formatted in the viewer's timezone |
| `dischargeDateTime` | text | Discharge date and time entered on the discharge form |
| `dischargeRecordedDateTime` | text | When the discharge was recorded in Tamanu |
| `dischargeRecordingDelayDays` | integer | Whole days between the two |
| `dischargeDisposition` | text | Discharge disposition label |
| `dischargeClinician` | text | Clinician named on the discharge form |
| `dischargeRecordedBy` | text | User who completed the discharge form |
| `dischargeIsAutomatic` | text | `Yes` / `No` |
| `dischargeLaterEditCount` | integer | Edits after the discharge was first recorded |

## Business logic

- **BL-001:** Grain is one row per non-deleted `discharges` record whose encounter is not
  deleted and whose patient is neither deleted, merged, nor the test patient.
- **BL-002:** `discharge_recorded_datetime` is the `logged_at` of the earliest
  `logs.changes` entry for the discharge record, falling back to the discharge record's
  `created_at` where no change log entry exists.
- **BL-003:** `logs.changes.logged_at` and `discharges.created_at` are `timestamptz` and are
  converted to deployment-local wall clock in the base layer; `encounters.start_date` and
  `end_date` are already local wall clock and are not converted. Only the report layer
  applies `to_user_selected_timezone`.
- **BL-004:** Discharges whose note begins `Automatically discharged` are system actions,
  not staff actions. They are exposed via `is_auto_discharge` rather than filtered out, and
  the `dischargeType` parameter selects between the two populations.
- **BL-005:** `logs.changes.updated_by_user_id` defaults to the nil UUID when no audit user
  is set on the session, so the join to users is a left join and renders blank rather than
  dropping the row.
- **BL-006:** The clinician named on the discharge form and the user who recorded it are
  different people in general, and are reported as separate columns.
- **BL-007:** The report's date range filters on `discharge_recorded_datetime`, and covers
  the whole of `toDate` rather than stopping at its midnight boundary.
- **BL-008:** `later_edit_count` is the number of change log entries after the first. It is
  null where the discharge has no change log coverage, which distinguishes "never edited"
  from "not known".
- **BL-009:** Facility scope is partitioned by the `is_sensitive` macro argument.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | No rows for soft-deleted discharges or encounters, and none for deleted, merged or test patients | BL-001 | `logical__ds__discharge_audit` |
| AC-002 | Exactly one row per `encounter_id` | BL-001 | `unique` on `encounter_id`, `logical__ds__discharge_audit` |
| AC-003 | `discharge_recorded_datetime` is never null, and falls back to the discharge record's creation time where the change log has no entry | BL-002 | `not_null`, `test_ds__discharge_audit_changelog_fallback` |
| AC-004 | A discharge whose entered date precedes its recorded date by several days returns the expected positive `days_between_discharge_and_recording` | BL-002, BL-003 | `test_ds__discharge_audit_recording_delay` |
| AC-005 | A UTC change log timestamp near local midnight lands on the correct local date | BL-003 | `test_discharges_change_logs_timezone` |
| AC-006 | Auto-discharged rows are flagged, not dropped, and carry no recording user when the session had no audit user | BL-004, BL-005 | `test_ds__discharge_audit_recording_delay` |
| AC-007 | The date range includes discharges recorded at any time of day on `toDate` | BL-007 | Manual run against a demo snapshot |

## Risks

- **Report runtime.** Reports run in production as views over the compiled bundle, so the
  whole `ref()` chain is re-evaluated per run. `logs.changes` is the largest table in a
  mature deployment and there is no guarantee of a useful index on `table_name`. Test on a
  Kiribati replica snapshot before shipping. If it is slow, apply the narrower-window
  parallel intermediate pattern.
- **Change log coverage.** Anything discharged before the change log trigger was installed
  has no change log entry. BL-002's fallback covers the timestamp, but the recording user
  and edit count are blank for those rows, and the report notes say so.

## Open questions

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-14 | Maui team | Initial spec and implementation, named "Audit - discharge line list", cut against the `2.54` version branch for the Kiribati deployment. Adds the `discharges_change_logs` base model, `created_datetime` on the `discharges` base model, the `ds__discharge_audit` dataset and the standard + sensitive report pair. |

# Report Spec: `audit-patient-details-edit`

## Identity

| Field | Value |
|---|---|
| **Name** | `audit-patient-details-edit` |
| **Type** | Tamanu report (shared macro in `macros/reports/`), plus the `ds__patients_change_logs` dataset and the `patients_change_logs` / `patient_additional_data_change_logs` base models |
| **Layer** | `base`, `ds`, `report` |
| **Materialisation** | base `view`, dataset `view`, report `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7017](https://linear.app/bes/issue/MAUI-7017) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-10-19 |

## Purpose

Administrators need to audit who edited a patient's personally identifiable details — name,
date of birth, contact information, insurance details — and when. The report lists every edit
to the patient `Details` component (the `patients` and `patient_additional_data` tables),
grouping changes to an individual patient's details inside the same minute into a single row.

**Consumer:** Tamanu reporting UI.

## Grain

One row per patient per minute of edit activity, across both `patients` and
`patient_additional_data` changes.

## Inputs

### Parameters

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | UI default | Lower bound on `edited_datetime` (viewer-timezone aware) |
| `toDate` | date | UI default | Upper bound on `edited_datetime`, inclusive of the whole day |
| `patientId` | uuid | null | Optional restriction to a single patient |
| `userId` | uuid | null | Optional restriction to a single editing user |

### Upstream models

| Reference | Why we need it |
|---|---|
| `ref('patients_change_logs')` | Change-log history of the `patients` table, and the report's candidate scan |
| `ref('patient_additional_data_change_logs')` | Change-log history of the `patient_additional_data` table, and the report's candidate scan |
| `ref('patients')` | Current patient details, joined onto `patient_additional_data` edits which carry no name/DOB/sex/village of their own |
| `ref('users')` | Editing user's display name, email, role |
| `ref('reference_data')` | Village name |

## Output schema

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId` | text | Patient display ID |
| `patientFirstName` | text | Patient given name, at the time of edit |
| `patientLastName` | text | Patient family name, at the time of edit |
| `patientDateOfBirth` | text | Date of birth at the time of edit, formatted |
| `patientSex` | text | Patient sex at the time of edit |
| `patientVillage` | text | Patient village at the time of edit |
| `logChangeBy` | text | Editing user's display name |
| `userEmail` | text | Editing user's email address |
| `userRole` | text | Editing user's role |
| `logChangeDateTime` | text | When the edit was made, formatted in the viewer's timezone, truncated to the minute |

## Business logic

- **BL-001:** Grain is one row per patient per minute of edit activity. `patients_change_logs`
  and `patient_additional_data_change_logs` are unioned, then grouped by patient and minute, so
  several edits to the same patient inside one minute collapse to one row.
- **BL-002:** A `patient_additional_data` edit carries no name, date of birth, sex or village of
  its own — those columns come from `ref('patients')` as they stand today, not as they stood at
  the time of the edit, unlike a `patients` edit, which reads them from its own change-log
  record.
- **BL-003:** `logs.changes.logged_at` is `timestamptz` and is converted to deployment-local
  wall clock in the base layer; only the report layer applies `to_user_selected_timezone`.
- **BL-004:** The report's date range filters on `edited_datetime`, truncated to the minute, and
  covers the whole of `toDate` rather than stopping at its midnight boundary.
- **BL-013:** The report scopes the dataset's edit aggregation to candidate patients — those
  with a `patients` or `patient_additional_data` change logged between `fromDate` less two days
  and `toDate` plus three days, deployment-local time, found by scanning
  `patients_change_logs` and `patient_additional_data_change_logs` directly — before it runs,
  reaching `logs.changes` through the `(table_name, record_id)` index rather than a full scan.
  The window is widened because the candidate compares deployment time while BL-004's filter
  compares the viewer's selected timezone, up to 26 hours apart, and BL-004's exact filter
  trims the result to the range afterwards, so correctness never depends on the candidate step
  being exact. `ds__patients_change_logs` calls the same core macro unfiltered, so other
  consumers keep reading every patient's full history.
- **BL-014:** `patients_change_logs_core()` holds the shared edit union and aggregation,
  parameterised by `candidate_patient_ids` — a subquery of candidate patient ids, applied
  identically against both source tables' patient-id columns. `ds__patients_change_logs` calls
  it unfiltered; the report calls it with BL-013's candidate filter.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | Several edits to one patient inside the same minute return exactly one row | BL-001 | Manual run against a demo snapshot |
| AC-002 | A `patient_additional_data` edit reports the patient's current name, date of birth, sex and village | BL-002 | Manual run against a demo snapshot |
| AC-003 | The date range includes edits made at any time of day on `toDate` | BL-004 | Manual run against a demo snapshot |
| AC-004 | A patient changed outside the candidate window (including its ±2/+3 day margin) is excluded from the report; one changed inside it is included and the row's values are unaffected by the candidate step | BL-013 | Manual run against a demo snapshot; `EXPLAIN` confirms the `(table_name, record_id)` index is used for candidates only |

Data tests run at `warn` severity project-wide (`data_tests: +severity: warn` in
`dbt_project.yml`); this report has none beyond the base and report-config validation scripts.

## Risks

- **Report runtime.** Before BL-013, the report read every patient's full edit history on every
  run, aggregated, and only then applied its date filter — forcing a full `logs.changes` scan
  for both tracked tables regardless of the requested range. BL-013's candidate step keeps this
  scoped to patients with activity in the window.
- **Candidate scan cost.** The candidate step itself still reads each tracked table's full
  change-log view before narrowing to the date range, the same residual cost noted for the
  identity-audit pattern this report follows. The saving is in not aggregating the whole
  history, not in avoiding the candidate scan entirely.

## Open questions

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-19 | Maui team | [MAUI-7017](https://linear.app/bes/issue/MAUI-7017): retrospective spec documenting the existing report, plus BL-013/BL-014 and AC-004 for the new candidate-scoping step (`patients_change_logs_core()`, `audit_patient_details_edit_report()`). Output unchanged. |

# Report Spec: `encounter-prescription-discharge-summary`

## Identity

| Field | Value |
|---|---|
| **Name** | `encounter-prescription-discharge-summary` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading the existing `ds__encounter_prescriptions` / `ds__sensitive_encounter_prescriptions` datasets |
| **Layer** | `ds`, `report` |
| **Materialisation** | dataset `view`, report `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | TBC |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-25 |

## Purpose

Tamanu records discharge medication in two different places. `is_selected_for_discharge` on
`encounter_prescriptions` is set by the clinician at discharge, for every medication the patient
leaves with -- whether or not it goes through pharmacy. `medication_dispenses` is a separate,
later record: pharmacy staff physically handing the medication over, using Tamanu's own dispense
workflow.

`medication-dispensed-summary` only reads `medication_dispenses`, so it is always empty for a
deployment where pharmacy doesn't use that workflow -- even though clinicians are still
discharging patients with medication. Fiji is the first such case.

This report reads `ds__encounter_prescriptions` filtered on `is_selected_for_discharge = true` --
the same source pattern `msf-medication-dispensed-summary-historical` (`tamanu-dbt-msf`) uses --
but with no cutoff date, and with `medication-dispensed-summary`'s output shape: item code, item
name, and an aggregate quantity for the selected date range.

**Consumer:** Tamanu reporting UI. Fiji in the first instance.

## Grain

One row per medication, aggregated across all matching encounter prescriptions in the selected
date range and filters -- a single total per medication for the whole range, not broken down by
day. Matches the grain of `medication-dispensed-summary`, not the per-day grain of
`msf-medication-dispensed-summary-historical`.

## Inputs

### Parameters

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | timestamp | 2024-01-01 | Lower bound on `datetime` (viewer-timezone aware) |
| `toDate` | timestamp | 2024-01-31 | Upper bound on `datetime` (viewer-timezone aware) |
| `facilityId` | uuid | null | Optional restriction to a single facility |
| `medicationId` | uuid | null | Optional restriction to a single drug |

### Upstream models

| Reference | Why we need it |
|---|---|
| `ref('ds__encounter_prescriptions')` | Standard variant: prescription quantity, medication identity, facility, discharge-selection flag |
| `ref('ds__sensitive_encounter_prescriptions')` | Sensitive variant: same, partitioned to sensitive facilities |

## Output schema

| Column (translation key) | Type | Description |
|---|---|---|
| `encounterPrescriptionMedication` | text | Medication name |
| `encounterPrescriptionMedicationCode` | text | Medication reference-data code |
| `encounterPrescriptionQuantity` | integer | Sum of `quantity` across matching prescriptions for the medication, for the whole selected date range |

## Business logic

- **BL-001:** Source rows are `ds__encounter_prescriptions` / `ds__sensitive_encounter_prescriptions`
  filtered to `is_selected_for_discharge = true` -- the pre-dispensing-module proxy for a
  prescription being sent to / dispensed by pharmacy, mirroring the source logic of
  `msf-medication-dispensed-summary-historical.sql` in `tamanu-dbt-msf`.
- **BL-002:** No date cutoff -- this is an ongoing report for deployments that have never
  migrated off encounter prescriptions. See Risks for what to do if a deployment using this
  report later migrates.
- **BL-003:** Date range filters on `datetime` (the prescription's local date and time, per
  `ds__encounter_prescriptions.yml`), converted to the viewer-selected timezone, matching the
  convention in `medication-dispensed-summary.sql`.
- **BL-004:** Output columns and their translation keys (`encounterPrescriptionMedication`,
  `encounterPrescriptionMedicationCode`, `encounterPrescriptionQuantity`) are shared with
  `medication-dispensed-summary` / `sensitive-medication-dispensed-summary` and
  `prescription-line-list` / `sensitive-prescription-line-list`, since the columns mean the same
  thing across all of them: medication identity and a quantity.
- **BL-005:** Grouped by `medication_id`, `medication`, `medication_code` -- one row per
  medication for the whole selected range, matching the grain and grouping of
  `medication-dispensed-summary`.
- **BL-009:** Facility scope is the sensitive-facility partition already built into
  `ds__sensitive_encounter_prescriptions` (facilities with a `sensitive_network_id`), not a parameter on
  this report.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | Only prescriptions with `is_selected_for_discharge = true` are included | BL-001 | `test_encounter_prescription_discharge_summary` — fails when the filter is removed |
| AC-002 | Rows outside the selected date range (by `datetime`, viewer timezone) are excluded | BL-003 | `test_encounter_prescription_discharge_summary` — fails when the lower bound is removed. The fixture uses UTC, so the timezone shift itself is not exercised |
| AC-003 | Sensitive variant only includes prescriptions at facilities with a `sensitive_network_id` | BL-009 | `test_ds_sensitive_encounter_prescriptions_partition` — fails when the partition is a constant `false` |
| AC-004 | One row per medication, summed quantity across all matching prescriptions in the selected range | BL-005 | `test_encounter_prescription_discharge_summary` — fails when grouped per prescription |
| AC-005 | Output columns are labelled with the shared `encounterPrescription*` keys | BL-004 | `test_encounter_prescription_discharge_summary` asserts the default labels `Medication`, `Code`, `Quantity` |

## Risks

- **Not a substitute once a deployment migrates.** If a deployment using this report later goes
  live on the pharmacy dispensing module, this report will start under-reporting new activity
  (prescriptions stop being marked `is_selected_for_discharge` in the old way once staff switch
  workflows). At that point, follow the MSF pattern: cap this report with a cutoff date and point
  ongoing reporting at `medication-dispensed-summary`.
- **Two reports, same real-world question.** A deployment could have both this report and
  `medication-dispensed-summary` visible and not know which one has their data. Report `notes`
  fields point at the sibling report by name to reduce this, but the reporting UI does not
  enforce mutual exclusivity.

## Open questions

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-25 | Maui team | Initial spec and implementation, standard + sensitive pair, for Fiji (still on encounter prescriptions, never migrated to the pharmacy dispensing module). |
| 2026-08-25 | Maui team | Briefly changed output shape to match `msf-medication-dispensed-summary-historical` (date breakdown, distinct patient count, doses); reverted the same day once the actual requester ask was confirmed as item code, item name, and a single aggregate quantity for the period, with no date breakdown -- matching `medication-dispensed-summary`'s shape instead. Removed the now-unused `prescriptionDrug`, `prescriptionPatientCount`, `prescriptionNumberOfDoses` labels from `csv/report_translations_standard.csv`. |
| 2026-10-15 | Maui team | MAUI-7011: every AC is now asserted by a unit test (AC-005 added for BL-004), each confirmed to fail when its clause is broken. BL-003, BL-004, BL-005 and BL-009 gained code anchors. |

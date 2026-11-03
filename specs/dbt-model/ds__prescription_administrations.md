# dbt Model Spec: `ds__prescription_administrations`

## Identity

| Field | Value |
|---|---|
| **Name** | `medication_administration_records`, `medication_administration_record_doses` (bases) + `ds__prescription_administrations` / `ds__sensitive_prescription_administrations` (datasets) |
| **Type** | dbt model |
| **Layer** | `base` + `ds` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7084](https://linear.app/bes/issue/MAUI-7084/tamanu-report-new-thrombolytic-administration-tenecteplase-alteplase) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-03 |
| **Last updated** | 2026-11-03 |

## Purpose

**Why does this model exist?** Tamanu records what was prescribed (`prescriptions`) separately from what was given: the medication administration record (MAR, `medication_administration_records`) holds each scheduled administration and its status, and `medication_administration_record_doses` holds each dose actually given. The package modelled both only as raw sources, so no report could show a prescription next to its administrations. This adds a base for each and a dataset joining them to the prescription.

**Who consumes it?** The standard `medication-administration-record-line-list` report (MAUI-7084, requested by Nauru). Any report that needs prescription-with-administration detail can reuse it.

**Business context:** clinical audit of medication use, where a prescription with no administration is as informative as one with.

## Grain

**One row per prescription per MAR record per dose given.**

- A prescription with no MAR record yields one row with every `administration_*` / `administered_*` column null.
- A MAR record with no dose (not given, or not yet recorded) yields one row with the dose columns null.
- A MAR record with N doses yields N rows.

A prescription is reached through `encounter_prescriptions`, so a prescription shared by several encounters yields a row per encounter (as in `ds__encounter_prescriptions`).

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('encounter_prescriptions') }}` | Anchors each prescription to an encounter |
| `{{ ref('encounters') }}`, `{{ ref('patients') }}` | Encounter type, department, location, patient demographics |
| `{{ ref('prescriptions') }}` | Dose, route, prescriber, notes |
| `{{ ref('medication_administration_records') }}` | New base: administration status and schedule |
| `{{ ref('medication_administration_record_doses') }}` | New base: each dose given, when and by whom |
| `{{ ref('reference_data') }}` | Medication code and name |
| `{{ ref('locations') }}`, `{{ ref('facilities') }}`, `{{ ref('departments') }}` | Location, facility (sensitivity split), department names |
| `{{ ref('users') }}` | Prescriber and dose-giver display names |

### Required input columns

| Upstream | Columns used |
|---|---|
| `medication_administration_records` (source) | `id`, `prescription_id`, `status`, `due_at`, `recorded_at`, `recorded_by_user_id`, `reason_not_given_id`, `changing_status_reason`, `is_auto_generated`, `is_error`, `error_notes`, `deleted_at` |
| `medication_administration_record_doses` (source) | `id`, `mar_id`, `dose_index`, `dose_amount`, `given_time`, `given_by_user_id`, `recorded_by_user_id`, `reason_for_change`, `is_removed`, `deleted_at` |
| `prescriptions` (base) | `id`, `datetime`, `medication_id`, `prescriber_id`, `is_variable_dose`, `dose_amount`, `dosing_unit`, `route`, `notes` (new) |
| `encounters` | `id`, `patient_id`, `encounter_type`, `department_id`, `location_id` |

### Freshness expectations

Bases refreshed within 24 hours.

## Output schema

Both datasets expose the same columns. Types and descriptions are in the model `.yml` files.

| Column | Description |
|---|---|
| `encounter_id`, `prescription_id`, `administration_id`, `administration_dose_id` | Keys; `administration_id` is null without a MAR record, `administration_dose_id` without a dose |
| `datetime` | Prescription date/time |
| `patient_id`, `display_id`, `first_name`, `last_name`, `date_of_birth`, `sex` | Patient |
| `encounter_type`, `department_id`, `department`, `location_id`, `location`, `facility_id`, `facility` | Encounter context |
| `medication_id`, `medication_code`, `medication` | Prescribed medication |
| `prescriber_id`, `prescriber`, `is_variable_dose`, `dose_amount`, `dosing_unit`, `route`, `prescription_notes` | Prescription detail |
| `administration_status`, `administration_due_datetime`, `administration_recorded_datetime`, `administration_notes` | MAR record |
| `administration_dose_index`, `administered_dose_amount`, `administered_datetime`, `administered_by_id`, `administered_by` | Dose given |

## Business logic

- **BL-001:** The MAR base excludes soft-deleted MAR records and records whose prescription is soft-deleted (`deleted_at is null`).
- **BL-002:** The MAR base excludes MAR records on a prescription that belongs to an encounter of the test patient (`var("test_patient")`).
- **BL-003:** The dataset keeps prescriptions without any MAR record, by left-joining the base.
- **BL-004:** MAR records with `is_error = true` are not joined; they were entered in error. A prescription whose only records are errors therefore appears as a prescription with no administration.
- **BL-005:** The dataset has one row per dose given, and `administered_datetime` is the dose's `given_time`. A MAR record with no dose keeps one row with the dose columns null.
- **BL-006:** `department` and `location` are the encounter's current department and location. Neither the MAR record nor the dose records where a dose was given.
- **BL-007:** The standard dataset includes only facilities with `is_sensitive = false`, the sensitive dataset only `is_sensitive = true`, by the location's facility.
- **BL-008:** `prescriber` is null when the prescription has no prescriber (left join).
- **BL-009:** The prescriptions base now exposes `notes`.
- **BL-010:** The doses base excludes soft-deleted doses, doses marked removed (`is_removed`), doses whose MAR record or prescription is soft-deleted, and doses of the test patient.
- **BL-011:** `administered_by` is the user who gave the dose (`given_by_user_id`), not the user who recorded it.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | A prescription with no MAR record appears once with null administration columns | BL-003 | Unit test `test_ds__prescription_administrations_grain` |
| AC-002 | No row has an `administration_id` belonging to an `is_error` record | BL-004 | Unit test `test_ds__prescription_administrations_grain` |
| AC-003 | No row appears in both the standard and sensitive datasets | BL-007 | Unit test `test_ds__prescription_administrations_grain` (sensitive-facility prescription excluded from standard) |
| AC-004 | Both datasets compile and run against the release database | all | `dbt compile` + read-only smoke run |
| AC-005 | A MAR record with two doses yields two rows, each with its own `given_time` and giver; a MAR record with no dose yields one row with null dose columns | BL-005, BL-011 | Unit test `test_ds__prescription_administrations_grain` |
| AC-006 | A removed dose is excluded from the doses base | BL-010 | Unit test `test_medication_administration_record_doses_excludes_removed` |

## Lineage

```
encounter_prescriptions ───────────────────┐
prescriptions ─────────────────────────────┤
medication_administration_records (new) ───┼─►  ds__prescription_administrations ───────────►  medication-administration-record-line-list
medication_administration_record_doses (new)┤
encounters/patients/...  ──────────────────┘   ds__sensitive_prescription_administrations ─►  sensitive-medication-administration-record-line-list
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-03 | Maui team | Initial spec |

# dbt Model Spec: `ds__prescription_administrations`

## Identity

| Field | Value |
|---|---|
| **Name** | `medication_administration_records` (base) + `ds__prescription_administrations` / `ds__sensitive_prescription_administrations` (datasets) |
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

**Why does this model exist?** Tamanu records what was prescribed (`prescriptions`) separately from what was given (`medication_administration_records`, the MAR). The package modelled the MAR only as a raw source, so no report could show a prescription next to its administrations. This adds the MAR base and a dataset joining the two.

**Who consumes it?** First consumer is the Nauru thrombolytic administration report (`tamanu-dbt-nauru`, MAUI-7084). Any deployment or standard report that needs prescription-with-administration detail can reuse it.

**Business context:** clinical audit of medication use, where a prescription with no administration is as informative as one with.

## Grain

**One row per prescription per MAR record.** A prescription with no MAR record yields exactly one row with every `administration_*`/`administered_*` column null. A prescription with N non-error MAR records yields N rows.

A prescription is reached through `encounter_prescriptions`, so a prescription shared by several encounters yields a row per encounter (as in `ds__encounter_prescriptions`).

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('encounter_prescriptions') }}` | Anchors each prescription to an encounter |
| `{{ ref('encounters') }}`, `{{ ref('patients') }}` | Encounter type, department, location, patient demographics |
| `{{ ref('prescriptions') }}` | Dose, route, prescriber, notes |
| `{{ ref('medication_administration_records') }}` | New base: administration status, times, recorder |
| `{{ ref('reference_data') }}` | Medication code and name |
| `{{ ref('locations') }}`, `{{ ref('facilities') }}`, `{{ ref('departments') }}` | Location, facility (sensitivity split), department names |
| `{{ ref('users') }}` | Prescriber and administering user display names |
| `{{ source('tamanu', 'medication_administration_records') }}` | Source for the new base |

### Required input columns

| Upstream | Columns used |
|---|---|
| `medication_administration_records` (source) | `id`, `prescription_id`, `status`, `due_at`, `recorded_at`, `recorded_by_user_id`, `reason_not_given_id`, `changing_status_reason`, `is_auto_generated`, `is_error`, `error_notes`, `deleted_at` |
| `prescriptions` (base) | `id`, `datetime`, `medication_id`, `prescriber_id`, `dose_amount`, `dosing_unit`, `route`, `notes` (new) |
| `encounters` | `id`, `patient_id`, `encounter_type`, `department_id`, `location_id` |

### Freshness expectations

Bases refreshed within 24 hours.

## Output schema

Both datasets expose the same columns. Types and descriptions are in the model `.yml` files.

| Column | Description |
|---|---|
| `encounter_id`, `prescription_id`, `administration_id` | Keys; `administration_id` is null without a MAR record |
| `datetime` | Prescription date/time |
| `patient_id`, `display_id`, `first_name`, `last_name`, `date_of_birth`, `sex` | Patient |
| `encounter_type`, `department_id`, `department`, `location_id`, `location`, `facility_id`, `facility` | Encounter context |
| `medication_id`, `medication_code`, `medication` | Prescribed medication |
| `prescriber_id`, `prescriber`, `is_variable_dose`, `dose_amount`, `dosing_unit`, `route`, `prescription_notes` | Prescription detail |
| `administration_status`, `administration_due_datetime`, `administered_datetime`, `administered_by_id`, `administered_by`, `administration_notes` | Administration detail |

## Business logic

- **BL-001:** The base excludes soft-deleted MAR records and records whose prescription is soft-deleted (`deleted_at is null`).
- **BL-002:** The base excludes MAR records on a prescription that belongs to an encounter of the test patient (`var("test_patient")`).
- **BL-003:** The dataset keeps prescriptions without any MAR record, by left-joining the base.
- **BL-004:** MAR records with `is_error = true` are not joined; they were entered in error. A prescription whose only records are errors therefore appears as a prescription with no administration.
- **BL-005:** `administered_datetime` is the MAR `recorded_at`, i.e. when the status was recorded. It is null while a scheduled dose has no status yet; the row's `administration_status` is then also null.
- **BL-006:** `department` and `location` are the encounter's current department and location. The MAR does not record where a dose was given, so this is an approximation of "at time of administration".
- **BL-007:** The standard dataset includes only facilities with `is_sensitive = false`, the sensitive dataset only `is_sensitive = true`, by the location's facility.
- **BL-008:** `prescriber` is null when the prescription has no prescriber (left join).
- **BL-009:** The prescriptions base now exposes `notes`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | A prescription with no MAR record appears once with null administration columns | BL-003 | Manual check / unit test (follow-up) |
| AC-002 | No row has an `administration_id` belonging to an `is_error` record | BL-004 | Manual check / singular test (follow-up) |
| AC-003 | No row appears in both the standard and sensitive datasets | BL-007 | Manual check |
| AC-004 | Both datasets compile and build against the release database | all | `dbt build` |

## Lineage

```
encounter_prescriptions ─┐
prescriptions ───────────┤
medication_administration_records (new) ─┼─►  ds__prescription_administrations ─►  Nauru: thrombolytic-administration-line-list
encounters/patients/...  ┘                └►  ds__sensitive_prescription_administrations
```

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Should `administered_datetime` instead be the dose's `given_time` from `medication_administration_record_doses`? The MAR-level `recorded_at` was used because the ticket says "from the MAR" and a MAR can hold several doses. | Maui team | |
| OQ-002 | Add dbt unit tests for AC-001/AC-002 before release? | Maui team | |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-03 | Maui team | Initial draft |

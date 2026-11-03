# Report Spec: `medication-administration-record-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `medication-administration-record-line-list` (display name "Medication administration record line list") + `sensitive-medication-administration-record-line-list` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, sharing `macros/reports/medication_administration_record_line_list.sql` and reading `ds__prescription_administrations` / `ds__sensitive_prescription_administrations` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7084](https://linear.app/bes/issue/MAUI-7084/tamanu-report-new-thrombolytic-administration-tenecteplase-alteplase) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-03 |

## Purpose

**Why does this report exist?** Clinical review and audit of the use of specific medications: for each prescription of the chosen drugs, who prescribed it, the dose and route, and whether, when and by whom its administration was recorded.

**Who consumes it?** Clinical, pharmacy and IT staff at any deployment, through the Tamanu reports UI.

**Business context:** requested by Nauru (NMC) for thrombolytics: Inj. Alteplase (`drug-Inj900`) and Inj. Tenecteplase (`drug-Inj901`), from 01/04/2026 to date on first run. The report is generic so every deployment can audit any set of drugs.

## Grain

One row per prescription per medication administration record (MAR), from the dataset (see `specs/dbt-model/ds__prescription_administrations.md`). A prescription with no MAR record is one row with blank administration columns.

## Inputs

### Parameters

| Name | Field | Filters on |
|---|---|---|
| `fromDate` / `toDate` | date range (default 30 days) | Prescription date |
| `facilityId` | `FacilityField` | Encounter location's facility |
| `medicationId` | `ParameterSuggesterSelectField`, `drug`, `isMulti` | Prescribed medication, any number of drugs |
| `departmentId` | autocomplete `department` | Encounter department |
| `locationId` | autocomplete `location` | Encounter location |

### Upstream models

| Reference | Why we need it |
|---|---|
| `{{ ref('ds__prescription_administrations') }}` / `{{ ref('ds__sensitive_prescription_administrations') }}` | Prescription, patient, encounter and MAR detail, split by facility sensitivity |

## Output schema

Patient ID, First name, Last name, Date of birth, Sex, Medication, Prescribed date, Prescribed by, Dose, Route, Administered date and time, Administered by, Administration status, Department, Location, Facility, Encounter type, Notes.

## Business logic

- **BL-001:** The report covers every medication; it hard-codes no drug list.
- **BL-002:** The date range filters on the prescription date: every prescription exists, not all are administered.
- **BL-003:** The medication filter is a multi-select over all drugs (`isMulti`) and is optional; when empty, every medication is returned. The selection reaches SQL as a list, so the empty check uses `coalesce(...)`.
- **BL-004:** Facility, department and location filters are optional.
- **BL-005:** Prescribed by is blank when no prescriber was recorded.
- **BL-006:** Dose is the prescription's dose amount and dosing unit, or `Variable` for a variable-dose prescription.
- **BL-007:** Administration columns come from the MAR record and are blank for a prescription with none. MAR records marked as entered in error are excluded by the dataset.
- **BL-008:** Notes joins the prescription note and the administration status-change note with ` | `, omitting blanks.
- **BL-009:** Ordered by prescription date descending, then prescription, scheduled time and administration time, so the order is stable.
- **BL-010:** Administration status is `Given`, `Not given`, or `Not recorded` for a MAR record whose status is not yet set (a scheduled dose). The MAR has no "refused" status; refusal is recorded as not given with a reason.
- **BL-011:** Department and location are the encounter's current values, not the values at administration time, because the MAR does not record where a dose was given.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | Selecting two drugs returns rows for exactly those drugs; selecting none returns all medications | BL-001, BL-003 | Manual check on a demo server |
| AC-002 | A prescription with no MAR record appears once with blank administration columns | BL-007 | Manual check |
| AC-003 | Standard and sensitive variants return disjoint rows | dataset BL-007 | Manual check |
| AC-004 | Configs validate and every label resolves | all | `validate_report_configs.py`, `check_translations.py` |

## Risks

- `isMulti` is a Tamanu web prop passed through by the report form rather than a declared report option (see `documentations/tamanu-report-configuration-schema.md`). A Tamanu frontend change could drop it and turn the field back into a single select; the SQL still works with one value.
- With no medication selected and a long date range, the report lists every prescription; the 30-day default keeps the first run bounded.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Is the encounter's current department/location acceptable in place of the location at administration (BL-011)? | Maui team | |
| OQ-002 | Should "Administered date and time" be the dose `given_time` from `medication_administration_record_doses` instead of the MAR recorded time? | Maui team | |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-03 | Maui team | Initial draft |

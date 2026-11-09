# Report Spec: `recent-diagnoses-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `recent-diagnoses-line-list` + `sensitive-recent-diagnoses-line-list` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading `ds__diagnoses` / `ds__sensitive_diagnoses` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Lists the patients who had any of the chosen diagnoses recorded in a date range, with their contact details, village, clinician and department, for follow-up and surveillance. Consumed by clinical and public-health staff through the Tamanu reports UI. The sensitive variant covers sensitive facilities only.

## Grain

One row per recorded encounter diagnosis. Disproven and recorded-in-error diagnoses are excluded by the `encounter_diagnoses` base.

## Inputs

### Parameters

| Name | Field | Filters on |
|---|---|---|
| `fromDate` / `toDate` | date range (default 24 hours) | Diagnosis date and time |
| `facilityId` | `FacilityField` | Encounter location's facility |
| `villageId` | `VillageField` | Patient village |
| `diagnosisId` | `ParameterSuggesterSelectField`, `diagnosis`, `isMulti` | Diagnosis, any number of diagnoses |
| `clinicianId` | autocomplete `practitioner` | Encounter clinician |

## Business logic

- **BL-001:** The date range filters on the diagnosis date and time in the viewer's timezone.
- **BL-002:** Facility, village and clinician filters are each optional.
- **BL-003:** The diagnosis filter is a multi-select that returns a row when its diagnosis is any of the selected diagnoses, and every diagnosis when none is selected.
- **BL-004:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.
- **BL-005:** Rows are ordered by diagnosis date and time, latest first.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With no diagnosis selected every diagnosis in the window is returned | BL-003 | `test_recent_diagnoses_line_list_no_diagnosis_selected` |
| AC-002 | With one diagnosis selected only that diagnosis is returned, in both variants | BL-003 | `test_recent_diagnoses_line_list_one_diagnosis_selected`, `test_recent_diagnoses_line_list_sensitive_one_selected` |
| AC-003 | The compiled SQL binds `diagnosisId` through an array constructor and references no other diagnosis parameter | BL-004 | Inspect `dbt compile` output. Unit tests bind a single value, so selections of several values are not exercised |

## Risks

- `isMulti` is a Tamanu web prop passed through by the report form rather than a declared report option (see `documentations/tamanu-report-configuration-schema.md`). A frontend change could turn the field back into a single select; the SQL still works with one value.
- The field lists every diagnosis in one dropdown, so a very large diagnosis list can make it slow to use.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which replaced the five diagnosis filters with one multi-select. |

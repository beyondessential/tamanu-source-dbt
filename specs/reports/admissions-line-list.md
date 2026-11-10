# Report Spec: `admissions-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `admissions-line-list` + `sensitive-admissions-line-list` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading `ds__admissions` / `ds__sensitive_admissions` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Lists the patients admitted in the selected range, with their admission, location and diagnosis details, for hospital staff. The sensitive variant covers sensitive facilities only.

Only the multi-select filters are numbered here. The rest of the report is described as built.

## Inputs

### Parameters

| Name | Field | Label |
|---|---|---|
| `facilityId` | `FacilityField` | Facility |
| `patientBillingTypeId` | `ParameterSuggesterSelectField, `patientBillingType`, multi-select` | Patient billing type |
| `clinicianId` | `ParameterAutocompleteField, `practitioner`` | Admitting clinician |
| `locationGroupId` | `ParameterAutocompleteField, `locationGroup`` | Area |
| `departmentId` | `ParameterAutocompleteField, `department`` | Department |
| `admissionStatus` | `ParameterMultiselectField` | Admission status |
plus the date range.

## Business logic

- **BL-001:** The patient billing type filter is a multi-select that returns a row when its billing type is any of the selected values, and every row when none is selected.
- **BL-002:** The admission status filter is a multi-select that returns a row when its admission status is any of the selected values, and every row when none is selected.
- **BL-003:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With one or several billing types selected only rows with those billing types are returned, in both variants | BL-001 | `test_admissions_line_list_billing_type_one_selected`, `test_admissions_line_list_billing_type_two_selected`, `test_admissions_line_list_sensitive_billing_type_one`, `test_admissions_line_list_sensitive_billing_type_two` |
| AC-003 | With an empty selection every row is returned | BL-001, BL-003 | `test_admissions_line_list_billing_type_empty_list` |
| AC-002 | The compiled SQL binds both filters through an array constructor | BL-003 | Inspect `dbt compile` output |

## Risks

- No test selects an admission status. The same expression is tested on the billing type filter.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which made the patient billing type filter a multi-select. |

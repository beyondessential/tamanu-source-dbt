# Report Spec: `imaging-requests-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `imaging-requests-line-list` + `sensitive-imaging-requests-line-list` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading `ds__imaging_requests` / `ds__sensitive_imaging_requests` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Lists the patients with an imaging request created in the selected range, with the details of each request, for imaging and clinical staff. The sensitive variant covers sensitive facilities only.

Only the status filter is numbered here; the rest of the report is described as built.

## Inputs

### Parameters

| Name | Field | Label |
|---|---|---|
| `facilityId` | `ParameterAutocompleteField`, `facility` | Facility |
| `requestedById` | `ParameterAutocompleteField`, `practitioner` | Requesting clinician |
| `statusId` | `ParameterMultiselectField` | Status |
| `imagingType` | `ImagingTypeField` | Imaging type |
plus the date range.

## Business logic

- **BL-001:** The status filter is a multi-select that returns a row when its imaging request's status is any of the selected values, and every row when none is selected. The options are `pending`, `in_progress`, `completed`, `cancelled`, `deleted`, `entered_in_error`.
- **BL-002:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With nothing selected every row in scope is returned | BL-001, BL-002 | `test_imaging_requests_line_list_status_none`, `test_imaging_requests_line_list_status_empty_list` |
| AC-002 | With one or two values selected only rows with those values are returned, in both variants | BL-001 | `test_imaging_requests_line_list_status_one`, `test_imaging_requests_line_list_status_two_selected`, `test_imaging_requests_line_list_status_sensitive_one`, `test_imaging_requests_line_list_status_sensitive_two` |
| AC-003 | The compiled SQL binds the filter through an array constructor | BL-002 | Inspect `dbt compile` output|

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which made the status filter a multi-select. |

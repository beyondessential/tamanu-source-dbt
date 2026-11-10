# Report Spec: `lab-requests-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `lab-requests-line-list` + `sensitive-lab-requests-line-list` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading `ds__lab_requests` / `ds__sensitive_lab_requests` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Lists the patients with a lab request created in the selected range, with the details of each request, for laboratory and clinical staff. The sensitive variant covers sensitive facilities only.

Only the status filter is numbered here; the rest of the report is described as built.

## Inputs

### Parameters

| Name | Field | Label |
|---|---|---|
| `requestedById` | `PractitionerField` | Requesting clinician |
| `testCategoryId` | `LabTestCategoryField` | Test category |
| `statusId` | `ParameterMultiselectField` | Status |
plus the date range.

## Business logic

- **BL-001:** The status filter is a multi-select that returns a row when its lab request's status is any of the selected values, and every row when none is selected. The options are `reception_pending`, `results_pending`, `to_be_verified`, `verified`, `published`, `cancelled`, `deleted`, `sample-not-collected`, `entered-in-error`.
- **BL-002:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With nothing selected every row in scope is returned | BL-001, BL-002 | `test_lab_requests_line_list_status_none` |
| AC-002 | With one value selected only rows with that value are returned, in both variants | BL-001 | `test_lab_requests_line_list_status_one`, `test_lab_requests_line_list_status_sensitive_one` |
| AC-003 | The compiled SQL binds the filter through an array constructor | BL-002 | Inspect `dbt compile` output. Unit tests bind a single value, so a selection of several values is not exercised |

## Risks

- A selection of several values reaches SQL as a list that unit tests cannot set. The array expression is the same one used by `medication-administration-record-line-list`.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which made the status filter a multi-select. |

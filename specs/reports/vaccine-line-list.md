# Report Spec: `vaccine-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `vaccine-line-list` + `sensitive-vaccine-line-list` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading `ds__vaccinations` / `ds__sensitive_vaccinations` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Lists the vaccinations given or not given in the selected range, with the patient and vaccine details, for immunisation and clinical staff. The sensitive variant covers sensitive facilities only.

Only the multi-select filters are numbered here. The rest of the report is described as built.

## Inputs

### Parameters

| Name | Field | Label |
|---|---|---|
| `facilityId` | `FacilityField` | Facility |
| `villageId` | `ParameterSuggesterSelectField, `village`, multi-select` | Village |
| `category` | `VaccineCategoryField` | Category |
| `vaccine` | `VaccineField` | Vaccine |
plus the date range.

## Business logic

- **BL-001:** The village filter is a multi-select that returns a row when its patient's village is any of the selected values, and every row when none is selected.
- **BL-002:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With one village selected only rows for that village are returned, in both variants | BL-001 | `test_vaccine_line_list_village_one_selected`, `test_vaccine_line_list_sensitive_village_one_selected` |
| AC-002 | The compiled SQL binds the filter through an array constructor | BL-002 | Inspect `dbt compile` output. Unit tests bind a single value, so a selection of several values is not exercised |

## Risks

- A selection of several values reaches SQL as a list that unit tests cannot set. The array expression is the same one used by `medication-administration-record-line-list`.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which made the village filter a multi-select. |

# Report Spec: `upcoming-vaccinations-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `upcoming-vaccinations-line-list` |
| **Type** | Tamanu report, standard report in `models/reports/`, reading `ds__patient_vaccinations_upcoming` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Lists the vaccinations that are due or overdue, with the patient and vaccine details, so staff can follow up.

Only the multi-select filters are numbered here. The rest of the report is described as built.

## Inputs

### Parameters

| Name | Field | Label |
|---|---|---|
| `category` | `VaccineCategoryField` | Category |
| `vaccine` | `VaccineField` | Vaccine |
| `status` | `ParameterSelectField` | Vaccine status |
| `villageId` | `ParameterSuggesterSelectField`, `village`, multi-select | Village |
| `excludeNonHomeCountry` | `ParameterSelectField` | Exclude overseas patients (default No) |
plus the date range.

## Business logic

- **BL-001:** The village filter is a multi-select that returns a row when its patient's village is any of the selected values, and every row when none is selected.
- **BL-002:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With one or two villages selected only the patients in those villages are returned | BL-001 | `test_upcoming_vaccinations_village_one_selected`, `test_upcoming_vaccinations_village_two_selected` |
| AC-002 | With an empty selection every patient is returned | BL-001, BL-002 | `test_upcoming_vaccinations_village_empty_list` |
| AC-003 | The compiled SQL binds the village filter through an array constructor | BL-002 | Inspect `dbt compile` output |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which made the village filter a multi-select. |

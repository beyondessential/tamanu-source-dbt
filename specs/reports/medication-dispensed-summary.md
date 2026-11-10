# Report Spec: `medication-dispensed-summary`

## Identity

| Field | Value |
|---|---|
| **Name** | `medication-dispensed-summary` + `sensitive-medication-dispensed-summary` |
| **Type** | Tamanu report, standard + sensitive pair in `models/reports/`, reading `ds__medication_dispenses` / `ds__sensitive_medication_dispenses` (see `specs/dbt-model/ds__medication_dispenses.md`) |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7088](https://linear.app/bes/issue/MAUI-7088/tamanu-reports-replace-repeated-filters-with-a-multi-select) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-10 |

## Purpose

Totals the quantity of each medication that pharmacy dispensed in a date range, from the dispense records, for stock and pharmacy reporting. Deployments that do not use the dispensing workflow use `encounter-prescription-discharge-summary` instead.

## Grain

One row per medication, summed over every dispense in the date range and filters.

## Inputs

### Parameters

| Name | Field | Filters on |
|---|---|---|
| `fromDate` / `toDate` | date range (default 30 days) | Dispense date and time |
| `facilityId` | `FacilityField` | Facility of the dispense's encounter |
| `medicationId` | `ParameterSuggesterSelectField`, `drug`, `isMulti` | Dispensed medication, any number of drugs |

## Business logic

- **BL-001:** The date range filters on the dispense date and time in the viewer's timezone.
- **BL-002:** The facility filter is optional.
- **BL-003:** The medication filter is a multi-select that returns the selected drugs, and every medication when none is selected.
- **BL-004:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.
- **BL-005:** The output is one row per medication with its name, code and summed quantity, using the labels shared with `encounter-prescription-discharge-summary`.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With no drug selected every dispensed medication is summed | BL-003, BL-005 | `test_medication_dispensed_summary_no_medication_selected` |
| AC-002 | With one drug selected only that medication is returned, in both variants | BL-003 | `test_medication_dispensed_summary_one_medication_selected`, `test_medication_dispensed_summary_sensitive_one_selected` |
| AC-003 | The compiled SQL binds `medicationId` through an array constructor | BL-004 | Inspect `dbt compile` output. Unit tests bind a single value, so selections of several values are not exercised |

## Risks

- `isMulti` is a Tamanu web prop passed through by the report form rather than a declared report option (see `documentations/tamanu-report-configuration-schema.md`). A frontend change could turn the field back into a single select; the SQL still works with one value.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-10 | Maui team | Retrospective spec, written with MAUI-7088, which made the drug filter a multi-select. |

# Report Spec: `report-facility-options`

## Purpose

A Tamanu user runs a report for "This facility" or "All facilities". This spec fixes, for the standard reports below, which of the two each report offers and how a report offering "This facility" limits its rows to a facility, so that a report never returns another facility's records under "This facility" and never returns an incomplete result under "All facilities".

## Identity

| Field | Value |
|---|---|
| **Name** | `report-facility-options` |
| **Type** | Tamanu report configuration, standard reports in `models/reports/` |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | MAUI-7249, under MAUI-7221 |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-27 |

## Inputs

### Parameters

| Report | Facility parameter | Filters on |
|---|---|---|
| `lab-requests-line-list` | `facilityId`, `FacilityField` | `ds__lab_requests.facility_id` |
| `lab-tests-line-list` | `facilityId`, `FacilityField` | `ds__lab_tests.facility_id` |
| `patient-emergency-encounters-summary` | `facilityId`, `FacilityField` | `ds__encounters_emergency.facility_id` |
| `incomplete-referrals` | `facilityId`, `FacilityField` | `ds__referrals.facility_id` |
| `program-registry-line-list` | `facilityId`, `FacilityField` | `ds__patient_program_registrations.registering_facility_id` |
| `program-registry-removed-patients-line-list` | `facilityId`, `FacilityField` | `ds__patient_program_registrations.registering_facility_id` |
| `imaging-requests-line-list` | `facilityId`, `ParameterSuggesterSelectField`, `facility`, multi-select | `ds__imaging_requests.facility_id` |
| `vaccine-audit-line-list` | `facilityId`, `ParameterSuggesterSelectField`, `facility`, multi-select | `ds__vaccinations.facility_id` |

## Business logic

- **BL-001:** A report that offers "This facility" has an optional facility parameter that limits its rows to the selected facility, and leaves every facility's rows when none is selected.
- **BL-002:** The lab requests, lab tests, patient emergency encounters and incomplete referrals reports filter on the facility of the encounter's location, as their datasets expose it.
- **BL-003:** The program registry and program registry removed patients reports filter on the facility where the patient was registered.
- **BL-004:** The registered patients, registered patients by date of birth, patient details edit audit, usage quality metrics (patient details), usage quality metrics (patient registrations) and upcoming vaccinations reports offer "All facilities" only.

- **BL-005:** The imaging requests and vaccine audit reports take several facilities in one multi-select, returning a row when its facility is any of the selected values and every row when none is selected.
- **BL-006:** The selection reaches SQL as a list that is empty when nothing is selected, so the filter goes through an array constructor, which stays valid when empty.

### Why a report offers "All facilities" only

- Registered patients and registered patients by date of birth list patients, who sync to every facility, with no facility link.
- The patient details edit audit reads change-log rows that carry no facility.
- The usage quality metrics reports count the whole server.
- The upcoming vaccinations report lists every patient on a facility server but holds vaccination history only for the patients marked for sync there, so the other patients show vaccines they have already had as due.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | With a facility selected only that facility's rows are returned | BL-001, BL-002, BL-003 | `test_lab_requests_line_list_facility_filter_selected`, `test_lab_tests_line_list_facility_filter_selected`, `test_emergency_summary_facility_filter_selected`, `test_incomplete_referrals_facility_filter_selected`, `test_program_registry_line_list_facility_filter_selected`, `test_registry_removed_line_list_facility_filter_selected` |
| AC-002 | With no facility selected every facility's rows are returned | BL-001 | `test_lab_requests_line_list_facility_filter_blank`, `test_lab_tests_line_list_facility_filter_blank`, `test_emergency_summary_facility_filter_blank`, `test_incomplete_referrals_facility_filter_blank`, `test_program_registry_line_list_facility_filter_blank`, `test_registry_removed_line_list_facility_filter_blank` |
| AC-004 | With two of three facilities selected only the rows of those two are returned | BL-005 | `test_imaging_requests_line_list_facility_two_selected`, `test_vaccine_audit_line_list_facility_two_selected` |
| AC-005 | An empty selection returns every facility's rows | BL-005, BL-006 | `test_imaging_requests_line_list_facility_empty_list`, `test_vaccine_audit_line_list_facility_empty_list` |
| AC-003 | Each report in BL-004 declares `allFacilities` as its only data source | BL-004 | `test_ac_003_report_offers_all_facilities_only` in `scripts/tests/test_report_data_sources.py` |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-27 | Maui team | Spec written with MAUI-7249. |

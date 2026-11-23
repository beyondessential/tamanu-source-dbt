# dbt Spec: sensitive facility partition (shared rule)

## Purpose

Tamanu puts some facilities in sensitive networks, and data recorded at a facility in a network
must reach only the reports, models and Tupaia data tables built for that network. Every
facility-attributed base splits into one standard partition and one partition per sensitive
network, and every model downstream inherits its partition from what it reads. This package ships
the standard models and the body macros; each deployment lists its sensitive networks and
generates the models for each one.

**Who consumes it?** Every base, dataset, report, `clinical__` and package `metric__` model, the
deployment repos that generate per-network models, and the Tupaia data tables built on them. Each
model's own spec keeps its other clauses. This spec owns which partition a row belongs to and
which partitions each layer reads.

## Identity

| Field | Value |
|---|---|
| **Name** | sensitive facility partition |
| **Type** | shared rule across dbt models, with a model generator |
| **Layer** | `bases/`, `ds__`, reports, `clinical__`, `metric__`, `models/intermediate/omop/`, `ref__care_site`, `ref__care_site_location` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7220](https://linear.app/bes/issue/MAUI-7220/split-standard-and-sensitive-facilities-at-the-base-models) |
| **Repo** | `tamanu-source-dbt` (macros, standard models, generator), `tamanu-dbt-<deployment>` (per-network models) |
| **Created** | 2026-11-23 |
| **Last updated** | 2026-11-23 |

## Partitions and naming

A deployment lists its sensitive networks by `sensitive_networks.code` in the var
`sensitive_networks`; an empty list, the default, means it has none. Each listed network has a
key, its code lowercased with every run of non-alphanumerics replaced by `_`.

| Layer | Standard model | Model for network `<key>` |
|---|---|---|
| Base | `encounters` | `sensitive_<key>_encounters` |
| Dataset | `ds__admissions` | `ds__sensitive_<key>_admissions` |
| Report | `admissions-line-list` | `sensitive-<key>-admissions-line-list` |
| OMOP | `clinical__visit_occurrence` | `clinical__sensitive_<key>_visit_occurrence` |
| Metric | `metric__program_registry_enrolment` | `metric__sensitive_<key>_program_registry_enrolment` |

## Split bases

The link column decides a row's facility.

| Link | Bases |
|---|---|
| Own facility | `facilities`, `locations`, `location_groups`, `departments`, `patient_facilities`, `user_facilities`, `patients_access_logs`, `patient_death_data`, `patient_birth_data` (birth facility), `patient_program_registrations` (registering facility) |
| Own location or location group | `location_bookings`, `outpatient_appointments` |
| Encounter, by its current location | `encounters` |
| An encounter, directly or through a parent record | `discharges`, `document_metadata`, `encounter_diagnoses`, `encounter_diets`, `encounter_history`, `encounter_prescriptions`, `imaging_requests`, `imaging_request_areas`, `imaging_results`, `invoices` and every `invoice_*` base carrying `invoice_id`, `invoices_invoice_insurance_plans`, `lab_requests`, `lab_tests`, `lab_test_panel_requests`, `lab_request_logs`, `medication_administration_records`, `medication_administration_record_doses`, `medication_dispenses`, `pharmacy_orders`, `pharmacy_order_prescriptions`, `prescriptions`, `procedures`, `referrals`, `survey_responses`, `survey_response_answers`, `tasks`, `triages`, `vaccine_administrations`, `notes` |
| Another split base's record | `contributing_death_causes` and `patient_death_contributing_causes` (death record), `patient_program_registration_conditions` (registration), `outpatient_appointments_change_logs` (appointment) |
| The record it describes | every `*_change_logs` and `*_metadata` base whose record is in a split base |

Every other base, such as `patients`, `patient_additional_data`, `reference_data`, `users` and
the survey and product definitions, is not split.

## Business logic

### Partition

- **BL-001:** A facility is in the partition of its sensitive network, and in the standard partition when it belongs to none.
- **BL-002:** A split base's standard model holds its standard rows and each network's model that network's rows.
- **BL-003:** A row whose link is null, or resolves to no facility, is standard.
- **BL-004:** An encounter's partition is that of its current location's facility.
- **BL-005:** A row attached to an encounter, directly or through a parent record, takes that encounter's partition, even where the row records a location of its own.
- **BL-006:** A prescription takes the partition of the encounter it is prescribed in, and an ongoing prescription with no encounter is standard.
- **BL-007:** A note on an encounter, triage, lab request or imaging request takes that encounter's partition, and a note on a patient or care plan is standard.
- **BL-008:** A change-log or metadata base takes the partition of the record it describes, as that record is now.
- **BL-009:** On an incremental target, a row whose partition changes only through its parent moves at the next full refresh.
- **BL-010:** A row at a facility whose sensitive network is not in `sensitive_networks` is in no model.

### Package and generator

- **BL-011:** Each split model's body is one macro taking the partition, `none` for standard or a network code, and the standard model calls it with `none`.
- **BL-012:** The package's generator writes, for each network in the deployment's `sensitive_networks`, a model file calling the body macro with that network's code, and a property file copying the standard model's with the name changed, for every model the package marks as partitioned.
- **BL-013:** A deployment commits its generated files, and its CI fails when regenerating them changes anything.
- **BL-014:** A model that reads every partition unions its standard input with each listed network's, through one shared macro.

### Datasets and reports

- **BL-015:** A partitioned model reads the inputs of its own partition only.
- **BL-016:** A dataset or report with no per-network models reads the standard partition only, except `ds__deaths` and `user-login-activity`, which read every partition.
- **BL-025:** A network's reports are their own report definitions, which a role runs only with `run` permission on them.

### OMOP layer

- **BL-017:** `clinical__visit_occurrence`, `clinical__visit_detail`, `clinical__condition_occurrence`, `clinical__drug_exposure`, `clinical__measurement`, `clinical__observation`, `clinical__procedure_occurrence`, `clinical__cost` and `clinical__episode` are partitioned.
- **BL-018:** `clinical__person` covers every patient, and `clinical__observation_period` covers visits in every partition.
- **BL-019:** `ref__care_site` and `ref__care_site_location` cover every partition's facilities.

### Metrics

- **BL-020:** A `metric__` model classified `internal` reads the standard partition only.
- **BL-021:** `metric__birth`, `metric__death`, `metric__immunisation_dose`, `metric__immunisation_refusal` and `metric__patient_condition` read every partition.
- **BL-022:** `metric__program_registry_enrolment`, `metric__who_dak_anc_indicators` and `metric__who_dak_hiv_indicators` are partitioned.
- **BL-023:** A new package `metric__` model classified `internal` follows BL-020, and one classified `restricted` names BL-021 or BL-022 in its spec.
- **BL-024:** The `is_sensitive` flags on surveys and lab test types play no part in the partition.
- **BL-026:** A network's model of a partitioned metric emits the same `metric_id` as the standard model, and the registry holds one entry for both.

## Acceptance criteria

This repo tests one fixture network, `example`, whose generated models CI writes before
running dbt. Unit-test fixtures hold a row at a standard facility, a row at a facility in the
`example` network, a row at a facility in an unlisted network, and, where the link allows it, a
row with no facility.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | For each link kind (own facility, own location, encounter, encounter child, grandchild, nullable link, change log), the standard base holds the standard and unlinked rows, the `example` base holds the `example` row, and neither holds the unlisted network's row | BL-001 to BL-008, BL-010 | unit test per link kind, on a representative base |
| AC-002 | The generator writes the expected files for a list of networks, and every model marked partitioned has a body macro taking the partition | BL-011, BL-012 | pytest |
| AC-003 | Every sensitive network in the deployment's `sensitive_networks` base is listed in the var | BL-010 | singular data test, severity `error` |
| AC-004 | `encounters` and every network's encounters base together hold every live non-test encounter in a listed partition once | BL-002 | logical integrity data test |
| AC-005 | With no networks listed the project parses, and no standard model depends on a network's model | BL-012, BL-015, BL-020 | CI's standard-only parse |
| AC-006 | `clinical__visit_occurrence` holds the standard encounter and `clinical__sensitive_example_visit_occurrence` the `example` one | BL-017 | unit test |
| AC-007 | `metric__encounter` holds no encounter in a sensitive network | BL-020 | unit test |
| AC-008 | `metric__birth` and `metric__death` keep the `example` row | BL-021 | unit test per model |
| AC-009 | `metric__sensitive_example_program_registry_enrolment` holds the `example` enrolment and `metric__program_registry_enrolment` the standard one | BL-022 | unit test |
| AC-010 | `ref__care_site` holds a care site for the `example` facility | BL-019 | unit test |

## Lineage

```
source ──► <model>_body(none)       ──► <model>                       ──► general reports / data tables
       └─► <model>_body('<code>')   ──► sensitive_<key>_<model>       ──► network reports / permissioned data tables
                                       (generated in the deployment repo, one per listed network)
every partition ──► ds__deaths, user-login-activity, clinical__observation_period, ref__care_site*, metric__birth / death / immunisation_* / patient_condition
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-23 | Maui team | Initial draft: every facility-attributed base splits into a standard partition and one per sensitive network, deployments generate the per-network models, and each layer reads the partitions set here (MAUI-7220). Replaces the analytics facility scope spec drafted in #2155. |

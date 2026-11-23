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
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7220](https://linear.app/bes/issue/MAUI-7220/split-standard-and-sensitive-facilities-at-the-base-models) |
| **Repo** | `tamanu-source-dbt` (macros, standard models, generator), `tamanu-dbt-<deployment>` (per-network models) |
| **Created** | 2026-11-23 |
| **Last updated** | 2026-11-24 |

## Partitions and naming

A deployment lists its sensitive networks by `sensitive_networks.code` in the var
`sensitive_networks`; an empty list, the default, means it has none. Each listed network has a
key, its code lowercased with every run of non-alphanumerics replaced by `_`.

| Layer | Standard model | Model for network `<key>` |
|---|---|---|
| Base | `encounters` | `sn_<key>_encounters` |
| Intermediate | `int__program_enrolments` | `int__sn_<key>_program_enrolments` |
| Dataset | `ds__admissions` | `ds__sn_<key>_admissions` |
| OMOP | `clinical__visit_occurrence` | `clinical__sn_<key>_visit_occurrence` |
| Metric | `metric__program_registry_enrolment` | `metric__sn_<key>_program_registry_enrolment` |
| Report | `admissions-line-list` | `sensitive-<key>-admissions-line-list` |

A relation takes the short `sn_` token because Postgres allows a relation name 63 characters,
and dbt adds 12 to an ephemeral model's. A report's name is not a relation's.

## Split bases

The link column decides a row's facility.

| Link | Bases |
|---|---|
| Own facility | `facilities`, `locations`, `location_groups`, `departments`, `patient_facilities`, `user_facilities`, `patients_access_logs`, `patient_death_data`, `patient_birth_data` (birth facility), `patient_program_registrations` (registering facility) |
| Own location or location group | `location_bookings`, `outpatient_appointments` |
| Encounter, by its current location | `encounters` |
| An encounter, directly or through a parent record | `discharges`, `document_metadata`, `encounter_diagnoses`, `encounter_diets`, `encounter_history`, `encounter_prescriptions`, `imaging_requests`, `imaging_request_areas`, `imaging_results`, `invoices` and every `invoice_*` base carrying `invoice_id`, `invoices_invoice_insurance_plans`, `lab_requests`, `lab_tests`, `lab_test_panel_requests`, `lab_request_logs`, `medication_administration_records`, `medication_administration_record_doses`, `medication_dispenses`, `pharmacy_orders`, `pharmacy_order_prescriptions`, `prescriptions`, `procedures`, `referrals`, `survey_responses`, `survey_response_answers`, `tasks`, `triages`, `vaccine_administrations`, `notes` |
| Another split base's record | `contributing_death_causes` and `patient_death_contributing_causes` (death record), `patient_program_registration_conditions` (registration) |
| The record it describes | `discharges_change_logs`, `invoices_change_logs`, `outpatient_appointments_change_logs`, `vaccine_administrations_change_logs`, `patient_program_registrations_change_logs`, `patient_program_registration_conditions_change_logs`, and the `encounters`, `encounter_diagnoses`, `lab_requests`, `lab_request_logs` and `procedures` metadata bases |

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

- **BL-011:** A partitioned model takes the partition as `network`, `none` for standard or a network's code, through its body macro or a `set network = none` at its head.
- **BL-012:** For each listed network, the package's generator writes a copy of every partitioned model with that network's code as `network`, of its property file, and of a report's config.
- **BL-013:** Generated files are committed, and CI fails when regenerating them changes anything.
- **BL-027:** A generated property file points each test that reads another partitioned model at that network's copy of it.
- **BL-028:** The generator refuses a network code that would give a relation a name longer than Postgres allows.
- **BL-029:** This repo carries the generated models of one fixture network, `example`, enabled only where that network is listed.
- **BL-014:** A model that reads every partition unions its standard input with each listed network's, through one shared macro.

### Datasets and reports

- **BL-015:** A partitioned model reads the inputs of its own partition only.
- **BL-016:** A dataset or report with no per-network models reads the standard partition only, except `ds__deaths` and `user-login-activity`, which read every partition.
- **BL-025:** A network's reports are their own report definitions, which a role runs only with `run` permission on them.

### OMOP layer

- **BL-017:** `clinical__visit_occurrence`, `clinical__visit_detail`, `clinical__condition_occurrence`, `clinical__drug_exposure`, `clinical__measurement`, `clinical__observation`, `clinical__procedure_occurrence`, `clinical__cost` and `clinical__episode` are partitioned.
- **BL-018:** `clinical__person` covers every patient, reading birth records from every partition, and `clinical__observation_period` covers events in every partition.
- **BL-019:** `ref__care_site` and `ref__care_site_location` cover every partition's facilities, and an enrolment names the facility a patient is currently at from every partition.

### Metrics

- **BL-020:** A `metric__` model classified `internal` reads the standard partition only.
- **BL-021:** `metric__birth`, `metric__death`, `metric__immunisation_dose`, `metric__immunisation_refusal` and `metric__patient_condition` cover every facility, reading each partitioned input from every partition.
- **BL-022:** `metric__program_registry_enrolment`, `metric__who_dak_anc_indicators` and `metric__who_dak_hiv_indicators` are partitioned, with the intermediates they read.
- **BL-023:** A new package `metric__` model classified `internal` follows BL-020, and one classified `restricted` names BL-021 or BL-022 in its spec.
- **BL-024:** The `is_sensitive` flags on surveys and lab test types play no part in the partition.
- **BL-026:** A network's model of a partitioned metric emits the same `metric_id` as the standard model, and the registry holds one entry for both.

## Acceptance criteria

Unit-test fixtures use the fixture network `example`: a row at a standard facility, a row at a
facility in `example`, a row at a facility in the unlisted network `other`, and, where the link
allows it, a row with no facility. CI lists `example` for every step except the standard-only
parse.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | For a facility, an encounter, an encounter's child and grandchild, a nullable facility link and a note, the standard base holds the standard and unlinked rows, the `example` base holds the `example` rows, and neither holds the unlisted network's | BL-001 to BL-005, BL-007, BL-010 | unit tests (`ac_001_*`, `test_facilities_partition.yml` and `test_base_partitions.yml`) |
| AC-002 | The generator writes each partitioned model, property file and report config for each network, renames named tests, and removes a dropped network's files | BL-011, BL-012, BL-027 | pytest (`test_generate_sensitive_network_models.py`) |
| AC-003 | Every sensitive network in the deployment is listed in the var | BL-010 | singular data test `assert__sensitive_networks__code`, severity `error` |
| AC-004 | The committed fixture models match what the generator writes, and the `sensitive` folders hold nothing else | BL-013, BL-029 | pytest (`test_committed_fixture_network_models_are_in_sync`) and CI's drift check |
| AC-005 | With no network listed the project parses, so no standard model depends on a network's model | BL-015, BL-020, BL-029 | CI's standard-only parse |
| AC-006 | `clinical__visit_occurrence` reads the standard encounters and `clinical__sn_example_visit_occurrence` the `example` network's | BL-015, BL-017 | unit tests (`ac_006_*`) |
| AC-008 | `metric__birth` and `metric__death` count a record that is in the `example` partition | BL-021 | unit tests (`test_metric__birth_projection`, `test_metric__death_population`) |
| AC-009 | `metric__sn_example_program_registry_enrolment` counts the `example` network's episode, with the standard metric's `metric_id` | BL-022, BL-026 | unit test (`ac_009_*`) |
| AC-010 | `ref__care_site` holds a facility care site for the standard facility and for the `example` network's | BL-019 | unit test (`ac_010_*`) |
| AC-011 | `ds__deaths` lists a death whose record is in the `example` partition, and `user-login-activity` names a user's facility there | BL-016 | unit tests (`ac_006_ds__deaths_facility`, `ac_007_user_login_activity_sensitive_facilities`) |

## Lineage

```
source ──► <model>, network = none      ──► <model>              ──► general reports / data tables
       └─► <model>, network = '<code>'  ──► sn_<key>_<model>     ──► network reports / permissioned data tables
                                       (generated in the deployment repo, one per listed network)
every partition ──► ds__deaths, user-login-activity, clinical__observation_period, ref__care_site*, metric__birth / death / immunisation_* / patient_condition
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-24 | Maui team | Every facility-attributed base splits into a standard partition and one per sensitive network, deployments generate the per-network models, and each layer reads the partitions set here (MAUI-7220). |

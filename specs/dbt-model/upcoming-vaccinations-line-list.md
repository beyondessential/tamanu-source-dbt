# dbt Model Spec: `upcoming-vaccinations-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `upcoming-vaccinations-line-list` (+ `ds__patient_vaccinations_upcoming`) |
| **Type** | Tamanu report + supporting dataset |
| **Layer** | `report` over `ds` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6769](https://linear.app/bes/issue/MAUI-6769/update-samoas-vaccination-data-to-exclude-patients-who-have-moved-from) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-05 |
| **Last updated** | 2026-08-05 |

## Purpose

**What is it?** A line list of the vaccine doses a patient is scheduled for, so
immunisation staff can see who is due, overdue, or missing vaccinations and follow them
up. By default it covers patients born in the past 18 years; the user can narrow to any
birth-date range and filter by vaccine, category, status, and village.

**Who consumes it?** EPI / immunisation staff via the Tamanu reporting UI.

**Business context:** National immunisation programmes. Deployments where patients
migrate abroad (Samoa EPI first) can drop out-of-country children via the "Exclude
overseas patients" filter, so the follow-up list is not inflated by children who no
longer live in the country.

## Grain

**One row per:** patient per scheduled vaccine dose that is upcoming, due, overdue,
missed, or scheduled (i.e. one row per outstanding dose per patient).

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('patient_vaccinations_upcoming') }}` | The outstanding scheduled doses (due date, category, status) |
| `{{ ref('patients') }}` | Patient demographics and death status |
| `{{ ref('vaccine_schedules') }}` | Vaccine label and dose label |
| `{{ ref('reference_data') }}` | Village name |
| `{{ ref('patient_additional_data') }}` | `country_id` — recorded country of residence |

### Required input columns

| Upstream | Columns used |
|---|---|
| `patient_vaccinations_upcoming` | `patient_id`, `vaccine_schedules_id`, `due_date`, `vaccine_category`, `status` |
| `patients` | `id`, `display_id`, `first_name`, `last_name`, `date_of_birth`, `sex`, `village_id`, `date_of_death` |
| `vaccine_schedules` | `id`, `label`, `dose_label` |
| `reference_data` | `id`, `name` |
| `patient_additional_data` | `patient_id`, `country_id` |

## Output schema

Report columns (user-facing labels via `translate_label`):

| Column (label concept) | Source | Type | Description |
|---|---|---|---|
| `patientDisplayId` | `display_id` | text | Patient display identifier |
| `patientFirstName` | `first_name` | text | Patient first name |
| `patientLastName` | `last_name` | text | Patient last name |
| `patientDateOfBirth` | `date_of_birth` | date (formatted) | Patient date of birth |
| `patientVillage` | `village` | text | Patient village name |
| `patientAge` | `age` | integer | Patient age in years |
| `patientSex` | `sex` | text | Patient sex |
| `vaccinationDueDate` | `due_date` | date (formatted) | Date the dose is due |
| `vaccineName` | `vaccine_name` | text | Vaccine label |
| `vaccineSchedule` | `vaccine_schedule` | text | Dose label within the schedule |
| `vaccinationStatus` | `vaccine_status` | text | Dose status (due / overdue / missed / upcoming / scheduled) |

The dataset also carries `village_id`, `vaccine_category`, and `country_id` (used by the
report's filters), plus `patient_id` and `vaccine_schedules_id`; none of these are
displayed.

## Parameters

| Name | Field | Meaning |
|---|---|---|
| `fromDate` / `toDate` | date range (default `18years`) | Restrict to patients born within the range; the reporting UI always supplies one (default: past 18 years) |
| `category` | `VaccineCategoryField` | Restrict to one vaccine category |
| `vaccine` | `VaccineField` | Restrict to one vaccine |
| `status` | `ParameterSelectField` | Restrict to one dose status |
| `villageId` | `ParameterAutocompleteField` (village) | Restrict to one village |
| `excludeNonHomeCountry` ("Exclude overseas patients (default: No)") | `ParameterSelectField` (Yes / No) | When `Yes`, apply the overseas exclusion (BL-006) |

## Configuration

| Var | Default | Meaning |
|---|---|---|
| `home_country_id` | `country-Australia` | `reference_data` id of the deployment's home country; overridden per deployment (Samoa → `country-Samoa`) |

## Business logic

- **BL-001:** One row per outstanding scheduled vaccine dose per patient, sourced from
  `patient_vaccinations_upcoming` joined to the patient and the vaccine schedule.
- **BL-002:** Exclude deceased patients (`date_of_death is null`).
- **BL-003:** Country of residence is the patient's current `patient_additional_data`
  value — the operative state is where the patient lives now, not its change history.
- **BL-004:** Restrict to patients born within the date range supplied by the reporting
  UI, which always provides one (default: births in the past 18 years).
- **BL-005:** The `status`, `category`, `vaccine`, and `villageId` filters each apply only
  when the user supplies a value; an unset filter matches all rows.
- **BL-006:** When the user sets "Exclude overseas patients" to `yes`, exclude patients
  whose recorded `country_id` is non-null and not equal to `home_country_id`; retain
  patients with no recorded country. Any other value (or the `no` default) includes
  everyone.
- **BL-007:** Order by due date, then patient last name, first name, and vaccine name.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | With "Exclude overseas patients" unset or `no`, every patient matching the other filters is returned (no country restriction) | BL-006 | Review against the `-- BL-006` anchor |
| AC-002 | With "Exclude overseas patients" = `yes`, no output row has a non-null `country_id` unequal to `home_country_id`, and rows with a null `country_id` are retained | BL-006 | dbt unit test `ac_002_upcoming_vaccinations_exclude_overseas` |
| AC-003 | No output row belongs to a deceased patient | BL-002 | Review against the `-- BL-002` anchor |

## Lineage

```
patient_vaccinations_upcoming ──┐
patients ───────────────────────┤
vaccine_schedules ──────────────┼─► ds__patient_vaccinations_upcoming ─► upcoming-vaccinations-line-list
reference_data ─────────────────┤                                          (report)
patient_additional_data ────────┘
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-05 | Maui team | Document the report; add the "Exclude overseas patients" filter and `home_country_id` var |

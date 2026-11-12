# dbt Model Spec: `metric__appointment` (canonical definition)

## Purpose

Outpatient appointments booked in Tamanu, one row per appointment, whatever became of it. It
counts appointments by clinic, status and type, so a consumer reads attendance and no-shows
(appointments whose status is `No-show`) by clinic without a line list.

| `metric_id` | Unit | Measures |
|---|---|---|
| `outpatient_appointment` | count | Outpatient appointments (always 1 per row) |

**Who reads it.** Tupaia outpatient dashboard cards (appointments and no-shows by clinic), via a
data table over this view.

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__appointment` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-011) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7131](https://linear.app/bes/issue/MAUI-7131) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-11 |
| **Last updated** | 2026-11-11 |

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of booked outpatient appointments by recorded status. No external body registers an appointment-count or no-show indicator a Tamanu appointment maps to |

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity.
`subject_id` is the Tamanu appointment id, so `count(distinct subject_id)` and
`sum(value_numeric)` agree.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `outpatient_appointment`. FK -> `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL -- the standard definition |
| `subject_id` | varchar(255) | Appointment id. `not_null` (AC-004) |
| `period_start` | timestamp | Scheduled start, minute grain (BL-004). `not_null` (AC-005) |
| `period_end` | timestamp | Scheduled end, minute grain (BL-004). NULL where none is recorded |
| `period_granularity` | text | Constant `'minute'` (AC-006) |
| `value_numeric` | numeric | Always `1` (AC-007) |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar(255) | The appointment's location group's facility (BL-005). `not_null` (AC-008) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` (BL-009) |
| `age_years` | integer | Age in whole years on the appointment date, unbanded (BL-009). A measure, not a dimension |
| `appointment_status` | varchar(255) | Tamanu status as recorded (BL-007). Never NULL (AC-009) |
| `appointment_type` | varchar(255) | Appointment type, resolved to a name (BL-008). Never NULL (AC-010) |
| `location_group_name` | varchar(255) | The location group (clinic/area) the appointment is booked in, resolved to a name (BL-006). Never NULL (AC-011) |

## Data tables

The Tupaia data tables over this view are configured in `tupaia-data-product`, at
`tamanu/data_tables/`. This model carries no `data_table_*` meta.

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (inclusion):** every row of `bases/outpatient_appointments` -- which already drops
  deleted appointments, test-patient appointments and location bookings (rows with no
  appointment type) -- whatever its status, including cancelled appointments and no-shows.
- **BL-003 (per-appointment grain):** one row per appointment, `subject_id` = the appointment
  id, `value_numeric` = `1`.
- **BL-004 (reporting period):** `period_start` is the appointment's scheduled `start_datetime`
  and `period_end` its scheduled `end_datetime`, both truncated to the minute, at `'minute'`
  granularity. `period_end` is NULL where the appointment records no end.
- **BL-005 (facility attribution):** `facility_id` is the facility of the appointment's
  location group (`bases/location_groups.facility_id`). Inner join: an appointment whose
  location group does not resolve is excluded rather than attributed to a NULL facility.
- **BL-006 (location group):** `location_group_name` is the name of the appointment's location
  group -- the clinic or area it is booked in -- the same column and clinic list as
  `metric__outpatient_visit` BL-015. Coalesced to `'Not recorded'`, never NULL (AC-011).
- **BL-007 (status):** `appointment_status` is the appointment's Tamanu `status` as recorded
  (`Confirmed`, `Arrived`, `Assessed`, `Seen`, `No-show`, `Cancelled`), ungrouped, coalesced to
  `'Not recorded'`, never NULL (AC-009). It is the appointment's current status: Tamanu updates
  it in place, so a row reads as it stands now, not as it stood on the appointment date.
- **BL-008 (appointment type):** `appointment_type` is `appointment_type_id` resolved to its
  `reference_data` name. Left joined and coalesced to `'Not recorded'`, never NULL (AC-010).
- **BL-009 (demographics):** `sex` and `age_years` come from the patient's `clinical__person`
  row; `age_years` is whole years on the appointment's start date, via the `age_years` macro,
  unbanded and absent from the registry's disaggregations. Inner join: an appointment whose
  patient `bases/patients` excludes (deleted or merged) is excluded.
- **BL-010 (no patient identifier):** the patient id is used only for the BL-009 join and is
  not emitted; no column carries a patient identifier, name, date of birth or the clinician.
  `pii: false`, `classification: internal`, the reasoning `metric__outpatient_visit` uses.
- **BL-011 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-003 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `outpatient_appointment` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `subject_id` is `not_null` | BL-003 | `not_null` |
| AC-005 | `period_start` is `not_null` | BL-004 | `not_null` |
| AC-006 | `period_granularity` is `not_null` and always `'minute'` | BL-004 | `not_null` + `accepted_values` |
| AC-007 | `value_numeric` is `not_null` and always `1` | BL-003 | `not_null` + `accepted_values` |
| AC-008 | `facility_id` is `not_null` | BL-005 | `not_null` |
| AC-009 | `appointment_status` is `not_null` | BL-007 | `not_null` |
| AC-010 | `appointment_type` is `not_null` | BL-008 | `not_null` |
| AC-011 | `location_group_name` is `not_null` | BL-006 | `not_null` |
| AC-012 | The projection resolves as specified: every status is kept, including `No-show` and `Cancelled`; the period is truncated to the minute and `period_end` stays NULL where none is recorded; the facility and clinic come from the location group; an unresolved appointment type reads `'Not recorded'`; an appointment whose location group or patient does not resolve is excluded; `age_years` is taken on the appointment date; no patient identifier is emitted | BL-002–BL-010 | unit test `ac_012_metric__appointment_projection` |

## Registry entry

One row in `documentations/metrics/outpatient.yml`: `outpatient_appointment`, `kind: metric`,
`unit: count`, `subject_grain: appointment`, `status: approved`, `spec_path` pointing here, with
`disaggregations: facility_id,sex,appointment_status,appointment_type,location_group_name`.
`age_years` is absent: it is a measure (BL-009). `appointment_status` and `appointment_type` are
in the allowlist in `assert__metric_definitions__disaggregations`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `outpatient_appointments` | `bases/` | The appointments: inclusion, period, status, type, location group, patient (BL-002–BL-008) |
| `location_groups` | `bases/` | Facility and clinic name of the appointment's location group (BL-005, BL-006) |
| `reference_data` | `bases/` | Appointment type name (BL-008) |
| `clinical__person` | `clinical/` | Inclusion, sex and birth date (BL-009) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table over this view, backing appointment and no-show cards by clinic |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Scope by status.** No-shows are `appointment_status = 'No-show'`. A no-show rate is that
   count over the appointments the consumer counts as booked -- whether `Cancelled` belongs in
   that denominator is the consumer's choice, so the model keeps every status.
3. **Read the status as current.** A future appointment reads `Confirmed`; a past one still
   reading `Confirmed` was never updated, not attended.
4. **Bucket the time grain and band `age_years` itself.**

## Related

| Artefact | Relationship |
|---|---|
| `metric__outpatient_visit` | The visits themselves; shares `location_group_name` (its BL-015) so appointments and visits read against one clinic list |
| `ds__outpatient_appointments` | Report-layer appointment line list over the same base, with patient detail |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-11 | Maui team | Initial spec and implementation, for appointments and no-shows by clinic (MAUI-7131) |

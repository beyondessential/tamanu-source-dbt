# Report Spec: `outpatient-appointments-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `outpatient-appointments-line-list` |
| **Type** | Tamanu report (shared macro + standard/sensitive wrappers) over the `ds__outpatient_appointments` dataset |
| **Layer** | `ds`, `report` |
| **Materialisation** | dataset `view`; report `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | _none yet — this spec was written alongside the performance rework_ |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-07 |
| **Last updated** | 2026-09-07 |

## Purpose

Every patient with a scheduled outpatient appointment in a date range, one row per
appointment, in chronological order by scheduled start. The operational counterpart to
`audit-outpatient-appointments`: this report answers "who is coming in", that one answers
"who changed the booking".

**Consumers:** the Tamanu reporting UI. The dataset additionally serves analytics
consumers wanting appointments without report parameters.

## Grain

One appointment (BL-040). Not one row per change event — that is the audit report's grain,
and the two share upstream models but not their shape.

## Inputs

### Parameters (report only)

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | next 30 days | Lower bound on the appointment's **scheduled start**, not when it was booked (BL-041) |
| `toDate` | date | next 30 days | Upper bound on the same column, inclusive of the whole day (BL-041) |
| `facilityId` | uuid | null | Optional single-facility restriction (BL-045) |
| `locationGroupId` | uuid | null | Optional single-area restriction |
| `clinicianId` | uuid | null | Optional single-clinician restriction |
| `appointmentTypeId` | uuid | null | Optional single-type restriction |
| `appointmentStatus` | text[] | null | Optional multi-select over `Confirmed`, `Arrived`, `Assessed`, `Seen`, `No-show`, `Cancelled` |

### Macro arguments (report and dataset)

`is_sensitive` — `false` (standard) / `true` (sensitive); selects the facility partition
(BL-045).

`appointment_filter` — the dataset macro's early-filter argument (BL-046). `none` for the
dataset models, the report's predicate text for the report.

### Upstream models

| Reference | Why |
|---|---|
| `ref('outpatient_appointments')` | Appointment population and schedule fields (BL-040) |
| `ref('location_groups')`, `ref('facilities')` | Area and facility names, and the sensitivity partition (BL-045) |
| `ref('outpatient_appointments_change_events')` | The creation event, for `created_by` (BL-044) |
| `ref('patients')`, `ref('patient_additional_data')` | Demographics and contact number |
| `ref('users')` ×2 (clinician, creator) | Display names |
| `ref('reference_data')` ×3 (billing type, village, appointment type) | Resolved names |

### Freshness

The report reads through `bases/` at request time, so it is always current.

## Output schema

Standard and sensitive share one macro, so columns are identical by construction (BL-047).

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId`, `patientFirstName`, `patientLastName` | text | Patient identity |
| `patientDateOfBirth` | text | Formatted date of birth |
| `patientAge` | integer | Age at the appointment's scheduled start, not today |
| `patientSex` | text | |
| `patientContactNumber` | text | Primary contact number, falling back to secondary |
| `patientVillage`, `patientBillingType` | text | Resolved reference-data names |
| `appointmentDateTime`, `appointmentEndDateTime` | text | Scheduled start and end, in the viewer's timezone |
| `appointmentType`, `appointmentStatus` | text | |
| `appointmentClinician` | text | The clinician the appointment is booked with |
| `appointmentLocationGroup` | text | Area |
| `appointmentPriority` | text | `Yes`/`No`, formatted in the base model |
| `appointmentIsRepeating` | text | Recurrence description, or the literal `No` (BL-048) |
| `appointmentRepeatingEndDate` | text | The schedule's `until_date`, blank for a one-off |
| `appointmentCreatedBy` | text | User who booked the appointment (BL-044) |

The dataset emits 32 columns to the report's 19 — snake_case, unformatted, no translation
keys. Beyond the same facts it carries `appointment_id`, `patient_id`, the raw `*_id`
columns behind each resolved name, `facility_id`/`facility`, and the four raw schedule
fields (`interval`, `frequency`, `days_of_week`, `nth_weekday`) the report collapses into
one description.

## Business logic

Each clause is anchored in the implementing SQL as a `-- BL-XXX:` comment. As
`audit-outpatient-appointments.md` records under its DV-007, `check_spec_anchors.py` only
compares ID sets — it never checks that a comment still describes the code beneath it, and
is not run by CI. Keeping a clause true to its code is a review obligation.

- **BL-040:** One row per appointment, over the population `bases/outpatient_appointments`
  defines — which excludes soft-deleted appointments, appointments with no
  `appointment_type_id`, and the test patient. Appointment-level fields are read from the
  appointment's *current* row, so the report shows the booking as it now stands and carries
  no history.
- **BL-041:** `fromDate`/`toDate` bound the appointment's **scheduled start**
  (`start_datetime`), the opposite of the audit report's BL-029, which bounds edit time. The
  range is inclusive at both ends: Tamanu binds `fromDate` as start-of-day and `toDate` as
  end-of-day (`getToDate()` in
  `packages/shared/src/utils/reports/getReportQueryReplacements.js`), so `<= :toDate` covers
  the whole of `toDate` and the house line-list form is correct as written.

  This deliberately keeps the house form rather than the audit reports'
  `< (:toDate)::date + interval '1 day'`. That variant exists so the bound means the same
  thing in both of `parameter()`'s modes; the cost of the house form is that outside compile
  — `dbt run`, and therefore every unit test — `data_type='date'` casts the bound to
  midnight and the final day *is* truncated. Unit tests compensate by setting `toDate` a day
  past their data, and no unit test can exercise the production semantics (DV-002).
- **BL-042:** Every filter is applied inside the dataset's `appointments_in_scope` CTE,
  before the patient, reference-data and creator joins, and there is no outer `where`
  clause. This is the same pushdown as the audit report's BL-030, with one difference that
  matters: BL-030 re-applies every predicate at the end, so its candidate filter is allowed
  to be a loose superset. Here the scope CTE *is* the filter, so each predicate must be
  exact — except BL-043, which is deliberately loose and paired with the exact bound it
  widens.
- **BL-043:** The date range is expressed twice. The exact predicate (BL-041) wraps the
  column in `to_user_selected_timezone()`, so no index on `appointments.start_time` is
  usable; a second pair of bounds compares the bare column against `(:bound)::date` widened
  a day past each exact bound, which an index can prune. The widening absorbs the
  `:timezone` round trip, which can move the value by up to the zone offset in either
  direction, so the bare-column pair is always a strict superset of the exact one.

  `from_user_selected_timezone()` — the BL-039 technique — does not apply: it is only valid
  against a `timestamptz` column, and `start_datetime` is a naive timestamp
  (`a.start_time::timestamp` in the base model).
- **BL-044:** `created_by` is the actor on the appointment's earliest surviving change
  event, resolved with `distinct on (record_id)` over
  `bases/outpatient_appointments_change_events` — the window-free projection BL-037 exists
  for — joined to `appointments_in_scope`.

  This replaced a read of `outpatient_appointments_change_logs` filtered on
  `change_sequence = 1`. That put `row_number()` and `lag(record_data)` between the
  report's filters and the change-log scan, and Postgres pushes no predicate below a
  `WindowAgg`, so a one-month report windowed every appointment's entire history and
  carried each row's JSONB payload through the sort. The rewrite is an exact equivalence,
  on three counts: both read the same source rows under the same BL-037 filters; the
  `order by` is the window's own `(logged_at, record_updated_at, id)`, so `distinct on`
  selects the row where `row_number() = 1`; and at that row
  `first_value(updated_by_user_id)` is `updated_by_user_id`.

  BL-031's statement that the base model itself cannot be date-scoped still holds — this
  removes the line list's dependence on that model rather than changing it.
- **BL-045:** Facility scope is the `is_sensitive` partition plus the optional `facilityId`
  parameter, both applied in the scope CTE. Area and facility are inner joins, so an
  appointment whose `location_group_id` is null or dangling produces no row at all; the
  join to `patients` behaves the same way, so a soft-deleted or merged patient takes their
  appointments with them.

  `facilityId` had been declared by both report configs' `FacilityField` since the report
  was written and referenced by no predicate, so selecting a facility returned every
  facility's appointments. Applying it is a visible behaviour change (DV-001).
- **BL-046:** The dataset macro takes `appointment_filter`, raw SQL spliced into the scope
  CTE's `where`, on the same alias contract as `encounters_core()`'s BL-003: the predicate
  may reference `a` (appointments), `lg` (location groups) and `f` (facilities) and nothing
  else. It is row-selecting only — the scope CTE has no window functions or aggregates, so
  a caller's predicate can change which rows survive but not the value of any column.

  The macro itself calls no `parameter()`, because datasets build on analytics targets where
  `parameter()` falls through to a `var()` literal rather than a bind placeholder. Report
  callers own their filters.
- **BL-047:** Standard and sensitive share `outpatient_appointments_line_list_report()`,
  and the two report models are one-line calls differing only in `is_sensitive`. Before
  this, each carried its own copy of the same 45-line body — the drift risk the
  `outpatient_appointments_audit_core` header describes from experience.
- **BL-048:** `appointmentIsRepeating` carries two kinds of value in one column: the
  recurrence description (`get_recurrence_description()`) for an appointment with a
  `schedule_id`, and the literal `No` for a one-off. Pre-existing behaviour, preserved
  verbatim; see DV-003.

## Acceptance criteria

| ID | Criterion | Implements | Status |
|---|---|---|---|
| AC-040 | With `facilityId` set, only that facility's appointments are returned | BL-045 | **passed** — `test_outpatient_appointments_line_list_facility_filter` |
| AC-041 | An appointment whose creation event predates the report window still reports its creator, and a later edit does not displace it | BL-044 | **passed** — `test_outpatient_appointments_line_list_creator_outside_window` |
| AC-042 | The rewritten creator lookup returns what the windowed one did, for every appointment | BL-044 | **passed** — release replica, 582,002 appointments: 0 rows on either side alone, 0 creator disagreements |
| AC-043 | The report's output columns are unchanged by the rework | BL-047 | **passed** — compiled SQL diffed against the previous version: 19 columns and their labels byte-identical, both variants |
| AC-044 | The dataset returns one row per in-scope appointment, unchanged in count | BL-040 | **passed** — release replica, 585,091 = 585,091, the `logical__ds__outpatient_appointments` assertion |
| AC-045 | A one-month run completes without the change-log window scan | BL-042, BL-044 | **passed** — release replica, January 2025: 11m51s to 15.8s for the identical 14,143 rows |
| AC-046 | Sensitive-facility appointments never appear in the standard output, or vice versa | BL-045 | not tested — no unit test; the partition is shared with the audit report's AC-027 |
| AC-047 | Every row returned has a scheduled start within `[fromDate, toDate]` in the viewer's timezone | BL-041 | not tested under the compile branch — see DV-002 |
| AC-048 | The bare-column bounds are a superset of the exact predicate for any `:timezone` | BL-043 | not tested — unreachable from dbt (DV-002); argued from the maximum zone offset |
| AC-049 | The bare-column bound leaves an index on `start_time` usable | BL-043 | not tested — needs `EXPLAIN` on a populated replica |

## Lineage

```
appointments ──► outpatient_appointments (base, BL-040) ──┐
location_groups, facilities ──────────────────────────────┤
                                                          ├──► appointments_in_scope (BL-042, BL-045)
logs.changes ──► outpatient_appointments_change_events ───┘         │
                 (thin base, BL-037)                                │
                        └──► distinct on (BL-044) ──► appointment_creators
                                                                     │
patients, patient_additional_data, users, reference_data ────────────┤
                                                                     ▼
                                     outpatient_appointments_dataset()  (BL-046)
                                          ├─ appointment_filter=none ──► ds__outpatient_appointments (+sensitive)
                                          │                                   └──► analytics consumers
                                          └─ report filter (BL-042) ──► outpatient_appointments_line_list_report() (BL-047)
                                                                              ├──► outpatient-appointments-line-list
                                                                              └──► sensitive-outpatient-appointments-line-list
```

## Open questions

- **No Linear issue.** This work was raised from a review of the report rather than a
  ticket. It needs a MAUI card before merge, both for traceability and because BL-045 is a
  user-visible change.

## Divergence from current code

- **DV-001:** BL-045 changes behaviour. A saved parameter set or a user habit that selected
  a facility previously returned every facility's appointments and now returns one
  facility's. That is what the config always declared, but the report has never behaved
  that way, so the row count for identical inputs drops. *Resolution:* call it out in the
  release notes, not just the PR.
- **DV-002:** Coverage is two unit tests, both on the report. Unit tests reach only the
  non-compile branch of `to_user_selected_timezone()`, where it is a no-op, so neither the
  timezone conversion the compiled report runs nor BL-043's superset property can be
  exercised by dbt at all — and BL-041's production end-of-day semantics are visible only
  in the compiled SQL plus Tamanu's binding. The same limitation as the audit report's
  DV-004. *Resolution:* verify the compiled form against a replica; consider a
  `report_validation` check for the superset property.
- **DV-003:** BL-048's column mixes a description with a `No`, so it sorts and filters
  meaninglessly in Excel and cannot answer "which appointments repeat" without string
  matching. Pre-existing and preserved deliberately — changing it is a product decision
  needing a `translate_label` key. *Resolution:* raise separately if users ask.
- **DV-004:** The dataset gained two columns (`facility_id`, `facility`) and one upstream
  dependency it did not have before (`outpatient_appointments_change_events` is now read
  directly rather than through `outpatient_appointments_change_logs`). An analytics build
  must select the model with its upstream chain rather than in isolation. *Resolution:*
  confirm the analytics pipeline does, as the audit report's DV-008 asks for the same
  model.
- **DV-005:** `check_spec_anchors.py` is not run by CI (`.github/workflows/checks.yml` does
  not invoke it), so the anchors here are advisory. Shared with the audit report's DV-007.

## Risks

- **The BL-044 equivalence rests on the two paths reading the same rows.** If
  `bases/outpatient_appointments_change_events` and
  `outpatient_appointments_change_log_events()` ever diverge in their source filters, the
  creator resolved here diverges from the one the audit report reports, silently. They read
  the same base today precisely because BL-037 put the filters in one place; a change to
  either must keep them together.
- **BL-043's superset is argued, not measured.** It relies on no timezone offset exceeding
  a day, which is true of every real zone but is not enforced anywhere. A `:timezone` of a
  hypothetical far-offset zone would narrow the result set rather than error.
- **The report must read a central-server database** for `created_by` to be right. A
  facility server holds only partial change history for anything edited elsewhere — the
  audit spec's reasoning applies unchanged, and here it would show a blank or wrong creator
  rather than a wrong `change_number`.
- **`priority` is text, not boolean.** `bases/outpatient_appointments` already formats
  `is_high_priority` to `Yes`/`No`, so the dataset's `priority` column is a string despite
  the `.yml` declaring `boolean`. Pre-existing, and the `.yml` type is wrong rather than the
  SQL. Not corrected here, to keep this change to the performance rework.
- **Appointment age is computed at the appointment, not today.** `patientAge` is
  `age(start_datetime, date_of_birth)`, so a future-dated appointment reports the age the
  patient *will* be. Intentional and pre-existing, but it surprises readers comparing the
  column to a patient's current age elsewhere.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-07 | Maui team | Initial spec, written alongside the performance rework: filter pushdown into the dataset's scope CTE (BL-042, BL-046), the window-free creator lookup (BL-044), the bare-column index-prunable bounds (BL-043), the shared report macro replacing two copies of the body (BL-047), and `facilityId` applied for the first time (BL-045). BL-041 records why this report keeps the house `<= toDate` form where the audit reports cast and add a day. |

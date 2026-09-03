# Report Spec: `hospital-admissions-*-summary`

## Identity

| Field | Value |
|---|---|
| **Name** | `hospital-admissions-by-area-summary`, `hospital-admissions-by-department-summary`, `hospital-admissions-by-location-summary` |
| **Models** | `models/reports/sql/standard/hospital-admissions-by-{area,department,location}-summary.sql` — inline SQL, no report macro |
| **Intermediates** | `int__admission_history_location`, `int__admission_history_department` (`models/intermediate/standard/`) |
| **Type** | Tamanu reports (reporting schema) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-04 |

Monthly aggregate activity for inpatient areas, departments and locations: how many
patients were admitted, discharged, died or transferred, how long they stayed, and — for
two of the three — how full the beds were.

## Purpose

These are the bed-management and activity reports. They answer "what happened in this
ward last month", at three levels of granularity, from one shared episode spine per
dimension.

## Grain

One row per (reporting month × dimension), where the dimension is the location group for
`-by-area`, the department for `-by-department`, and the location for `-by-location`. A
row exists only where at least one admission episode overlaps that month.

The intermediates below it are at **episode** grain: one row per contiguous stay of an
encounter in one location (or one department).

## Inputs

`ref('encounter_history')`, `ref('encounters')`, `ref('patients')`, `ref('locations')`,
`ref('location_groups')`, `ref('departments')`, `ref('facilities')`.

Parameters: `fromDate`, `toDate`, plus `locationGroupId` (`-by-area`, `-by-location`) or
`departmentId` (`-by-department`).

## Output

All three: `reportingMonth`, `facility`, the dimension name, then
`hospitalAdmissionCount`, `hospitalDischargeCount`, `hospitalDeathCount`,
`hospitalTransfersInto*Count`, `hospitalTransfersOutOf*Count`,
`hospitalAverageLengthOfStay`.

`-by-area` and `-by-location` additionally: `hospitalPatientDayCount`,
`hospitalBedOccupancyPercent`. `-by-location` also carries `location` alongside
`locationGroup`.

## Business logic

- **BL-001:** An episode is a contiguous stay in one dimension value. Boundaries come
  from `lead(start_datetime)` over the encounter ordered by start datetime, and the final
  episode closes on the encounter's `end_datetime` — so an open encounter has an open
  final episode.
- **BL-002:** Episodes are built only from the encounter's **admission phase**: history
  rows where `encounter_type = 'admission'` and `change_type` is null or overlaps
  `{location, encounter_type}` (or `{department, encounter_type}`). An encounter admitted
  from an outpatient presentation therefore contributes episodes from conversion onward,
  never from presentation. This matches BL-002 of `specs/dbt-model/ds__admissions.md`,
  and the same reasoning applies: the reports are about inpatient activity.
- **BL-003:** An episode is typed `admission` when it starts on the creation row or on an
  `encounter_type` change, and `transfer-in` otherwise.
- **BL-004:** Five event flags are derived per episode. `admission` and `transfer_in`
  restate BL-003. `transfer_out` is true where a later episode exists. `discharge` is
  true where no later episode exists **and** the encounter has an `end_datetime`. `death`
  is true where no later episode exists and the encounter's end date equals the patient's
  `date_of_death` — so a death is also counted as a discharge, and the two columns are
  not disjoint.
- **BL-005:** `length_of_stay` is the difference in whole days between the episode's
  start and end dates, **floored at 1** — a stay beginning and ending on the same date
  counts as one day, never zero.
- **BL-006:** The reports generate a month spine from `fromDate` to `toDate` and join
  episodes that overlap each month, so an episode spanning three months contributes to
  all three. In `-by-area` and `-by-location` the counts of admissions, discharges,
  deaths and transfers are further filtered to episodes whose **start** date falls inside
  the month, so a long stay is counted as an admission once, in the month it began.
  `-by-department` filters its counts the same way, for the same reason.
- **BL-007:** `hospitalPatientDayCount` is patient-days inside the month: the episode's
  span clipped to the month boundaries, or 1 where the episode starts and ends on the
  same date. An open episode is clipped to `current_date`.
- **BL-008:** `hospitalBedOccupancyPercent` is patient-days over capacity-days, where
  capacity is the sum of `locations.max_occupancy` over the location group for `-by-area`
  and the single location's `max_occupancy` for `-by-location`, and the day count is
  the elapsed part of the month for the current month and the whole month otherwise. It
  renders `N/A` where either occupancy or capacity is null — a dimension whose locations
  carry no `max_occupancy` reports activity but no occupancy.
- **BL-009:** `-by-department` carries **no** occupancy or capacity columns.
  `max_occupancy` is a property of a location, and a department does not own locations, so
  there is no capacity to divide by.
- **BL-010:** All three join episodes to the month spine on overlap and clip the spine at
  `current_date`, so a month later than today is never reported even when the requested
  range extends into the future. `-by-department` additionally admits an episode into the
  month it started, which matters only for the malformed episodes of DV-003.

- **BL-011:** `hospitalAverageLengthOfStay` averages the episodes whose **end** date falls
  inside the month, in all three reports. A month's figure therefore describes the stays
  that finished in it, an open episode contributes to no month until it closes, and a stay
  spanning several months is averaged once, in the month it ended — never in the month it
  began. The figure is comparable across the three.

  A consequence: a month can hold a row with zero events and a populated average, because
  a stay ended in it without any starting. `-by-area` and `-by-location` report such a
  month regardless, since patient-days accrue while a stay is merely open. `-by-department`
  has no occupancy column (BL-009), so it keeps a row only where an episode started **or**
  ended in the month, and a month an episode merely spans is suppressed as empty.

## Divergences

- **DV-001:** *(the standard/sensitive partition is not applied)* Both intermediates join
  `facilities` with no `is_sensitive` predicate, and all three reports exist only in
  `models/reports/sql/standard/` with no sensitive twin. A sensitive facility's name and
  its admission, discharge, **death**, transfer, length-of-stay and bed-occupancy figures
  therefore appear in a standard report. Everywhere else the partition is applied as
  `f.is_sensitive = {{ is_sensitive }}` — exhaustive and disjoint, so each facility's data
  reaches exactly one of the two variants. Here it reaches the standard one regardless.
  The figures are aggregate rather than patient-level, which bounds the exposure but does
  not remove it: a facility appears by name with a death count. In both intermediates the
  `facilities` join exists only to resolve `f.name`, so nothing else depends on it.
  Resolution is OQ-001.
- **DV-002:** *(episodes silently dropped)* `int__admission_history_location` inner-joins
  `location_groups`, so an episode in a location with no `location_group_id` disappears
  from both `-by-area` and `-by-location`, taking its admission, discharge and death
  counts with it. `int__admission_history_department` has no equivalent join and is
  unaffected. The same class of defect as an inner join to a nullable dimension elsewhere;
  it is a silent undercount rather than a visible gap.

- **DV-003:** *(malformed episodes)* An episode can end before it starts, where an
  encounter's `end_datetime` precedes a later history row — the intermediates compute
  `end_datetime` as `coalesce(lead(start_datetime), encounters.end_datetime)` and do not
  guard the ordering. Such an episode spans no month, so the overlap join in `-by-area`
  and `-by-location` excludes it from **every** month and its admission, discharge and
  death are reported nowhere. `-by-department` admits it into the month it started
  (BL-010), so the three reports disagree on these episodes. Resolution is OQ-003.

## Open questions

- **OQ-001** *(owner: Maui team; due: before these reports are used by a deployment that
  flags any facility sensitive)* — how should DV-001 be resolved? Three resolutions are
  viable and they differ in what is lost: partition the intermediates and add sensitive
  twins of all three reports; partition to standard-only and accept that sensitive
  facilities have no bed-management reporting; or record the current behaviour as
  deliberate on the grounds that aggregate counts are not identifying. The choice is a
  governance one about aggregate disclosure rather than a technical one — all three are
  straightforward to build — so it needs a decision before code.
- **OQ-002** *(owner: Maui team; due: with OQ-001)* — should DV-002 be resolved by a left
  join, so an ungrouped location's episodes are counted under a null area? That changes
  `-by-area` output and needs a row-level diff. It is listed with OQ-001 because both are
  fixes to the same intermediate and are cheaper to ship together.

- **OQ-003** *(owner: Maui team; due: with OQ-001)* — how should the malformed episodes of
  DV-003 be treated? Dropping them everywhere makes the three consistent but loses real
  admissions; keeping them everywhere means deciding which month a negative-duration stay
  belongs to. Either is a behaviour change to `-by-area` and `-by-location` and needs its
  own row-level diff. The underlying data is worth a look first: an encounter ending
  before its own history is a source-side defect, not a reporting one.

## Acceptance criteria

| ID | Criterion | Clause | Asserted by |
|---|---|---|---|
| AC-001 | An episode spanning several months appears in each month it overlaps. | BL-006 | `test_hospital_admissions_by_area_date_range_basic` |
| AC-006 | A stay spanning months is averaged in the month it ended, not the month it began. | BL-011 | `test_hospital_admissions_by_department_length_of_stay` |
| AC-007 | An open episode contributes to no month's average. | BL-011 | `test_hospital_admissions_by_department_length_of_stay` |
| AC-008 | A `-by-department` month an episode merely spans is not reported. | BL-009 | `test_hospital_admissions_by_department_length_of_stay` |
| AC-002 | A same-day stay counts as one day, not zero. | BL-005 | Structural — no test targets the floor |
| AC-003 | A death is counted in both the death and discharge columns. | BL-004 | Structural — no test targets the overlap |
| AC-004 | A dimension whose locations carry no `max_occupancy` renders `N/A`. | BL-008 | Structural |
| AC-005 | No sensitive facility appears in these reports. | — | **Not satisfied.** See DV-001 |

## Change log

| Date | Change |
|---|---|
| 2026-09-04 | Retrospective spec created for the three summaries and their two intermediates. |
| 2026-09-04 | `-by-department` average length of stay changed to the ended-in-month basis the other two use (BL-011), making the three comparable. Event counts unchanged. |

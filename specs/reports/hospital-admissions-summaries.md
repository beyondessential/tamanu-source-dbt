# Report Spec: `hospital-admissions-*-summary`

## Identity

| Field | Value |
|---|---|
| **Name** | `hospital-admissions-by-{area,department,location}-summary` (+ sensitive twins) |
| **Macros** | `hospital_admissions_by_{area,department,location}_summary_report(is_sensitive=false)` (`macros/reports/`) |
| **Models** | `models/reports/sql/{standard,sensitive}/` — one thin macro call per variant |
| **Intermediates** | `admission_history_{location,department}(is_sensitive=false)` (`macros/intermediate/`), materialised as `int__admission_history_*` and `int__sensitive_admission_history_*` |
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

One row per (reporting month × dimension) **in the requested sensitivity partition**, where the dimension is the location group for
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
  is true where no later episode exists and the patient's `date_of_death` falls within the
  encounter's `[start_datetime, end_datetime]`, inclusive — the same interval containment
  `ds__deaths` uses to attribute a death to an encounter. A death is therefore also counted
  as a discharge, and the two columns are not disjoint. Two consequences follow from using
  an interval. A patient discharged alive who dies later the same day is **not** a death
  here. And a death during a still-open
  encounter is not counted until that encounter is closed, since `between start and null`
  is null — the same restriction `discharge` already carries.
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
- **BL-010:** All three join episodes to the month spine on overlap. `-by-area` and
  `-by-location` additionally clip the spine at `current_date`, because they report a month
  an episode merely spans and an open episode would otherwise run the spine to its end;
  a future-dated admission is consequently absent from them. `-by-department` needs no such
  clip — its `having` (BL-009) already restricts it to months an episode started or ended
  in — and it admits an episode into the month it started, which matters only for the
  malformed episodes of DV-003.

- **BL-011:** `hospitalAverageLengthOfStay` averages the episodes whose **end** date falls
  inside the month, in all three reports. A month's figure therefore describes the stays
  that finished in it, an open episode contributes to no month until it closes, and a stay
  spanning several months is averaged once, in the month it ended — never in the month it
  began. The figure is comparable across the three.

  A month in which nothing was discharged renders `0` rather than blank, in all three, so
  the column has one sentinel across the set. A consequence: a month can hold a row with
  zero events and a populated average, because
  a stay ended in it without any starting. `-by-area` and `-by-location` report such a
  month regardless, since patient-days accrue while a stay is merely open. `-by-department`
  has no occupancy column (BL-009), so it keeps a row only where an episode started **or**
  ended in the month, and a month an episode merely spans is suppressed as empty.
- **BL-012:** The facility scope is partitioned by `is_sensitive`, in the intermediates
  rather than in the reports. The predicate is
  `coalesce(f.is_sensitive, false) = <argument>`, so the two variants are disjoint and
  exhaustive: each facility's episodes reach exactly one of them. The `coalesce` is what
  makes it exhaustive — `facilities.is_sensitive` carries no `not_null` test, and a bare
  `= true` / `= false` pair matches neither variant for a null, which would drop that
  facility from all six reports rather than move it. A null reads as non-sensitive. The `coalesce` is
  required here and absent from `encounters_core`'s bare `f.is_sensitive = <argument>`;
  removing it to match would place a null-flagged facility in neither variant. The reports carry no
  sensitivity logic beyond choosing which intermediate to read, and a consumer wanting
  both figures runs both reports. The join to `facilities` exists only to resolve the
  facility name; the predicate is what makes it a partition.

  The sensitive intermediates are tagged `restricted` (`dbt_project.yml`), which is what
  keeps them out of the deployed `reporting` schema unless `has_sensitive_facility` is
  set. Ephemeral materialisation alone does not: `generate_reporting_schema_script()`
  emits a view for every non-report, non-internal model in the manifest, ephemeral
  included, so an untagged sensitive intermediate would ship as an episode-grain view
  readable by `tamanu_reporting` on every deployment — a wider exposure than the
  aggregate one this clause closes.

## Divergences

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
- **DV-005:** *(counts are keyed to the admission month)* BL-006 books every event to the
  month the episode **started**. The shipped report notes describe two of them differently:
  *"Number of discharges = Number of patients discharged … for specified month"* and
  *"Number of deaths = Number of deceased patients … for specified month … when their death
  was recorded"*. A patient admitted in January and discharged in March is therefore
  counted as a March discharge by the notes and as a January discharge by the code. The
  same notes define average length of stay over the patients *discharged* in the month,
  which BL-011 now follows in all three reports — so the discharge and death counts are
  the remaining columns keyed to a different month from the definition they ship with.
  Pre-existing and unchanged here. Resolution is OQ-005.

## Open questions

- **OQ-002** *(owner: Maui team; due: before the next behavioural change to these
  reports)* — should DV-002 be resolved by a left join, so an ungrouped location's episodes
  are counted under a null area? That changes `-by-area` output and needs a row-level diff.
  It touches the same intermediate as OQ-003 and the two are cheaper to ship together.

- **OQ-003** *(owner: Maui team; due: with OQ-002)* — how should the malformed episodes of
  DV-003 be treated? Dropping them everywhere makes the three consistent but loses real
  admissions; keeping them everywhere means deciding which month a negative-duration stay
  belongs to. Either is a behaviour change to `-by-area` and `-by-location` and needs its
  own row-level diff. The underlying data is worth a look first: an encounter ending
  before its own history is a source-side defect, not a reporting one.

- **OQ-005** *(owner: Maui team; due: with OQ-002)* — should the discharge and death
  counts move to the month of discharge or death, matching the notes shipped with the
  reports and the basis BL-011 now uses? It is a behaviour change to all three and needs
  its own row-level diff, so it is not folded into the length-of-stay alignment.

## Acceptance criteria

| ID | Criterion | Clause | Asserted by |
|---|---|---|---|
| AC-001 | An episode spanning several months appears in each month it overlaps. | BL-006 | `test_hospital_admissions_by_area_date_range_basic` |
| AC-006 | A stay spanning months is averaged in the month it ended, not the month it began. | BL-011 | `test_hospital_admissions_by_department_length_of_stay` |
| AC-007 | An open episode contributes to no month's average. | BL-011 | `test_hospital_admissions_by_department_length_of_stay` |
| AC-008 | A `-by-department` month an episode merely spans is not reported. | BL-009 | `test_hospital_admissions_by_department_length_of_stay` |
| AC-002 | A same-day stay counts as one day, not zero. | BL-005 | Structural — no test targets the floor |
| AC-003 | A death is counted in both the death and discharge columns. | BL-004 | `test_int__admission_history_department_death_flag`, `..._location_death_flag` |
| AC-004 | A dimension whose locations carry no `max_occupancy` renders `N/A`. | BL-008 | Structural |
| AC-005 | No sensitive facility's episode appears in a standard report. | BL-012 | `test_int__admission_history_location_partition` |
| AC-009 | A sensitive report carries the sensitive facilities and only those. | BL-012 | `test_int__sensitive_admission_history_location_partition`, `..._department_partition` |
| AC-010 | The department intermediate partitions on the same basis as the location one. | BL-012 | `test_int__admission_history_department_partition` |
| AC-011 | A patient who died during the admission is counted as a death. | BL-004 | `test_int__admission_history_department_death_flag`, `..._location_death_flag` |
| AC-012 | A patient discharged alive who died later the same day is not counted. | BL-004 | `test_int__admission_history_department_death_flag`, `..._location_death_flag` |
| AC-013 | A death recorded at the exact instant the encounter ended is counted. | BL-004 | `test_int__admission_history_department_death_flag`, `..._location_death_flag` |
| AC-014 | A death recorded before the admission began is not counted. | BL-004 | `test_int__admission_history_department_death_flag`, `..._location_death_flag` |

## Change log

| Date | Change |
|---|---|
| 2026-09-04 | Retrospective spec created for the three summaries and their two intermediates. Facility sensitivity partitioned in the intermediates (BL-012), resolving DV-001, with a sensitive twin added for each report. `-by-department` average length of stay aligned to the ended-in-month basis (BL-011). Death condition changed to interval containment (BL-004), resolving DV-004. |

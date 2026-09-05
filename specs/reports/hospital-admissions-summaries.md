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
  all three. Each event count is then filtered to the month the event
  itself falls in, which is not the same month for every column. `admission` and
  `transfer_in` are **start**-of-episode events and are counted in the month the episode
  began. `discharge`, `death` and `transfer_out` are **end**-of-episode events and are
  counted in the month it ended — for `death` that is the encounter's end month standing
  in for `date_of_death`, which the intermediates do not expose (DV-007). A stay admitted
  in January and discharged in March therefore contributes an admission to January and a
  discharge to March. This matches the
  definitions shipped with the reports, which describe each event by the month it occurred.

  An episode's end is the next episode's start, so a transfer is now one month's transfer
  out for the department or area left and the same month's transfer in for the one
  entered. The two columns are still **not** expected to total the same, and the gap is
  structural rather than an attribution error: BL-003 types an episode beginning on an
  `encounter_type` change as an `admission`, not a `transfer-in`, so the preceding episode
  records a transfer out with no matching transfer in. Every transfer out is either
  matched this way or falls into that group.

  Two edge cases lose an end-of-episode event rather than moving it. An episode whose end
  month is later than today is clipped out of `-by-area` and `-by-location` by BL-010's
  spine guard, so its discharge is counted nowhere. And a malformed episode (DV-003) is
  reachable in `-by-department` only through the started-in-month disjunct, so its end
  month has no group and its discharge is likewise counted nowhere; in the other two it was
  already absent from every month.
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
- **BL-013:** A location with no `location_group_id` keeps its episodes. Both joins that
  could drop it are outer: `location_groups` in the intermediate, and the area report's
  `area_capacity`, where the join key is nullable and `null = null` is false — so an
  ungrouped episode surviving the first would have been dropped by the second. Such an
  episode is reported under a **null area**, and `-by-area` renders that as an empty label
  rather than a synthesised one, because naming the bucket is a product decision rather
  than a reporting one. It has no area capacity to divide by, so its bed occupancy is `N/A`
  per BL-008. `-by-location` is unaffected beyond the null area label: it joins `locations`
  on a non-null key and reports the location's own `max_occupancy`.

## Divergences

- **DV-003:** *(malformed episodes)* An episode can end before it starts, where an
  encounter's `end_datetime` precedes a later history row — the intermediates compute
  `end_datetime` as `coalesce(lead(start_datetime), encounters.end_datetime)` and do not
  guard the ordering. Such an episode spans no month, so the overlap join in `-by-area`
  and `-by-location` excludes it from **every** month and its admission, discharge and
  death are reported nowhere. `-by-department` admits it into the month it started
  (BL-010), so the three reports disagree on these episodes. That admission is no longer
  the whole episode: since BL-006 counts end-of-episode events in the month the episode
  ended, and the started-in-month disjunct is the only month such an episode is grouped
  into, its discharge, death and transfer out are now counted nowhere in `-by-department`
  either. Resolution is OQ-003.

- **DV-007:** *(the death month is the encounter's, not the death's)* BL-006 counts a death
  in the month the episode **ended**, because the intermediates expose no `date_of_death` —
  they carry only the flag. The shipped notes define the column by the month the death
  *"was recorded"*. BL-004 requires the death to fall inside the encounter, so the episode's
  end is never earlier than the death and the two agree wherever an encounter is closed in
  the month the death occurred; on the data checked when BL-006 changed, all 20 flagged
  deaths did. They diverge for a death on 28 February in an encounter closed on 2 March,
  which is counted as a March death. Resolution is to carry `date_of_death` through the
  intermediates and filter the death count on it.

## Open questions

- **OQ-003** *(owner: Maui team; due: before the next behavioural change to these
  reports)* — how should the malformed episodes of DV-003 be treated? Dropping them
  everywhere makes the three consistent but loses real admissions; keeping them everywhere
  means deciding which month a negative-duration stay belongs to. Either is a behaviour
  change to `-by-area` and `-by-location` and needs its own row-level diff. The underlying
  data is worth a look first: an encounter ending before its own history is a source-side
  defect, not a reporting one.

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
| AC-015 | An episode admitted in one month and discharged in another contributes its admission to the first and its discharge to the second. | BL-006 | `test_hospital_admissions_by_department_length_of_stay`, `test_hospital_admissions_by_area_event_months`, `..._by_location_event_months` |
| AC-016 | A transfer crossing a month boundary is counted in the month of the move, as a transfer out for the dimension left and a transfer in for the one entered. | BL-006 | `test_hospital_admissions_by_department_event_months`, `..._by_area_event_months`, `..._by_location_event_months` |
| AC-017 | An ungrouped location's episodes appear in the intermediate with a null area. | BL-013 | `test_int__admission_history_location_ungrouped` |
| AC-018 | They also reach `-by-area`, as a null-area row reporting `N/A` occupancy. | BL-013 | `test_hospital_admissions_by_area_ungrouped` |

## Change log

| Date | Change |
|---|---|
| 2026-09-04 | Retrospective spec created for the three summaries and their two intermediates. Facility sensitivity partitioned in the intermediates (BL-012), resolving DV-001, with a sensitive twin added for each report. `-by-department` average length of stay aligned to the ended-in-month basis (BL-011). Death condition changed to interval containment (BL-004), resolving DV-004. Discharges and deaths counted in the month the episode ended (BL-006), resolving DV-005, and transfers out likewise (BL-006), resolving DV-006; the death month is the encounter's end month rather than `date_of_death`, recorded as DV-007. An ungrouped location's episodes are counted under a null area (BL-013), resolving DV-002. |

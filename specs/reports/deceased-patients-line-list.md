# dbt Model Spec: `deceased-patients-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `deceased-patients-line-list` (built on `ds__deaths`) |
| **Type** | dbt model (Tamanu report) |
| **Layer** | `report` (built on `ds__`) |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6671](https://linear.app/bes/issue/MAUI-6671/update-deceased-patients-line-list-to-show-all-records), [MAUI-7187](https://linear.app/bes/issue/MAUI-7187/align-the-deceased-patients-line-list-facility-with-the-tupaia-death) (facility) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-17 |
| **Last updated** | 2026-11-17 |

## Purpose

**Why does this model exist?** Clinicians and administrators need a line list of
deceased patients with the full death record (causes, manner, surgery, perinatal
details) for mortality review and reporting.

**Who consumes it?** Tamanu report users at facility and central level.

**Business context:** A deceased-patients line list is low-volume, so the
default view should surface every record rather than a recent window. The card
(MAUI-6671) sets the default date range to "all time" and notes that Tamanu
floors a blank "From date" at `1970-01-01 00:00:00`. A patient is considered
deceased when `patients.date_of_death` is set; a completed death form
(`patient_death_data`) is part of the death workflow but is not guaranteed —
partial-workflow and migrated deaths may have no form.

## Grain

**One row per:** deceased patient (a patient with `date_of_death` set). Death-record
detail columns are null when no death form exists.

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('ds__deaths') }}` | Patient demographics, death details, cause/manner of death, location, and surgery/perinatal fields. Lists every deceased patient; death-detail columns are null when no death form exists |

### Freshness expectations

Bases refreshed within 24 hours. Mortality review is periodic; intra-day
freshness is not required.

## Output schema

The report exposes the full death record. Columns are translated presentation
labels; the underlying dataset columns are documented on `ds__deaths`. Key
columns include patient identity (`display_id`, `first_name`, `last_name`,
`date_of_birth`, `age`, `sex`, `village`, `nationality`), death context
(`place_of_death`, `department`, `location_group`, `location`, `date_of_death`,
`attending_clinician`), cause/manner of death (`primary_cause_condition`,
`antecedent_cause_1/2`, `other_condition_1..4`, `manner_of_death`,
`external_cause_*`), surgery (`had_recent_surgery`, `last_surgery_date`,
`reason_for_surgery`), and perinatal fields (`was_pregnant`,
`pregnancy_contributed`, `was_fetal_or_infant`, `was_stillborn`,
`birth_weight`, `completed_weeks_of_pregnancy`, `age_of_mother`,
`condition_in_mother_affecting_fetus_or_newborn`, `death_within_day_of_birth`,
`hours_survived_since_birth`).

## Business logic

### Dataset (`ds__deaths`)

- **BL-009:** Include every patient with `date_of_death` set, driving from
  `patients` and left-joining death-record detail; a patient is not excluded
  for lacking a `patient_death_data` row.
- **BL-010:** Use only the `current` death record, and where more than one
  current record exists for a patient, prefer a finalised one; this keeps the
  dataset at one row per patient.
- **BL-011:** Death-record detail columns (cause, manner, surgery, perinatal)
  are null for patients without a death form.
- **BL-012:** `facility_id` is the death record's facility, falling back to the
  facility of the encounter the patient died in (BL-013) where the record names
  none and does not say the death was outside a health facility; null where
  neither applies. `place_of_death` is that facility's name, or `Died outside
  health facility` where the record says so. This matches `metric__death`
  (its BL-004).
- **BL-013:** The encounter the patient died in is the one whose span covers
  the date of death, taking the latest end, then the latest start; an encounter
  without an end does not match. `department`, `location_group` and `location`
  come from it.
- **BL-015:** A death whose BL-012 facility is set but is not a standard
  (non-sensitive) facility is excluded.

### Report (`deceased-patients-line-list`)

- **BL-001:** When the supplied `fromDate` is the "all time" sentinel
  (`1970-01-01` or earlier), apply no lower bound on `date_of_death`; otherwise
  filter `date_of_death >= fromDate`. This ensures migrated records with an
  unknown date of death (placeholder `1900-01-01`) appear under the default
  "all time" range.
- **BL-002:** Filter `date_of_death <= toDate`. A blank "To date" is floored by
  Tamanu to the current datetime.
- **BL-003:** Optional `causeOfDeath` parameter restricts output to rows whose
  `primary_cause_condition_id` matches; when null, no filter is applied.
- **BL-004:** Optional `mannerOfDeath` parameter restricts output to rows whose
  `manner_of_death` matches; when null, no filter is applied.
- **BL-005:** Optional `facilityId` parameter restricts output to rows whose
  `facility_id` matches; when null, no filter is applied.
- **BL-006:** Optional `antecedentCause` parameter matches against either
  `antecedent_cause_1_id` or `antecedent_cause_2_id`; when null, no filter is
  applied.
- **BL-007:** Optional `otherContributingCondition` parameter matches against
  any of `other_condition_1_id` through `other_condition_4_id`; when null, no
  filter is applied.
- **BL-008:** Output is sorted by `date_of_death` ascending.
- **BL-014:** The report runs on the all facilities data source only.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `patient_id` is `not_null` and `unique` in `ds__deaths` | BL-009, BL-010 | dbt schema test |
| AC-002 | A deceased patient with no `patient_death_data` row appears in `ds__deaths` with null death-detail columns | BL-009, BL-011 | manual / integration |
| AC-003 | With `defaultDateRange = allTime` and no dates entered, records with `date_of_death = 1900-01-01` are returned | BL-001 | manual / integration |
| AC-004 | With a `fromDate` later than `1970-01-01`, every returned row has `date_of_death >= fromDate` | BL-001 | manual / integration |
| AC-005 | When run with a `causeOfDeath` / `mannerOfDeath` / `facilityId` parameter, every returned row matches that filter | BL-003, BL-004, BL-005 | manual / integration |
| AC-006 | `facility_id` and `place_of_death` take the death record's facility, else the encounter died in's facility unless the death was outside a health facility, and the latest-started of encounters ending together is matched | BL-012, BL-013 | dbt unit test (`ac_006_ds__deaths_facility`) |
| AC-007 | A death whose facility is a sensitive facility has no row | BL-015 | dbt unit test (`ac_006_ds__deaths_facility`) |

## Lineage

```
patients ────────────┐
patient_death_data ──┤
encounters ──────────┼──► ds__deaths ──► deceased-patients-line-list
locations ───────────┤
facilities ──────────┘
```

## Open questions

_None outstanding._

## Divergence from current code

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-06-17 | Maui team | Initial retrospective spec (MAUI-6671): default the report to all time, treat the 1970-01-01 floor as unbounded, and rework `ds__deaths` to list every deceased patient (drive from `patients`, optional death form) so deaths without a `patient_death_data` record are no longer dropped |
| 2026-11-17 | Maui team | BL-012, BL-013: facility falls back to the encounter died in, as in `metric__death`, so filtering by facility matches the Tupaia death count (MAUI-7187). New AC-006. BL-014: the report runs on all facilities only. |
| 2026-11-22 | Maui team | BL-015, AC-007: a death at a sensitive facility is excluded, as the report is standard. |

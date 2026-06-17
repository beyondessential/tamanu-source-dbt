# dbt Model Spec: `deceased-patients-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `deceased-patients-line-list` (built on `ds__deaths`) |
| **Type** | dbt model (Tamanu report) |
| **Layer** | `report` (built on `ds__`) |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | @julianam-w |
| **Linear issue** | [MAUI-6671](https://linear.app/bes/issue/MAUI-6671/update-deceased-patients-line-list-to-show-all-records) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-17 |
| **Last updated** | 2026-06-17 |

## Purpose

**Why does this model exist?** Clinicians and administrators need a line list of
deceased patients with the full death record (causes, manner, surgery, perinatal
details) for mortality review and reporting.

**Who consumes it?** Tamanu report users at facility and central level.

**Business context:** A deceased-patients line list is low-volume, so the
default view should surface every record rather than a recent window. The card
(MAUI-6671) sets the default date range to "all time" and notes that Tamanu
floors a blank "From date" at `1970-01-01 00:00:00`.

## Grain

**One row per:** deceased patient death record (one row per patient with a
recorded death).

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('ds__deaths') }}` | Patient demographics, death details, cause/manner of death, location, and surgery/perinatal fields |

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

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | With `defaultDateRange = allTime` and no dates entered, records with `date_of_death = 1900-01-01` are returned | BL-001 | manual / integration |
| AC-002 | With a `fromDate` later than `1970-01-01`, every returned row has `date_of_death >= fromDate` | BL-001 | manual / integration |
| AC-003 | When run with a `causeOfDeath` / `mannerOfDeath` / `facilityId` parameter, every returned row matches that filter | BL-003, BL-004, BL-005 | manual / integration |

## Lineage

```
ds__deaths ──► deceased-patients-line-list
```

## Open questions

_None outstanding._

## Divergence from current code

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-06-17 | @julianam-w | Initial retrospective spec; default to all time and treat 1970-01-01 floor as unbounded (MAUI-6671) |

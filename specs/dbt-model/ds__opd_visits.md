# dbt Model Spec: `ds__opd_visits` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__opd_visits` |
| **Type** | dbt model (dataset) |
| **Layer** | `datasets` (standard) |
| **Materialisation** | `view` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

OPD (outpatient) visits dataset. One row per day per clinic (ward) with a count of
outpatient visits, disaggregated by facility, sex and OPD visit age band. Day
grain and additive, so it can be aggregated to any period downstream.

## Purpose

**What this measures.** Outpatient department visits. An encounter counts as OPD when
its **first encounter-history segment** is `clinic` or `vaccination`. The visit is
attributed to the **date and ward of that intake segment**.

**Why day grain, count only.** The dataset emits a single additive `count` measure at day
grain so it can be aggregated to any period (week/month/year) downstream. Encounter
duration is not included; see BL-005.

## Grain

**One row per** `(date, facility_id, location_group_id, location_group_name, sex,
age_group)`. The underlying subject is the **encounter** (its intake segment); rows are
aggregated counts. Ward-less encounters carry `location_group_id = 'locationgroup-Unknown'`
and `location_group_name = 'Unknown'` (an "unknown clinic" bucket) but are still counted in
the visit total; `facility_id` is unaffected by a missing ward (see BL-003) and is only
NULL when the encounter has no location at all.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `date` | date | Calendar day of the intake segment. `data_table_filter: date` |
| `facility_id` | uuid | Facility of the visit's location (`bases/locations.facility_id`), independent of ward. NULL only when the encounter has no location. `data_table_filter: array` |
| `tupaia_facility_id` | text | `facility_id` mapped to Tupaia's id via the deployment's `tupaia_facility_mapping` seed (see BL-006). NULL if the deployment hasn't configured this mapping, or the facility has no entry. `data_table_filter: array` |
| `location_group_id` | uuid | Ward (the "clinic"). `'locationgroup-Unknown'` (not a real FK value) when no ward; otherwise FK → `ref__care_site` ward-type rows. `data_table_filter: array` |
| `location_group_name` | text | Ward name; `'Unknown'` when no ward |
| `sex` | text | `clinical__person.gender_source_value` |
| `age_group` | text | OPD visit age band at the visit date (see BL-004) |
| `total_opd_visits` | integer | `count(*)` of OPD visits. `data_table_metric: sum` |

## Business logic

- **BL-001:** Grain is one row per `(date, facility_id, location_group_id,
  location_group_name, sex, age_group)`. Sourced from `clinical__` models, `ref__care_site`,
  `bases/locations` (BL-003), and a deployment-only seed (BL-006) — see Dependencies.
- **BL-002 (OPD inclusion + intake attribution):** OPD visits are the **first** segment of
  each encounter (`clinical__visit_detail` where `preceding_visit_detail_id is null`) whose
  `visit_detail_source_value in ('clinic', 'vaccination')`, covering **both** clinic and
  vaccination. `date` and `location_group_id` come from that intake segment.
- **BL-003 (facility + clinic name, resolved independently):** `facility_id` and the clinic
  name are two separate lookups, not a chain. `facility_id` is joined from `bases/locations`
  (`clinical__visit_detail.location_id` → `locations.facility_id`) — a location always
  carries its own facility, regardless of whether it also has a ward. `location_group_name`
  is joined from `ref__care_site` (`care_site_type = 'ward'`) on the intake segment's
  `care_site_id`. Only the **clinic** is genuinely unknown when there's no ward:
  `location_group_name` is coalesced to `'Unknown'` and `location_group_id` to
  `'locationgroup-Unknown'` (a sentinel, not a real `ref__care_site` id) in that case, while
  `facility_id` is left populated. `facility_id` is only NULL when the encounter has no
  location at all (or that location was later soft-deleted). A future `relationships` test
  on `location_group_id` must exclude the `'locationgroup-Unknown'` sentinel rather than
  treat it as a broken FK.
- **BL-006 (Tupaia facility-id crosswalk, deployment-gated):** `tupaia_facility_id` maps
  `facility_id` through a `tupaia_facility_mapping` seed (columns `tamanu_facility_id`,
  `tupaia_facility_id`) that **only exists in a deployment's own repo** — `tamanu-source-dbt`
  never defines this seed itself. The join is gated behind
  `var('has_tupaia_facility_mapping', false)`: when the flag is off (the default, including
  every standalone build of `tamanu-source-dbt`), the `ref()` to the seed is never rendered
  at all, so the model still compiles with no seed present, and `tupaia_facility_id` is
  simply NULL. A deployment that has set up its own mapping sets
  `has_tupaia_facility_mapping: true` in its own `dbt_project.yml` `vars:` block alongside
  supplying `seeds/tupaia_facility_mapping.csv`. If a deployment sets the flag `true` without
  providing the seed, the build fails loudly (missing `ref()`) rather than silently shipping
  blank Tupaia ids — this is intentional.
- **BL-004 (sex + age band):** `sex` from `clinical__person.gender_source_value`; age in
  whole years at the visit date is computed from `year_of_birth`/`month_of_birth`/
  `day_of_birth` and banded by the `standard_age_group` macro into
  `<1 / 1-4 / 5-14 / 15-49 / 50+`. The join to `clinical__person` is an inner join: `bases/
  patients` excludes soft-deleted and merged-away patients, so a visit whose patient was
  later deleted or merged is excluded from the dataset entirely, not counted with blank
  demographics.
- **BL-005 (no duration measure):** encounter duration is deliberately omitted. OPD/clinic
  encounters are auto-discharged, so `end - start` does not reflect real time spent and
  would misrepresent wait/consultation time. The additive measure is `total_opd_visits`
  (`count`) only.

## Acceptance criteria

None.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment (first history segment); OPD inclusion, date, ward, location |
| `clinical__person` | `clinical/` | Sex and birth date for age at visit |
| `locations` | `bases/` | `facility_id` of the visit's location (BL-003) |
| `ref__care_site` | `ref/` | Clinic (ward) name |
| `tupaia_facility_mapping` | deployment seed (not in `tamanu-source-dbt`) | Tamanu → Tupaia facility id crosswalk, gated by `has_tupaia_facility_mapping` (BL-006) |

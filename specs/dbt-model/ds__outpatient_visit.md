# dbt Model Spec: `ds__outpatient_visit` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__outpatient_visit` |
| **Type** | dbt model (dataset) |
| **Layer** | `datasets` (omop) |
| **Materialisation** | `view` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Outpatient visits dataset. One row per day per clinic (area) with a count of
outpatient visits, disaggregated by facility, sex and outpatient visit age band. Day
grain and additive, so it can be aggregated to any period downstream.

## Purpose

**What this measures.** Outpatient department visits. An encounter counts as outpatient
when its **first encounter-history segment** has OMOP visit concept **9202 (Outpatient
Visit)** — covering `clinic`, `vaccination`, and `imaging` encounter types. The visit is
attributed to the **date and area of that intake segment**.

**Why day grain, count only.** The dataset emits a single additive `count` measure at day
grain so it can be aggregated to any period (week/month/year) downstream. Encounter
duration is not included; see BL-005.

## Grain

**One row per** `(visit_detail_start_date, tamanu_facility_id, location_group_id,
location_group_name, sex, age_group)`. The underlying subject is the **encounter** (its
intake segment); rows are aggregated counts. Encounters with no resolvable area still
count, under a `'locationgroup-unknown'`/`'Unknown'` sentinel pair; `tamanu_facility_id`
is unaffected by a missing area and is NULL only when there's no location at all (BL-003).
`tupaia_facility_id` is never NULL — it's the data table's filter column, so it carries
`'Not available'` instead (BL-006).

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_detail_start_date` | date | Calendar day of the intake segment (OMOP `VISIT_DETAIL.visit_detail_start_date`). `data_table_filter: date` |
| `tamanu_facility_id` | uuid | Facility of the visit's location (`bases/locations.facility_id`), independent of area. NULL only when the encounter has no location. Not filterable — `tupaia_facility_id` is the filter column instead |
| `tupaia_facility_id` | text | `tamanu_facility_id` mapped to Tupaia's id via the deployment's `tupaia_facility_mapping` seed (see BL-006). `'Not available'` (never NULL) if the deployment hasn't configured this mapping, or the facility has no entry. `data_table_filter: array` |
| `location_group_id` | uuid | Area (the "clinic"). `'locationgroup-unknown'` (not a real FK value) when the area doesn't resolve; otherwise FK → `ref__care_site` area-type rows. `data_table_filter: array` |
| `location_group_name` | text | Area name; `'Unknown'` when the area doesn't resolve |
| `sex` | text | `clinical__person.gender_source_value` |
| `age_group` | text | Outpatient visit age band at the visit date, per the WHO primary age classification's range boundaries (see BL-004) |
| `total_outpatient_visits` | bigint | `count(*)` of outpatient visits. `data_table_metric: sum` |

## Business logic

- **BL-001:** Grain is one row per `(visit_detail_start_date, tamanu_facility_id,
  location_group_id, location_group_name, sex, age_group)`. Sourced from `clinical__`
  models, `ref__care_site`, `bases/locations` (BL-003), and a deployment-only seed (BL-006)
  — see Dependencies.
- **BL-002 (outpatient inclusion + intake attribution):** Outpatient visits are the
  **first** segment of each encounter (`clinical__visit_detail` where
  `preceding_visit_detail_id is null`) whose `visit_detail_concept_id = 9202` (OMOP
  'Outpatient Visit', from `map__omop_visit_type`). Filtering on the OMOP concept (not the
  raw `visit_detail_source_value`) ties inclusion to the OMOP-standard mapping — today that
  covers `clinic`, `vaccination`, **and `imaging`** (all three map to 9202).
  `visit_detail_start_date` and `location_group_id` come from that intake segment.
- **BL-003 (facility + clinic name, resolved independently):** `tamanu_facility_id` and the
  clinic name are two separate lookups, not a chain. `tamanu_facility_id` comes from
  `bases/locations` (`clinical__visit_detail.location_id` → `locations.facility_id`) — a
  location always carries its own facility, whether or not it has an area — so it's NULL
  only when the encounter has no location at all (or that location was later soft-deleted).

  The clinic (`location_group_name`/`location_group_id`) comes from `ref__care_site`
  (`care_site_type = 'area'`) on the intake segment's `care_site_id`. Both sentinels are
  driven off the same *joined* `care_site_id`, not the raw segment value —
  `location_group_id` is `coalesce(cs.care_site_id, 'locationgroup-unknown')`,
  `location_group_name` is `coalesce(cs.care_site_name, 'Unknown')` — so a missing area
  (never assigned, or soft-deleted since) always yields both sentinels together; a real
  `location_group_id` never pairs with an `'Unknown'` name, or vice versa.
- **BL-004 (sex + age band):** `sex` is `clinical__person.gender_source_value`. Age in
  whole years at the visit date is computed from `year_of_birth`/`month_of_birth`/
  `day_of_birth` and banded by the `age_group__who_primary_classification` macro (see its
  docstring for the band boundaries and source). The join to `clinical__person` is an inner
  join — `bases/patients` excludes soft-deleted and merged-away patients, so a visit whose
  patient was later deleted or merged is excluded from the dataset entirely, not counted
  with blank demographics.
- **BL-005 (no duration measure):** encounter duration is deliberately omitted. Outpatient/
  clinic encounters are auto-discharged, so `end - start` does not reflect real time spent
  and would misrepresent wait/consultation time. The additive measure is
  `total_outpatient_visits` (`count`) only.
- **BL-006 (Tupaia facility-id crosswalk, deployment-gated):** `tupaia_facility_id` maps
  `tamanu_facility_id` through a `tupaia_facility_mapping` seed (columns
  `tamanu_facility_id`, `tupaia_facility_id`) that **only exists in a deployment's own repo**
  — `tamanu-source-dbt` never defines it. The join is gated behind a namespaced flag,
  `var('integrations', {}).get('tupaia', {}).get('enabled', false)`, rather than a one-off
  boolean, so the `vars:` block doesn't grow a new flag per Tupaia mapping over time. When
  the flag is off (the default, including every standalone build), the `ref()` to the seed
  is never rendered, so the model compiles with no seed present. A deployment enables it
  via:
  ```yaml
  vars:
    integrations:
      tupaia:
        enabled: true
  ```
  in its own `dbt_project.yml`, alongside supplying `seeds/tupaia_facility_mapping.csv`.
  Enabling the flag without the seed fails the build loudly (missing `ref()`) rather than
  shipping a placeholder — intentional. The flag is deployment-wide for Tupaia, not
  per-mapping: enabling it commits the deployment to supplying every Tupaia seed this repo
  expects under it, not just this one.

  **Never NULL:** `tupaia_facility_id` is the model's `data_table_filter` column, and
  Tupaia's default array filter (`col = any(coalesce(:param, array[col]))`) silently drops
  rows where `col` is NULL — a NULL facility id would vanish from any view that doesn't pass
  an explicit filter. `tupaia_facility_id` is therefore `'Not available'` whenever a real
  value isn't available: the flag is off, the flag is on but the facility has no seed entry
  (`coalesce(tm.tupaia_facility_id, 'Not available')`), or (per BL-003) `tamanu_facility_id`
  itself is NULL.

## Acceptance criteria

None.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment (first history segment); outpatient inclusion, visit_detail_start_date, area, location |
| `clinical__person` | `clinical/` | Sex and birth date for age at visit |
| `locations` | `bases/` | `tamanu_facility_id` of the visit's location (BL-003) |
| `ref__care_site` | `ref/` | Clinic (area) name |
| `tupaia_facility_mapping` | deployment seed (not in `tamanu-source-dbt`) | Tamanu → Tupaia facility id crosswalk, gated by `integrations.tupaia.enabled` (BL-006) |

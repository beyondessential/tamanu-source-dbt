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

Outpatient visits dataset. One row per day per area with a count of
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

**One row per** `(visit_detail_start_date, yearmonth, tamanu_facility_id, location_group_id,
location_group_name, sex, age_group)`. `yearmonth` is derived from `visit_detail_start_date`
(BL-007) and does not change the grain — it is functionally dependent on
`visit_detail_start_date`, carried alongside it rather than replacing it. The underlying
subject is the **encounter** (its
intake segment); rows are aggregated counts. Encounters with no resolvable area still
count, under a `'locationgroup-unknown'`/`'Unknown'` sentinel pair. An encounter whose
location itself doesn't resolve (soft-deleted) is excluded from the dataset entirely
rather than surfaced with a NULL `tamanu_facility_id` (BL-003) — `tamanu_facility_id` is
therefore never NULL for any row present.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_detail_start_date` | date | Calendar day of the intake segment (OMOP `VISIT_DETAIL.visit_detail_start_date`). `data_table_filter: date` |
| `yearmonth` | text | The intake segment's calendar month as `'YYYY-MM'` (`to_char(visit_detail_start_date, 'YYYY-MM')`), alongside `visit_detail_start_date` rather than replacing it (BL-007). `data_table_filter: yearmonth` |
| `tamanu_facility_id` | uuid | Facility of the visit's location (`bases/locations.facility_id`), independent of area. Never NULL — an encounter whose location doesn't resolve is excluded from the dataset entirely (BL-003). `data_table_filter: array` |
| `location_group_id` | uuid | Area. `'locationgroup-unknown'` (not a real FK value) when the area doesn't resolve; otherwise FK → `bases/location_groups.id`. `data_table_filter: array` |
| `location_group_name` | text | Area name; `'Unknown'` when the area doesn't resolve |
| `sex` | text | `clinical__person.gender_source_value` |
| `age_group` | text | Outpatient visit age band at the visit date, per the WHO primary age classification's range boundaries (see BL-004) |
| `total_outpatient_visits` | bigint | `count(*)` of outpatient visits. `data_table_metric: sum` |

## Business logic

- **BL-001:** Grain is one row per `(visit_detail_start_date, yearmonth, tamanu_facility_id,
  location_group_id, location_group_name, sex, age_group)`. Sourced from `clinical__`
  models, `bases/locations` and `bases/location_groups` (BL-003), and a deployment-only
- **BL-002 (outpatient inclusion + intake attribution):** Outpatient visits are the
  **first** segment of each encounter (`clinical__visit_detail` where
  `preceding_visit_detail_id is null`) whose `visit_detail_concept_id = 9202` (OMOP
  'Outpatient Visit', from `map__omop_visit_type`). Filtering on the OMOP concept (not the
  raw `visit_detail_source_value`) ties inclusion to the OMOP-standard mapping — today that
  covers `clinic`, `vaccination`, **and `imaging`** (all three map to 9202).
  `visit_detail_start_date` comes from that intake segment; `location_group_id` is derived
  from its location (BL-003).
- **BL-003 (facility + area, resolved independently at this layer, with different join
  strictness):** `clinical__visit_detail.care_site_id` is the intake segment's own Tamanu
  location (BL-006 there) — `tamanu_facility_id` and the area are two separate lookups off
  that same location, not a chain, and both are rejoined from `bases/locations` directly at
  this dataset layer. The two joins have deliberately different strictness:

  - **`locations` — inner join.** Encounters always carry a location in practice, so a
    failure to match here (the segment's location has since been soft-deleted) is a
    genuine anomaly, not an expected case. The encounter is excluded from the dataset
    entirely rather than surfacing with a NULL `tamanu_facility_id` — losing the facility
    dimension silently would be worse than dropping the row outright, since
    `tamanu_facility_id` is the facility the visit is attributed to.
    `tamanu_facility_id` is therefore `locations.facility_id` directly, with no `coalesce`
    or sentinel: if the row exists in this dataset at all, it has a real facility.
  - **`location_groups` — left join.** Areas are sparse in Tamanu — most locations have
    none — so a missing `location_group` is the expected common case, not an anomaly. The
    encounter still counts, under the `'locationgroup-unknown'`/`'Unknown'` sentinel pair:
    `location_group_id` is `coalesce(lg.id, 'locationgroup-unknown')`, `location_group_name`
    is `coalesce(lg.name, 'Unknown')`. Both sentinels are driven off the same *joined*
    `location_groups` row, not the raw `location_group_id` value on `locations`, so a
    missing area (never assigned, or soft-deleted since) always yields both sentinels
    together; a real `location_group_id` never pairs with an `'Unknown'` name, or vice
    versa.
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
- **BL-006 (facility identity stays Tamanu's):** the dataset emits `tamanu_facility_id`
  and nothing else. It does **not** translate that into a consumer's own identifier.

  An earlier revision carried a `tupaia_facility_id` column, joined to a deployment-supplied
  `map__tupaia_facility` seed behind an `integrations.tupaia.enabled` var. That was
  withdrawn, for the reasons recorded in `metric__emergency_care` BL-009: it put one
  consumer's namespace in a shared model, it made the model's schema depend on a var, and
  in practice this model and `metric__emergency_care` ended up naming the same seed
  differently while gated on the same flag — so a deployment with the flag on had to supply
  two seeds of identical data or one model would not resolve.

  Translating a Tamanu facility id into a Tupaia entity code is a **consumer-layer**
  concern and is done there — for Tupaia, in the data table.

- **BL-007 (yearmonth):** `yearmonth` is
  `to_char(visit_detail_start_date, 'YYYY-MM')` — the intake segment's calendar month as
  text. It is carried alongside `visit_detail_start_date`, not instead of it, and does not
  change the grain (BL-001): it is functionally dependent on `visit_detail_start_date`.

## Acceptance criteria

None.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment (first history segment); outpatient inclusion, visit_detail_start_date, and its own location as `care_site_id` |
| `clinical__person` | `clinical/` | Sex and birth date for age at visit |
| `locations` | `bases/` | `tamanu_facility_id` and `location_group_id` of the visit's location (BL-003) |
| `location_groups` | `bases/` | Area (location_group) name, joined via the visit's location (BL-003) |

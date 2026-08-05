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
aggregated counts. Ward-less encounters carry `location_group_id = 'locationgroup-Unknown'`,
`location_group_name = 'Unknown'`, and `facility_id` = NULL (an "unknown clinic" bucket)
but are still counted in the visit total.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `date` | date | Calendar day of the intake segment. `data_table_filter: date` |
| `facility_id` | uuid | Parent facility of the ward, from `ref__care_site`. NULL when no ward. `data_table_filter: array` |
| `location_group_id` | uuid | Ward (the "clinic"). `'locationgroup-Unknown'` (not a real FK value) when no ward; otherwise FK → `ref__care_site` ward-type rows. `data_table_filter: array` |
| `location_group_name` | text | Ward name; `'Unknown'` when no ward |
| `sex` | text | `clinical__person.gender_source_value` |
| `age_group` | text | OPD visit age band at the visit date (see BL-004) |
| `total_opd_visits` | integer | `count(*)` of OPD visits. `data_table_metric: sum` |

## Business logic

- **BL-001:** Grain is one row per `(date, facility_id, location_group_id,
  location_group_name, sex, age_group)`. Sourced only from `clinical__` models and
  `ref__care_site`.
- **BL-002 (OPD inclusion + intake attribution):** OPD visits are the **first** segment of
  each encounter (`clinical__visit_detail` where `preceding_visit_detail_id is null`) whose
  `visit_detail_source_value in ('clinic', 'vaccination')`, covering **both** clinic and
  vaccination. `date` and `location_group_id` come from that intake segment.
- **BL-003 (facility + clinic name):** `location_group_name` and `facility_id` are joined
  from `ref__care_site` (`care_site_type = 'ward'`) on the intake segment's `care_site_id`;
  `facility_id` is the ward's denormalised parent facility. When the intake location has no
  ward, `location_group_name` is coalesced to `'Unknown'` and `location_group_id` to
  `'locationgroup-Unknown'` — a sentinel, not a real `ref__care_site` id. `facility_id` is
  left NULL (no equivalent sentinel), since the ward's facility genuinely can't be
  determined. A future `relationships` test on `location_group_id` must exclude this
  sentinel value rather than treat it as a broken FK.
- **BL-004 (sex + age band):** `sex` from `clinical__person.gender_source_value`; age in
  whole years at the visit date is computed from `year_of_birth`/`month_of_birth`/
  `day_of_birth` and banded by the `opd_visit_age_group` macro into
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
| `clinical__visit_detail` | `clinical/` | Intake segment (first history segment); OPD inclusion, date, ward |
| `clinical__person` | `clinical/` | Sex and birth date for age at visit |
| `ref__care_site` | `ref/` | Facility (`facility_id`) and clinic (ward) name |

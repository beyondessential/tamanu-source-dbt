# dbt Model Spec: `ds__emergency_visit` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__emergency_visit` |
| **Type** | dbt model (dataset) |
| **Layer** | `datasets` (omop) |
| **Materialisation** | `view` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.54`) |

Emergency department attendances dataset. One row per day per area with a count of ED
attendances, disaggregated by facility, sex and emergency visit age band. Day grain and
additive, so it can be aggregated to any period downstream.

Sibling of `ds__outpatient_visit` (PR #653, `feature/metric-opd-visits`, targeting `main`)
— same grain, same disaggregations, same Tupaia contract, differing only in the OMOP visit
concept that defines inclusion (9203 rather than 9202) and the name of the measure. The two
are deliberately shape-identical so a single Tupaia visual definition can be pointed at
either.

**Branch-line note.** This dataset is authored on the `2.54` line, where the OPD sibling is
not yet present. Two things follow, both isolated to BL-003 and Dependencies:

- `macros/age_group__who_primary_classification.sql` does not exist on `2.54`, so it is
  added here. It is byte-identical to the copy on `feature/metric-opd-visits`, so the two
  will not diverge when the lines converge.
- `ref__care_site` labels location_group rows `care_site_type = 'ward'` on this line;
  `feature/metric-opd-visits` renames that literal to `'area'`. This model joins on
  `'ward'` to match the line it builds on. Renaming `ref__care_site` is out of scope here —
  it would change the contract of the ported OMOP-lite clinical layer. When the rename
  reaches this line, the join literal is the single line to update.

## Purpose

**What this measures.** Emergency department attendances ("ED attendances"). An encounter
counts as an ED attendance when its **first encounter-history segment** has OMOP visit
concept **9203 (Emergency Room Visit)** — covering `emergency`, `triage`, and
`observation` encounter types. The attendance is attributed to the **date and area of that
intake segment**.

**Why day grain, count only.** The dataset emits a single additive `count` measure at day
grain so it can be aggregated to any period (week/month/year) downstream. ED length of
stay and time-to-triage are not included; see BL-005.

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
| `location_group_id` | uuid | Area (the ED area). `'locationgroup-unknown'` (not a real FK value) when the area doesn't resolve; otherwise FK → `ref__care_site` area-type rows. `data_table_filter: array` |
| `location_group_name` | text | Area name; `'Unknown'` when the area doesn't resolve |
| `sex` | text | `clinical__person.gender_source_value` |
| `age_group` | text | Emergency visit age band at the attendance date, per the WHO primary age classification's range boundaries (see BL-004) |
| `total_emergency_visits` | bigint | `count(*)` of ED attendances. `data_table_metric: sum` |

## Business logic

- **BL-001:** Grain is one row per `(visit_detail_start_date, tamanu_facility_id,
  location_group_id, location_group_name, sex, age_group)`. Sourced from `clinical__`
  models, `ref__care_site`, `bases/locations` (BL-003), and a deployment-only seed (BL-006)
  — see Dependencies.
- **BL-002 (ED inclusion + intake attribution):** ED attendances are the **first** segment
  of each encounter (`clinical__visit_detail` where `preceding_visit_detail_id is null`)
  whose `visit_detail_concept_id = 9203` (OMOP 'Emergency Room Visit', from
  `map__omop_visit_type`). Filtering on the OMOP concept (not the raw
  `visit_detail_source_value`) ties inclusion to the OMOP-standard mapping — today that
  covers `emergency`, `triage`, **and `observation`** (all three map to 9203).
  `visit_detail_start_date` and `location_group_id` come from that intake segment.

  **Intake-only, by design.** Anchoring on the first segment gives one row per patient
  arrival, which is what "attendance" means:
  - An encounter that arrives in the ED and is **later admitted** still counts — its
    intake segment is `triage`/`emergency`, so the attendance is recorded on the arrival
    day, in the ED area. (At the visit level such an encounter carries concept 262,
    'Emergency Room and Inpatient Visit', per `clinical__visit_occurrence` BL-002; this
    dataset reads `clinical__visit_detail`, so the 262 rollup does not affect it.)
  - An encounter that starts elsewhere (e.g. `admission`) and **passes through** an ED
    segment later does **not** count. That is intra-hospital movement, not an arrival, and
    counting it would double-count the same patient episode.
- **BL-003 (facility + area name, resolved independently):** `tamanu_facility_id` and the
  area name are two separate lookups, not a chain. `tamanu_facility_id` comes from
  `bases/locations` (`clinical__visit_detail.location_id` → `locations.facility_id`) — a
  location always carries its own facility, whether or not it has an area — so it's NULL
  only when the encounter has no location at all (or that location was later soft-deleted).

  The area (`location_group_name`/`location_group_id`) comes from `ref__care_site`
  (`care_site_type = 'ward'` — that line's label for location_group rows, see the
  branch-line note) on the intake segment's `care_site_id`. Both sentinels are
  driven off the same *joined* `care_site_id`, not the raw segment value —
  `location_group_id` is `coalesce(cs.care_site_id, 'locationgroup-unknown')`,
  `location_group_name` is `coalesce(cs.care_site_name, 'Unknown')` — so a missing area
  (never assigned, or soft-deleted since) always yields both sentinels together; a real
  `location_group_id` never pairs with an `'Unknown'` name, or vice versa.

  Areas are sparse in Tamanu, and ED encounters in particular are often recorded against a
  location with no area, so the `'Unknown'` bucket is expected to carry real volume here
  rather than being a rare data-quality tail.
- **BL-004 (sex + age band):** `sex` is `clinical__person.gender_source_value`. Age in
  whole years at the attendance date is computed from `year_of_birth`/`month_of_birth`/
  `day_of_birth` and banded by the `age_group__who_primary_classification` macro (see its
  docstring for the band boundaries and source). The join to `clinical__person` is an inner
  join — `bases/patients` excludes soft-deleted and merged-away patients, so an attendance
  whose patient was later deleted or merged is excluded from the dataset entirely, not
  counted with blank demographics.
- **BL-005 (no duration or triage measures):** ED length of stay, time-to-triage, and
  triage score are deliberately omitted. The additive measure is `total_emergency_visits`
  (`count`) only, keeping this dataset shape-identical to `ds__outpatient_visit` so one
  Tupaia visual definition serves both. Triage-score and wait-time disaggregations are a
  separate concern — `ds__encounters_emergency` already carries per-triage detail for
  report-style consumers, and a dedicated aggregate dataset should be added if Tupaia needs
  them, rather than widening this one.
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

## Open questions

- **OQ-001 (owner: Maui team):** `observation` encounters map to 9203 and therefore count
  as ED attendances whenever they are an encounter's intake segment. Confirm with the
  Queen of Sheba clinical team that a standalone `observation` intake is an ED arrival at
  their site, rather than a distinct short-stay ward. If it is not, the fix belongs in
  `map__omop_visit_type`, not here — BL-002 keys on the concept precisely so inclusion
  changes with the mapping.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment (first history segment); ED inclusion, visit_detail_start_date, area, location |
| `clinical__person` | `clinical/` | Sex and birth date for age at attendance |
| `locations` | `bases/` | `tamanu_facility_id` of the visit's location (BL-003) |
| `ref__care_site` | `ref/` | ED area name (`care_site_type = 'ward'` on this line) |
| `age_group__who_primary_classification` | `macros/` | Age banding (BL-004); added by this change on `2.54` |
| `tupaia_facility_mapping` | deployment seed (not in `tamanu-source-dbt`) | Tamanu → Tupaia facility id crosswalk, gated by `integrations.tupaia.enabled` (BL-006) |

## Related

| Artefact | Relationship |
|---|---|
| `ds__outpatient_visit` (PR #653, not on `2.54`) | Sibling dataset (OMOP concept 9202); identical grain, disaggregations and Tupaia contract |
| `models/datasets/standard/ds__encounters_emergency.sql` | Report-layer emergency dataset at triage grain, with PII; not a Tupaia aggregate (see BL-005) |
| MAUI-6694 | Queen of Sheba Hospital, Ghana — Hospital Administration → Emergency → "ED attendances" |

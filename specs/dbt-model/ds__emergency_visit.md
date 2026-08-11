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
attendances, disaggregated by facility, sex, emergency visit age band, and whether the
attendance led to an inpatient admission. Day grain and additive, so it can be aggregated to
any period downstream.

Sibling of `ds__outpatient_visit` (PR #653, `feature/metric-opd-visits`, targeting `main`) —
same Tupaia contract and the same seven shared columns, differing in the OMOP visit concept
that defines inclusion (9203 rather than 9202), the name of the measure, and one ED-specific
dimension: `is_inpatient_admission` (BL-007). A Tupaia visual built on the shared columns
works against either dataset; the admission split is available only here, since it has no
outpatient analogue.

**Branch-line note.** This dataset is authored on the `2.54` line, where the OPD sibling is
not yet present. `macros/age_group__who_primary_classification.sql` does not exist on
`2.54`, so it is added here — byte-identical to the copy on `feature/metric-opd-visits`, so
the two will not diverge when the lines converge.

**Layering note.** Area (`location_group`) is resolved directly from `bases/locations` →
`bases/location_groups` at this dataset layer (BL-003), not from `ref__care_site` or from
`clinical__visit_detail`. The `clinical__` layer's own `care_site_id` is location-grained
(room/bed, `clinical__visit_detail` BL-006) — a deliberate OMOP-shape choice at that layer,
unrelated to what a `ds__` dataset needs for a Tupaia "by area" disaggregation. Rather than
have this dataset inherit whatever grain the clinical layer happens to expose, it resolves
area for itself.

## Purpose

**What this measures.** Emergency department attendances ("ED attendances"). An encounter
counts as an ED attendance when its **first encounter-history segment** has OMOP visit
concept **9203 (Emergency Room Visit)** — covering `emergency`, `triage`, and
`observation` encounter types. The attendance is attributed to the **date and area of that
intake segment**. Attendances that went on to an inpatient admission — visit-level concept
**262** — are included and flagged by `is_inpatient_admission` (BL-002, BL-007).

**Why day grain, count only.** The dataset emits a single additive `count` measure at day
grain so it can be aggregated to any period (week/month/year) downstream. ED length of
stay and time-to-triage are not included; see BL-005.

## Grain

**One row per** `(visit_detail_start_date, tamanu_facility_id, location_group_id,
location_group_name, sex, age_group, is_inpatient_admission)`. The underlying subject is the
**encounter** (its intake segment); rows are aggregated counts. An encounter whose location
doesn't resolve in `bases/locations` (soft-deleted) is excluded from the dataset entirely —
not surfaced with a NULL `tamanu_facility_id` (BL-003). Encounters with no resolvable
**area**, by contrast, still count, under a `'locationgroup-unknown'`/`'Unknown'` sentinel
pair — area is sparse by default, unlike a missing location, which is anomalous. Everywhere
present in the dataset, `tamanu_facility_id` is therefore a real, non-NULL value.
`tupaia_facility_id` is never NULL — it's the data table's filter column, so it carries
`'Not available'` instead (BL-006). An encounter whose *current* `encounter_type` is
unmapped in `map__omop_visit_type` is also excluded entirely, via the inner join to
`clinical__visit_occurrence` (BL-007) — the same schema-drift risk as that model's own
grain, not a case specific to this dataset.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_detail_start_date` | date | Calendar day of the intake segment (OMOP `VISIT_DETAIL.visit_detail_start_date`). `data_table_filter: date` |
| `yearmonth` | text | Calendar month of the attendance, `'YYYY-MM'`. Functionally dependent on `visit_detail_start_date`, so it does not change the grain (BL-008). `data_table_filter: yearmonth` |
| `tamanu_facility_id` | uuid | Facility of the visit's location (`bases/locations.facility_id`), independent of area. Never NULL — an encounter whose location doesn't resolve is excluded from the dataset entirely (BL-003), not surfaced with a NULL value here. Not filterable — `tupaia_facility_id` is the filter column instead |
| `tupaia_facility_id` | text | `tamanu_facility_id` mapped to Tupaia's id via the deployment's `tupaia_facility_mapping` seed (see BL-006). `'Not available'` (never NULL) if the deployment hasn't configured this mapping, or the facility has no entry. `data_table_filter: array` |
| `location_group_id` | uuid | Area (the ED area). `'locationgroup-unknown'` (not a real FK value) when the area doesn't resolve; otherwise FK → `bases/location_groups.id`. `data_table_filter: array` |
| `location_group_name` | text | Area name; `'Unknown'` when the area doesn't resolve |
| `sex` | text | `clinical__person.gender_source_value` |
| `age_group` | text | Emergency visit age band at the attendance date, per the WHO primary age classification's range boundaries (see BL-004) |
| `is_inpatient_admission` | boolean | Whether the attendance became an inpatient admission — visit-level OMOP concept 262 (see BL-007). Never NULL. `data_table_filter: array` |
| `total_emergency_visits` | bigint | `count(*)` of ED attendances. `data_table_metric: sum` |

## Business logic

- **BL-001:** Grain is one row per `(visit_detail_start_date, tamanu_facility_id,
  location_group_id, location_group_name, sex, age_group, is_inpatient_admission)`. Sourced
  from `clinical__` models, `bases/locations` and `bases/location_groups` (BL-003), and a
  deployment-only seed (BL-006) — see Dependencies. `yearmonth` (BL-008) is also in the
  `group by` but is functionally dependent on `visit_detail_start_date`, so it adds no
  grain.
- **BL-002 (ED inclusion + intake attribution):** ED attendances are the **first** segment
  of each encounter (`clinical__visit_detail` where `preceding_visit_detail_id is null`)
  whose `visit_detail_concept_id = 9203` (OMOP 'Emergency Room Visit', from
  `map__omop_visit_type`). Filtering on the OMOP concept (not the raw
  `visit_detail_source_value`) ties inclusion to the OMOP-standard mapping — today that
  covers `emergency`, `triage`, **and `observation`** (all three map to 9203).
  `visit_detail_start_date` and `location_group_id` come from that intake segment.

  **Intake-only is complete for 262 too.** Tamanu encounters never transition from
  `admission` back into an ED-type phase — admission is a terminal state reached only via
  an ED-type phase, never the other way round. So any encounter that ever has an ED-type
  segment necessarily has one as its **first** segment; there is no admitted-via-ED
  encounter whose intake segment is something else. Consequently, the intake-only filter
  already captures every encounter `clinical__visit_occurrence` later flags 262 (see
  BL-007) — no widening to "any segment" is needed, and none is done. `is_inpatient_admission`
  only ever needs to *label* rows already included here, not admit new ones.

  **Intake-only, by design, for the rest.** Anchoring on the first segment gives one row per
  patient arrival, which is what "attendance" means: an encounter that starts elsewhere
  (e.g. `clinic`) and passes through an ED-type segment later does not count. That would be
  intra-hospital movement, not an arrival, and counting it would double-count the same
  patient episode.
- **BL-003 (facility + area, resolved independently at this layer, with different join
  strictness):** `tamanu_facility_id` and the area are two separate lookups, not a chain,
  and both are resolved directly from `bases/locations` at this dataset layer rather than
  through the `clinical__` layer. `clinical__` models don't carry facility or area — the
  `clinical__` layer's `care_site_id` is location-grained by design
  (`clinical__visit_detail` BL-006), and facility is not surfaced at that layer at all (its
  own BL-006 note); both are dataset-layer concerns, resolved here.

  Both lookups rejoin `bases/locations` on the segment's location
  (`clinical__visit_detail.care_site_id`, which is the segment's location itself), but the
  two joins have deliberately different strictness:

  - **`locations` — inner join.** Encounters always carry a `location_id` in practice, so
    a failure to match here (the segment's location has since been soft-deleted) is a
    genuine anomaly, not an expected case. The encounter is excluded from the dataset
    entirely rather than surfacing with a NULL `tamanu_facility_id` — losing the facility
    dimension silently would be worse than dropping the row outright, since
    `tamanu_facility_id` is the basis for the Tupaia facility filter (BL-006).
    `tamanu_facility_id` is therefore `locations.facility_id` directly, with no `coalesce`
    or sentinel: if the row exists in this dataset at all, it has a real facility.
  - **`location_groups` — left join.** Areas are sparse in Tamanu — most locations have
    none — so a missing `location_group` is the expected common case, not an anomaly. The
    encounter still counts, under the `'locationgroup-unknown'`/`'Unknown'` sentinel pair:
    `location_group_id` is `coalesce(lg.id, 'locationgroup-unknown')`, `location_group_name`
    is `coalesce(lg.name, 'Unknown')`. Both sentinels are driven off the same *joined*
    `location_groups` row, not the raw segment value, so a missing area (no
    `location_group` assigned, or that `location_group` was soft-deleted) always yields
    both sentinels together; a real `location_group_id` never pairs with an `'Unknown'`
    name, or vice versa.

  This dataset does both rejoins itself rather than reading them off `clinical__visit_detail`
  or `ref__care_site`, because neither carries area, and `ref__care_site` accordingly
  carries only `department` and `location` grains, not `area` (see `ref__care_site`'s "Why
  two grains"). ED encounters in particular are often recorded against a location with no
  area, so the `'Unknown'` bucket is expected to carry real volume, unlike the (rare)
  exclusion case above.
- **BL-004 (sex + age band):** `sex` is `clinical__person.gender_source_value`. Age in
  whole years at the attendance date is computed from `year_of_birth`/`month_of_birth`/
  `day_of_birth` and banded by the `age_group__who_primary_classification` macro (see its
  docstring for the band boundaries and source). The join to `clinical__person` is an inner
  join — `bases/patients` excludes soft-deleted and merged-away patients, so an attendance
  whose patient was later deleted or merged is excluded from the dataset entirely, not
  counted with blank demographics.
- **BL-005 (no duration or triage measures):** ED length of stay, time-to-triage, and
  triage score are deliberately omitted. The additive measure is `total_emergency_visits`
  (`count`) only. Beyond `is_inpatient_admission` (BL-007), which is a plain encounter-level
  attribute, the dataset holds to `ds__outpatient_visit`'s shared column set so one Tupaia
  visual definition serves both. Triage-score and wait-time disaggregations are a separate
  concern — `ds__encounters_emergency` already carries per-triage detail for report-style
  consumers, and a dedicated aggregate dataset should be added if Tupaia needs them, rather
  than widening this one.
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
  Tupaia-side value isn't available: the flag is off, or the flag is on but the facility has
  no seed entry (`coalesce(tm.tupaia_facility_id, 'Not available')`). `tamanu_facility_id`
  itself is never NULL here (per BL-003), so that case doesn't arise.
- **BL-007 (inpatient admission flag):** `is_inpatient_admission` is true when the
  encounter's **visit-level** OMOP concept is **262** ('Emergency Room and Inpatient
  Visit'), read from `clinical__visit_occurrence.visit_concept_id`. Per that model's BL-002,
  262 is assigned to an `admission` encounter whose `encounter_history` contains an
  `emergency`, `triage` or `observation` phase — precisely "arrived via the ED, ended up an
  inpatient". Grouping on the flag therefore yields the ED-to-admission conversion rate
  directly, with no second dataset and no re-derivation of admission logic here. Every 262
  encounter is already included by BL-002's intake filter (admission cannot precede ED, so
  its intake segment is an ED segment); this flag only labels those rows, it does not admit
  any encounter that BL-002 would otherwise exclude.

  **262 lives only at the visit level.** `clinical__visit_detail` never carries it: 262 is
  reachable in `map__omop_visit_type` only through the synthetic `admission_from_emergency`
  local code, which no `encounter_type` equals, and `clinical__visit_occurrence` applies it
  in a `CASE` rather than by lookup. So the flag requires joining
  `clinical__visit_occurrence`; it cannot be derived from the segment stream this dataset
  otherwise reads.

  **Join and NULL handling.** The join to `clinical__visit_occurrence` is an **inner** join,
  not a left join, and no `coalesce` is applied to `vo.visit_concept_id = 262`: neither is
  needed. `clinical__visit_occurrence`'s own BL-002 is itself an inner join to
  `map__omop_visit_type`, so `visit_concept_id` is never NULL for any row that model
  produces — `map__omop_visit_type` has no row with a NULL `concept_id`, not even
  `surveyResponse` (which maps to `0`, "No matching concept"). So there are only two
  possibilities here: either a `vo` row exists and its `visit_concept_id` is a real,
  non-null value, or no `vo` row exists at all and the inner join drops this dataset's row
  before `visit_concept_id` is ever evaluated. Either way, `is_inpatient_admission` is
  computed from a boolean comparison that can never itself be NULL.

  **This is not an unconditional guarantee, though — it is the same schema-drift risk as
  everywhere else `map__omop_visit_type` is used.** A `vo` row exists only if the
  encounter's *current* `encounter_type` (`clinical__visit_occurrence` reads
  `encounters.encounter_type` directly, not the intake segment's) is covered by the map.
  That can differ from the intake segment's `encounter_type` this dataset already filtered
  on — an ED-originated encounter that is later admitted has intake type `emergency` /
  `triage` / `observation` but current type `admission`. If `admission` were ever the type
  that fell out of map coverage (while the ED-type values stayed covered), this dataset's
  inner join to `vo` would silently drop that attendance even though its intake segment
  survived in `clinical__visit_detail`. This is not a new failure mode introduced by this
  dataset — it is `clinical__visit_occurrence`'s own BL-002 risk, already guarded by that
  model's AC-011 (`data_test__clinical__visit_occurrence`) and by
  `data_test__map__omop_visit_type_coverage` upstream of it.
- **BL-008 (`yearmonth`, a string period column for the Tupaia data table):** `yearmonth` is
  `to_char(visit_detail_start_date, 'YYYY-MM')`. It is functionally dependent on
  `visit_detail_start_date`, so adding it to the `group by` does not change the grain
  (BL-001) — every row that had a distinct date already had a distinct month.

  It exists because of a constraint in the consuming layer, not a modelling need. A Tupaia
  data table can only `group by` columns the dataset actually exposes, and Tupaia's report
  transform layer runs **alasql**, which has no date-to-month function — so a monthly chart
  built on `visit_detail_start_date` alone would have to pull every day's row into the
  transform engine and could not bucket them there anyway. Exposing `yearmonth` lets the
  database do that aggregation: a monthly ED-attendance chart fetches with
  `groupByColumns: ['yearmonth']` and gets one row per month.

  `'YYYY-MM'` as a **string** (not a date or an integer) is the established convention for
  Tupaia-facing datasets across this org — see `data-staging`'s `bes__phr_mel_*` models, and
  the `date_range_columns` list in `tupaia-data-product`'s data-table generator, which keys
  its start/end range parameters on `date_string` / `yearmonth` / `week_ending_sunday`.
  `visit_detail_start_date` is retained alongside it: it stays the day-grain, OMOP-faithful
  column, and the dataset remains additive to any period (BL-005).

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
| `clinical__visit_detail` | `clinical/` | Intake segment (first history segment); ED inclusion, visit_detail_start_date, and care_site_id (the segment's location, rejoined below for facility and area) (BL-002, BL-003) |
| `clinical__visit_occurrence` | `clinical/` | Visit-level concept 262 for the inpatient-admission flag (BL-007) |
| `clinical__person` | `clinical/` | Sex and birth date for age at attendance |
| `locations` | `bases/` | Rejoined on the segment's location for `facility_id` and `location_group_id` (BL-003) |
| `location_groups` | `bases/` | Area name and id (BL-003) |
| `age_group__who_primary_classification` | `macros/` | Age banding (BL-004); added by this change on `2.54` |
| `tupaia_facility_mapping` | deployment seed (not in `tamanu-source-dbt`) | Tamanu → Tupaia facility id crosswalk, gated by `integrations.tupaia.enabled` (BL-006) |

## Related

| Artefact | Relationship |
|---|---|
| `ds__outpatient_visit` (PR #653, not on `2.54`) | Sibling dataset (OMOP concept 9202); identical grain, disaggregations and Tupaia contract |
| `models/datasets/standard/ds__encounters_emergency.sql` | Report-layer emergency dataset at triage grain, with PII; not a Tupaia aggregate (see BL-005) |
| MAUI-6694 | Queen of Sheba Hospital, Ghana — Hospital Administration → Emergency → "ED attendances" |

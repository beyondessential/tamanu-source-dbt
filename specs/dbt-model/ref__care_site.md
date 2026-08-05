# dbt Model Spec: `ref__care_site` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `ref__care_site` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `ref` |
| **Materialisation** | `view` (always — OMOP health-system wrapper) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-01 |
| **Last updated** | 2026-07-01 |

OMOP `CARE_SITE` wrapper over Tamanu's care units. **Heterogeneous by design:** it holds
both Tamanu **departments** (the organizational care unit) and **location_groups**
(physical wards/areas) as care sites, discriminated by `care_site_type`. Gives
`clinical__` models a stable, OMOP-named join target for care-site context at whichever
grain they need. Resolves
[`clinical__visit_occurrence` OQ-1](clinical__visit_occurrence.md) — `care_site_id` on
`clinical__visit_occurrence` has a canonical FK target. See
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (`ref__` layer,
`ref__care_site` → OMOP `CARE_SITE`),
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (native UUID PK),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact represents.** One row per Tamanu care unit, at two grains that
coexist in the single OMOP `CARE_SITE` table (which is heterogeneous by design):
- **department** (`care_site_type = 'department'`) — the organizational unit an encounter
  is assigned to (`encounters.department_id`). Carried as an attribute on
  `clinical__visit_detail`, not a visit-level care-site FK.
- **ward** (`care_site_type = 'ward'`) — a physical `location_group` (ward/area). The
  care site on both `clinical__visit_occurrence` (per encounter) and
  `clinical__visit_detail` (per segment).

Each row is denormalised with its parent facility's id, name, and type.

**Why a wrapper.** Tamanu stores care-site structure as `departments` and
`location_groups`, each linked to a `facilities` row. `ref__care_site` gives downstream
models a typed, OMOP-named surface (`care_site_id`, `care_site_type`, `care_site_name`,
`place_of_service_source_value`) so they join to `ref__care_site`, not to raw base
tables — keeping the layer contract intact and portable across OMOP tooling (D2).

**Why both grains (the hybrid).** Both `clinical__visit_occurrence` and
`clinical__visit_detail` key `care_site_id` on the **ward** (location_group of the
encounter's / segment's location). Wards are physical and sparse — most Tamanu `locations`
have no `location_group`, and ~1 in 8 encounters has a location with no ward — so
`care_site_id` is NULL for those (accepted; NULLs are excluded from the FK test).

**Who reads it.** `clinical__visit_occurrence` and `clinical__visit_detail` (both
`care_site_id` FK → ward-type rows); `metric__` / `dataset__` models that disaggregate by
facility (see the `hypertension_controlled` worked example in D5, which joins
`ref__care_site` on `care_site_id`).

## Grain

**One row per:** care site — a Tamanu `department` **or** a `location_group` (ward), with
`care_site_type` discriminating. `care_site_id` is unique across both because department
and location_group ids occupy distinct UUID spaces. Soft-deleted rows are filtered by the
base models. The join to `bases/facilities` is many-to-one, so grain is preserved; it is a
`left join`, so a care site whose facility is unset or soft-deleted is still emitted with
the facility-derived columns NULL. Facility-level aggregation is available via the
denormalised `facility_id` / `facility_name` columns without a second model.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `care_site_id` | uuid | `departments.id` or `location_groups.id`. Native UUID PK — no remap to OMOP integer IDs (D1). OMOP `CARE_SITE.care_site_id` |
| `care_site_type` | text | `'department'` or `'ward'` — which Tamanu entity the row represents. Lets consumers pick the grain |
| `care_site_name` | text | `departments.name` or `location_groups.name`. OMOP `CARE_SITE.care_site_name` |
| `care_site_source_value` | text | `departments.code` or `location_groups.code`. OMOP `CARE_SITE.care_site_source_value` |
| `place_of_service_source_value` | text | `facilities.type`. OMOP `CARE_SITE.place_of_service_source_value`. NULL when the care site has no facility |
| `facility_id` | uuid | `departments.facility_id`. Parent facility FK, denormalised. NULL when unset |
| `facility_name` | text | `facilities.name`. Parent facility name, denormalised. NULL when the facility is unset/removed |

OMOP `CARE_SITE.location_id` is intentionally omitted — see BL-004.
`place_of_service_concept_id` is also omitted: OMOP's Place of Service vocabulary has no
standard concepts, so there is nothing domain-correct to populate. `facilities.type` is
retained as `place_of_service_source_value`; a deployment that has a place-of-service
vocabulary can derive the concept downstream.

## Business logic

- **BL-001:** One row per care site, sourced from `{{ ref('departments') }}`,
  `{{ ref('location_groups') }}`, and `{{ ref('facilities') }}` only (D10) — never
  `public.*`. Soft-delete filtering is inherited from the base models. The department and
  location_group id spaces are disjoint, so the union preserves a unique `care_site_id`;
  the facility join is many-to-one, so grain is preserved.
- **BL-002:** OMOP column naming is applied — `id → care_site_id`, `name → care_site_name`,
  `code → care_site_source_value` — for both departments and location_groups. The parent
  facility's `type` is carried verbatim as `place_of_service_source_value`. No
  `place_of_service_concept_id` is emitted: OMOP's Place of Service vocabulary has no
  standard concepts, so there is no domain-correct concept to populate (using a
  Visit-domain concept would be a domain mismatch a DQD run flags). The source value is
  retained so a deployment with a place-of-service vocabulary can derive the concept
  downstream without a schema change here.
- **BL-003:** The parent facility is denormalised onto each care site via a `left join`
  on `facility_id = facilities.id`, exposing `facility_id` and `facility_name`. The join
  is a **left** join so a care site with a missing or soft-deleted facility is still
  emitted, with the facility-derived columns (`facility_name`,
  `place_of_service_source_value`) NULL — a care site is never dropped because of a
  facility gap.
- **BL-004:** `location_id` (OMOP `CARE_SITE.location_id`) is not emitted. It would point
  to the care site's physical location, but Tamanu's `departments` / `facilities` carry
  no link to the `reference_data` geographic hierarchy `ref__location` is built from
  (that models patient village geography, not facility postal addresses): the facility
  address fields (`division`, `city_town`, `street_address`) are free text and
  `catchment_id` matches no `ref__location` row, so there is no value to back the column.
  Columns are added only when a real value backs them (the `ref__location` precedent);
  revisit if a deployment geocodes facility addresses into `ref__location`-compatible rows.
- **BL-005:** The model is the `union all` of two grains — departments
  (`care_site_type = 'department'`) and location_groups (`care_site_type = 'ward'`) —
  because OMOP `CARE_SITE` is a single heterogeneous table. Both
  `clinical__visit_occurrence` and `clinical__visit_detail` key `care_site_id` on
  **ward-type** rows (the encounter's / segment's location_group), which may be NULL since
  most Tamanu locations have no ward.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `care_site_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `care_site_id` is `unique` (one row per care site across both grains — relies on the disjoint department / location_group UUID spaces, BL-001) | grain | dbt `unique` |
| AC-003 | A department denormalises into a `care_site_type='department'` row carrying `facility_id`, `facility_name`, and `place_of_service_source_value` | BL-002, BL-003, BL-005 | dbt unit test (`test_ref__care_site_department_denormalises_facility`) |
| AC-004 | A care site whose facility is absent from `bases/facilities` is still emitted, with `facility_name` and `place_of_service_source_value` NULL | BL-003 | dbt unit test (`test_ref__care_site_orphan_care_site_yields_nulls`) |
| AC-005 | `care_site_type` is `not_null` and one of `department` / `ward` | BL-005 | dbt `not_null` + `accepted_values` |
| AC-006 | A location_group denormalises into a `care_site_type='ward'` row carrying its facility | BL-002, BL-005 | dbt unit test (`test_ref__care_site_ward_from_location_group`) |

## Registry entry

None. `ref__` models are OMOP health-system wrappers, not indicators or derived
elements (only `metric__` / `derived__` get a `metric_definitions.csv` row).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `departments` | `bases/` | Department care sites (id, code, name) and parent facility link |
| `location_groups` | `bases/` | Ward care sites (id, code, name) and parent facility link |
| `facilities` | `bases/` | Parent facility name and type, denormalised onto each care site |

## Consumers

| Model | Use |
|---|---|
| `clinical__visit_occurrence` | `care_site_id` FK → ward-type rows (AC-008 there) |
| `clinical__visit_detail` | `care_site_id` FK → ward-type rows (the segment's location_group) |
| `metric__` / `dataset__` | facility-level disaggregation |

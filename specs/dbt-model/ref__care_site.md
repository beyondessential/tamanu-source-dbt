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
| **Last updated** | 2026-08-11 |

OMOP `CARE_SITE` wrapper over Tamanu's care units. **Heterogeneous by design:** it holds
Tamanu **departments** (the organizational care unit) and **locations** (physical
rooms/beds) as care sites, discriminated by `care_site_type`. Gives `clinical__` models a
stable, OMOP-named join target for care-site context at whichever grain they need. Resolves
[`clinical__visit_occurrence` OQ-1](clinical__visit_occurrence.md) — `care_site_id` on
`clinical__visit_occurrence` has a canonical FK target. See
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (`ref__` layer,
`ref__care_site` → OMOP `CARE_SITE`),
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (native UUID PK),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact represents.** One row per Tamanu care unit, at two grains that
coexist in the single OMOP `CARE_SITE` table (which is heterogeneous by design):
- **department** (`care_site_type = 'department'`) — the organizational unit. Carried as
  an attribute on `clinical__visit_detail`; not itself a visit-level care site.
- **location** (`care_site_type = 'location'`) — an individual physical room/bed. The care
  site on both `clinical__visit_occurrence` (per encounter) and `clinical__visit_detail`
  (per segment).

Each row is denormalised with its parent facility's id, name, and type.

Location_groups (areas) are **not** a grain here. A consumer that needs area-level context
joins `bases/locations` → `bases/location_groups` directly — that link is a consumer-layer
concern, not a `ref__care_site` one (see `metric__emergency_care` BL-007, which resolves
facility the same way and notes why area is not a disaggregation there).

**Why a wrapper.** Tamanu stores care-site structure as `departments` and `locations`, each
linked to a `facilities` row. `ref__care_site` gives downstream models a typed, OMOP-named
surface (`care_site_id`, `care_site_type`, `care_site_name`,
`place_of_service_source_value`) so they join to `ref__care_site`, not to raw base
tables — keeping the layer contract intact and portable across OMOP tooling (D2).

**Why two grains.** Both `clinical__` models key `care_site_id` on the **location** itself,
not department. Location is used because every encounter's / segment's location resolves
whenever it has one at all. Department is organizational rather than physical, so it is not
used as `care_site_id` by either `clinical__` model; it is retained here as an available
grain, carried as an attribute on `clinical__visit_detail`.

**Who reads it.** `clinical__visit_occurrence` (`care_site_id` FK → location-type rows);
`clinical__visit_detail` (`care_site_id` FK → location-type rows); `metric__` / `dataset__`
models that disaggregate by facility (see the `hypertension_controlled` worked example in
D5, which joins `ref__care_site` on `care_site_id`).

## Grain

**One row per:** care site — a Tamanu `department`, a `location` **or** a `facility`, with
`care_site_type` discriminating. `care_site_id` is unique across all three because
department, location and facility ids occupy disjoint UUID spaces. Soft-deleted rows are filtered by the base
models. The join to `bases/facilities` is many-to-one, so grain is preserved; it is a
`left join`, so a care site whose facility is unset or soft-deleted is still emitted with
the facility-derived columns NULL. Facility-level aggregation is available via the
denormalised `facility_id` / `facility_name` columns without a second model.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `care_site_id` | uuid | `departments.id`, `locations.id` or `facilities.id`. Native UUID PK — no remap to OMOP integer IDs (D1). OMOP `CARE_SITE.care_site_id` |
| `care_site_type` | text | `'department'`, `'location'` or `'facility'` — which Tamanu entity the row represents. Lets consumers pick the grain |
| `care_site_name` | text | `departments.name`, `locations.name` or `facilities.name`. OMOP `CARE_SITE.care_site_name` |
| `care_site_source_value` | text | `departments.code`, `locations.code` or `facilities.code`. OMOP `CARE_SITE.care_site_source_value` |
| `place_of_service_source_value` | text | `facilities.type`. OMOP `CARE_SITE.place_of_service_source_value`. NULL when the care site has no facility |
| `facility_id` | uuid | `departments.facility_id` or `locations.facility_id` (matching the row's grain); on a facility row, the facility's own id. Parent facility FK, denormalised. NULL when unset |
| `facility_name` | text | `facilities.name`. Parent facility name, denormalised. NULL when the facility is unset/removed |

OMOP `CARE_SITE.location_id` is intentionally omitted — see BL-004.
`place_of_service_concept_id` is also omitted: OMOP's Place of Service vocabulary has no
standard concepts, so there is nothing domain-correct to populate. `facilities.type` is
retained as `place_of_service_source_value`; a deployment that has a place-of-service
vocabulary can derive the concept downstream.

## Business logic

- **BL-001:** One row per care site, sourced from `{{ ref('departments') }}`,
  `{{ ref('locations') }}`, and `{{ ref('facilities') }}` only (D10) — never `public.*`.
  Soft-delete filtering is inherited from the base models. The department, location and
  facility id spaces are disjoint, so the union preserves a unique `care_site_id`; the
  facility join is many-to-one, so grain is preserved.
- **BL-002:** OMOP column naming is applied — `id → care_site_id`, `name → care_site_name`,
  `code → care_site_source_value` — across both grains. The parent
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
- **BL-005:** The model is the `union all` of three grains — departments
  (`care_site_type = 'department'`), locations (`care_site_type = 'location'`) and
  facilities (`care_site_type = 'facility'`, BL-007) —
  because OMOP `CARE_SITE` is a single heterogeneous table. `care_site_id` on both
  `clinical__visit_occurrence` and `clinical__visit_detail` is FK-tested against
  location-type rows here (the encounter's / segment's physical location). Neither model
  joins `bases/locations` to produce it — both carry their raw `location_id` straight
  through (their own BL-006 in each spec) and rely on the FK test alone for validation. A
  `location_id` pointing at a since-soft-deleted location will not resolve to a row here
  (which sources from `bases/locations`, excluding soft-deleted rows), so the FK test would
  flag it — an accepted, low-stakes gap given project-wide `severity: warn`. Department-type
  rows exist in this model but are not currently joined or FK-tested by either `clinical__`
  model's `care_site_id` — they remain an available grain (`clinical__visit_detail.
  department_id` reads them as an attribute FK target).
- **BL-006:** The `location` grain (`care_site_type = 'location'`, sourced from
  `{{ ref('locations') }}`) wraps **every** Tamanu location as its own care site. It exists
  so that `clinical__visit_occurrence.care_site_id` and `clinical__visit_detail.care_site_id`
  (both real `locations.id`-shaped values, their own BL-006 in each spec) have a row to
  resolve against.
- **BL-007:** The `facility` grain wraps every Tamanu facility as a care site in its own
  right. It exists so `clinical__episode.care_site_id` has a row to resolve against: an
  enrolment is registered at a facility and never at a department or a room, so its care
  site is coarser than a visit's. Without this grain a facility-shaped FK in `clinical__`
  would have to point at `bases/facilities`, which D2 forbids — `clinical__` models join
  `ref__` wrappers, not bases, so the layer contract holds and the models stay portable
  across OMOP tooling. A facility row's `facility_id` is its own id, so facility-level
  aggregation over the column works uniformly across all three grains.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `care_site_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `care_site_id` is `unique` (one row per care site across all three grains — relies on the disjoint department / location / facility UUID spaces, BL-001) | grain | dbt `unique` |
| AC-003 | A department denormalises into a `care_site_type='department'` row carrying `facility_id`, `facility_name`, and `place_of_service_source_value` | BL-002, BL-003, BL-005 | dbt unit test (`test_ref__care_site_department_denormalises_facility`) |
| AC-004 | A care site whose facility is absent from `bases/facilities` is still emitted, with `facility_name` and `place_of_service_source_value` NULL | BL-003 | dbt unit test (`test_ref__care_site_orphan_care_site_yields_nulls`) |
| AC-005 | `care_site_type` is `not_null` and one of `department` / `location` / `facility` | BL-005, BL-007 | dbt `not_null` + `accepted_values` |
| AC-006 | A location denormalises into a `care_site_type='location'` row carrying its facility | BL-002, BL-006 | dbt unit test (`test_ref__care_site_location_denormalises_facility`) |
| AC-007 | A facility becomes a `care_site_type='facility'` row whose `facility_id` is its own id | BL-002, BL-007 | dbt unit test (`test_ref__care_site_facility_is_its_own_care_site`) |

## Registry entry

None. `ref__` models are OMOP health-system wrappers, not indicators or derived
elements (only `metric__` / `derived__` get a `metric_definitions.csv` row).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `departments` | `bases/` | Department care sites (id, code, name) and parent facility link |
| `locations` | `bases/` | Location care sites (id, code, name) and parent facility link (BL-006) |
| `facilities` | `bases/` | Parent facility name and type, denormalised onto each care site |

## Consumers

| Model | Use |
|---|---|
| `clinical__visit_occurrence` | `care_site_id` FK → location-type rows (AC-008 there, its own BL-006) |
| `clinical__visit_detail` | `care_site_id` FK → location-type rows (the segment's location) |
| `clinical__episode` | `care_site_id` FK → facility-type rows (the registering facility, BL-007) |
| `metric__` / `dataset__` | facility-level disaggregation |

# dbt Model Spec: `ref__location` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `ref__location` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `ref` |
| **Materialisation** | `view` (always — OMOP health-system wrapper) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-28 |
| **Last updated** | 2026-06-29 |

OMOP `LOCATION` wrapper over Tamanu's geographic reference data. Gives `clinical__`
models a stable, OMOP-named join target for patient geography. See
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (ref__ layer),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact represents.** One row per village, wrapped in OMOP `LOCATION`
column naming and **denormalised** so each village also carries its `county`
(subdivision), `state` (division), and `country_source_value` (country) — resolved by
walking the reference-data hierarchy. `clinical__person.location_id` resolves to a row
here, exposing the village's full geographic context in one row.

**Why a wrapper.** Tamanu stores geography as `reference_data` rows of varying `type`,
linked by `reference_data_relations`. `ref__location` gives downstream models a typed,
OMOP-named surface (`location_id`, `location_source_value`) so they join to
`ref__location`, not to raw `reference_data` — keeping the layer contract intact and
portable across OMOP tooling (D2).

**Who reads it.** `clinical__person` (patient location FK) and any geographic
disaggregation in `metric__` / `dataset__`. (`ref__care_site` does not currently join
here — Tamanu facilities carry no `reference_data` geographic link; see
[`ref__care_site` OQ-2](ref__care_site.md#open-questions).)

## Grain

**One row per:** village. Soft-deleted reference data is already filtered by the base
model. The other geographic levels (subdivision, division, country, and any
intermediate settlement) are not emitted as rows — they are walked as ancestors and
denormalised onto each village.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `location_id` | uuid | The village's `reference_data.id`. Native UUID PK — no remap to OMOP integer IDs (D1). OMOP `LOCATION.location_id` |
| `location_source_value` | text | The village's `reference_data.code`. OMOP `LOCATION.location_source_value` |
| `city` | text | The village's `reference_data.name`. OMOP `LOCATION.city` |
| `county` | text | Name of the village's `subdivision`-level ancestor. OMOP `LOCATION.county`. NULL if absent |
| `state` | text | Name of the village's `division`-level ancestor. OMOP `LOCATION.state`. NULL if absent |
| `country_source_value` | text | Name of the village's `country`-level ancestor. OMOP `LOCATION.country_source_value`. NULL if absent |

The remaining OMOP `LOCATION` columns (`address_1`, `address_2`, `zip`,
`country_concept_id`, `latitude`, `longitude`) are omitted: Tamanu's reference-data
geography carries no street/postal/geocode detail, and `country_concept_id` would
require a `map__omop_country` seed that isn't yet in use (the "only add columns when
used" principle, derived-elements-conventions § map__omop seeds).

## Business logic

- **BL-001:** Source only from `{{ ref('reference_data') }}` and
  `{{ ref('reference_data_relations') }}` (D10) — never `public.*`. Soft-delete
  filtering is inherited from the base models.
- **BL-002:** The `reference_data` working set keeps every level of the address
  hierarchy — `type in ('village', 'settlement', 'subdivision', 'division', 'country')`
  — so the ancestor chain above a village stays connected even where an intermediate
  level sits between two emitted levels. Only `village` rows are emitted in the final
  output (one row per village). `village` is the confirmed type used across the repo;
  the remainder are the standard Tamanu address levels. The parent links walked are
  constrained to those whose **both** ends are geographic places, so the walk stays
  inside the address hierarchy without depending on the relation's own `type` value.
- **BL-003:** Walk the hierarchy with a recursive CTE anchored on villages: each
  village is paired with itself and every ancestor reachable through
  `reference_data_relations` (`reference_data_id` = child,
  `reference_data_parent_id` = parent).
- **BL-004:** The village's own `name` is the OMOP `city`. Each ancestor level maps
  onto its OMOP `LOCATION` column where available — `subdivision → county`,
  `division → state`, `country → country_source_value` — taking the ancestor's `name`.
  An absent level yields NULL. This `case` is the single per-deployment adjustment
  point if a deployment's level→column correspondence differs.
  `reference_data.id → location_id` and `reference_data.code → location_source_value`
  apply OMOP naming.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `location_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `location_id` is `unique` (one row per village) | grain | dbt `unique` |
| AC-003 | A village whose ancestry runs village → subdivision → division → country denormalises into one row with `city`, `county`, `state`, and `country_source_value` all populated | BL-003, BL-004 | dbt unit test (`test_ref__location_denormalises_full_hierarchy`) |
| AC-004 | A level absent from a village's ancestry comes through NULL (e.g. parent is a division directly: `county` and `country_source_value` NULL, `state` populated) | BL-004 | dbt unit test (`test_ref__location_partial_hierarchy_yields_nulls`) |
| AC-005 | An intermediate level (settlement) between a village and its subdivision is walked through, not dropped, so `county` still resolves from the subdivision above it | BL-002 | dbt unit test (`test_ref__location_walks_through_intermediate_settlement`) |

## Registry entry

None. `ref__` models are OMOP health-system wrappers, not indicators or derived
elements (only `metric__` / `derived__` get a `metric_definitions.csv` row).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `reference_data` | `bases/` | Geographic places (villages, divisions, …) |
| `reference_data_relations` | `bases/` | Parent/child links between places (the hierarchy walked to denormalise) |

## Consumers

| Model | Use |
|---|---|
| `clinical__person` | `location_id` FK → patient's village |

## Open questions

- **OQ:** Whether `country_concept_id` (a `map__omop_country` seed) and structured
  street/postal/geocode columns are worth adding if a deployment carries that detail.
- **Note:** The level→OMOP-column mapping (BL-004) assumes the standard Tamanu address
  hierarchy. A deployment whose levels map differently adjusts the single `case` block;
  no consumer change is required.

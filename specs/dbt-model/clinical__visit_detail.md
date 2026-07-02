# dbt Model Spec: `clinical__visit_detail` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__visit_detail` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-01 |
| **Last updated** | 2026-07-01 |

The OMOP-lite `VISIT_DETAIL` domain — the intra-visit phase breakdown that sits **below**
[`clinical__visit_occurrence`](clinical__visit_occurrence.md). Where `VISIT_OCCURRENCE`
has one row per encounter reflecting its final/current type, `VISIT_DETAIL` has one row
per **segment** of that encounter: each department/location/encounter-type phase the
patient passed through, with its own datetime range. Resolves the intra-visit-transitions
question raised on [`clinical__visit_occurrence`](clinical__visit_occurrence.md). See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per encounter *segment* — a contiguous
period during which the encounter's department, location, and encounter_type were
stable. In Tamanu an ER-to-admission flow is a **single encounter** whose type and
placement change over time (recorded in `encounter_history`); `VISIT_DETAIL` unfolds
those changes into one row per phase, each keyed to its parent `visit_occurrence_id`.

**Clinical context.** `clinical__visit_occurrence` deliberately collapses an encounter
to one row (BL-002 there uses concept 262 to flag an ER→inpatient episode, but does not
expose the individual phases). Analytics that need per-phase timing — length of stay by
department, time-in-ER before admission, ward-transfer counts — need the segment grain
that `VISIT_DETAIL` provides.

**Who reads it.** `metric__` length-of-stay and transfer indicators; `dataset__`
admission audit line-lists; any analysis that must attribute time to a specific
department or ward within a single encounter.

## Grain

**One row per:** encounter segment (a stable department/location/encounter_type phase).
Parent `visit_occurrence_id` is many-to-one from segments, so `clinical__visit_detail`
fans out relative to `clinical__visit_occurrence` — this is expected and is the whole
point of the model. Segment boundaries come from `encounter_history` change events; an
encounter with no history at all contributes exactly one segment (BL-005), so every
encounter is represented by at least one row.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_detail_id` | uuid | Segment PK — the `encounter_history.id` that opens the segment, or the `encounters.id` for a synthesized whole-visit segment (BL-005). Native UUID (D1) |
| `visit_occurrence_id` | uuid | Parent encounter. FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `person_id` | uuid | Patient (`encounters.patient_id`) |
| `visit_detail_concept_id` | integer | OMOP Visit concept for this segment's `encounter_type`, from `map__omop_visit_type`. NULL if unmapped |
| `visit_detail_start_date` | date | Date component of `visit_detail_start_datetime` |
| `visit_detail_start_datetime` | timestamp | Segment start (the `encounter_history` event datetime, or the encounter start for a synthesized segment) |
| `visit_detail_end_date` | date | Date component of `visit_detail_end_datetime`. NULL for the final segment of an open encounter |
| `visit_detail_end_datetime` | timestamp | Segment end (next segment's start, or the encounter `end_datetime`; NULL for the final segment of an open encounter) |
| `care_site_id` | uuid | Segment **ward** — the `location_group` of the segment's location, resolved via `locations`. FK to `ref__care_site.care_site_id` (ward-type rows). NULL when the location has no ward (BL-006) |
| `department_id` | uuid | Segment department (`encounter_history.department_id`) — organizational unit, carried as an attribute (BL-007). FK to `ref__care_site.care_site_id` (department-type rows) |
| `location_id` | uuid | Segment room/bed (`encounter_history.location_id`) — finer than the ward care site, carried raw (BL-007) |
| `provider_id` | uuid | Segment clinician (`encounter_history.clinician_id`) |
| `visit_detail_source_value` | text | Segment `encounter_type`, retained verbatim (D1) |
| `preceding_visit_detail_id` | uuid | The prior segment's `visit_detail_id` in the same encounter; NULL for the first segment |

## Business logic

- **BL-001:** One row per encounter segment, sourced from `{{ ref('encounter_history') }}`,
  `{{ ref('encounters') }}`, and `{{ ref('locations') }}` (for the ward lookup) only
  (D10) — never `public.*`. Soft-delete and test-patient filtering are inherited from the
  base models; a history row whose encounter is filtered out is dropped by the inner join
  to `encounters`.
- **BL-002:** `encounter_history` is a single timeline where each row is a full snapshot
  (department, location, encounter_type, clinician) at one datetime — department and
  location changes already share the same rows, so there is no separate stream to merge.
  Each row opens one segment, keyed by its `encounter_history.id`. Each segment's
  `visit_detail_end_datetime` is the next segment's start —
  `lead(start) over (partition by visit_occurrence_id order by start_datetime, visit_detail_id)`
  — falling back to the encounter `end_datetime` for the final (open) segment. Ordering
  breaks ties on `visit_detail_id` for determinism. `visit_detail_start_date` /
  `visit_detail_end_date` are the date components of the respective datetimes, mirroring
  `clinical__visit_occurrence`. **Zero-length segments are possible:** when two
  `encounter_history` events share a timestamp, a segment's `end` equals its `start`
  (AC-006 permits `>=`), so length-of-stay-by-segment math should expect the occasional
  zero-duration phase rather than assume every segment spans a positive interval.
- **BL-003:** `visit_detail_concept_id` reuses `map__omop_visit_type` on the segment's
  `encounter_type` (same map as `clinical__visit_occurrence` BL-002), applied per segment
  rather than once per encounter — so an ER phase and a subsequent inpatient phase of one
  encounter get 9203 and 9201 respectively, while the parent `VISIT_OCCURRENCE` row
  carries the episode-level 262. An unmapped type yields a NULL concept; the row is kept.
- **BL-004:** `preceding_visit_detail_id` chains segments within an encounter via
  `lag(visit_detail_id)` over the same window, giving OMOP's intra-visit ordering.
- **BL-005:** An encounter with no `encounter_history` rows contributes exactly one
  synthesized segment covering the whole visit, taken from the encounter record itself
  (`encounters.start_datetime`/`end_datetime`, department, location, clinician, type) and
  keyed on `encounters.id`. This guarantees every encounter has at least one
  `VISIT_DETAIL` row. The `encounters.id` key cannot collide with an
  `encounter_history.id` (distinct UUID spaces), preserving AC-002.
- **BL-006:** `care_site_id` is the **ward** — the `location_group` of the segment's
  location, resolved by `left join`ing `locations` on the segment `location_id` and taking
  `location_group_id`. It FKs to `ref__care_site` (ward-type rows). It is NULL when the
  location has no `location_group`, which is common in Tamanu (most `locations` have no
  ward), so the FK test tolerates NULL. This is the finer, physical care site; the
  coarser, always-populated department care site lives on `clinical__visit_occurrence`
  (OMOP allows a coarser care site on the visit and a finer one on the detail).
- **BL-007:** `department_id` (the organizational unit, `encounter_history.department_id`)
  and `location_id` (the room/bed, `encounter_history.location_id`) are carried as
  attributes. `department_id` is the grain used as `care_site` on
  `clinical__visit_occurrence` and FKs to `ref__care_site` (department-type rows).
  `location_id` is finer than the ward care site and is **not** an OMOP `LOCATION` (that
  is geography — `ref__location`); it is carried raw until a care-site-style wrapper for
  Tamanu locations exists.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `visit_detail_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `visit_detail_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-001 | dbt `relationships` |
| AC-004 | Every non-null `care_site_id` (ward) exists in `ref__care_site.care_site_id` | BL-006 | dbt `relationships` |
| AC-005 | Every non-null `visit_detail_concept_id` exists in `map__omop_visit_type.concept_id` | BL-003 | dbt `relationships` |
| AC-006 | When `visit_detail_end_datetime` is non-null, it is `>= visit_detail_start_datetime` | BL-002 | dbt singular test (`data_test__clinical__visit_detail`) |
| AC-007 | Segments of one encounter do not overlap: each ends where the next begins, the last at the encounter end | BL-002, BL-004 | dbt unit test (`test_clinical__visit_detail_segments_do_not_overlap`) |
| AC-008 | Every non-null `department_id` exists in `ref__care_site.care_site_id` | BL-007 | dbt `relationships` |
| AC-009 | Every `person_id` exists in `clinical__person.person_id` | BL-001 | dbt `relationships` |

`test_clinical__visit_detail_synthesized_segment` additionally covers BL-005
(history-less encounter → one whole-visit segment).

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements (only `metric__` / `derived__` get a `metric_definitions.csv` row).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `encounter_history` | `bases/` | Per-segment department, location, type, clinician, datetime (the timeline) |
| `encounters` | `bases/` | Segment/encounter bounds, `person_id`, and the whole-visit fallback (BL-005) |
| `locations` | `bases/` | Room → `location_group` (ward) lookup for `care_site_id` (BL-006) |
| `map__omop_visit_type` | `maps/` | encounter_type → OMOP Visit concept, per segment |
| `clinical__visit_occurrence` | `clinical/` | Parent VISIT_OCCURRENCE; `visit_occurrence_id` FK target (AC-003) |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-009) |
| `ref__care_site` | `ref/` | `care_site_id` (ward) and `department_id` FK target (AC-004, AC-008) |

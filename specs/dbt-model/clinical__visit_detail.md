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
| **Last updated** | 2026-08-11 |

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
department, time-in-ER before admission, location-transfer counts — need the segment grain
that `VISIT_DETAIL` provides.

**Who reads it.** `metric__` length-of-stay and transfer indicators; `dataset__`
admission audit line-lists; any analysis that must attribute time to a specific
department or location within a single encounter.

## Grain

**One row per:** encounter segment (a stable department/location/encounter_type phase).
Parent `visit_occurrence_id` is many-to-one from segments, so `clinical__visit_detail`
fans out relative to `clinical__visit_occurrence` — this is expected and is the whole
point of the model. Segment boundaries come from `encounter_history` change events; an
encounter with no history at all contributes exactly one segment (BL-005). **This "every
encounter has at least one row" guarantee is conditional on `encounter_type` coverage**: a
segment whose `encounter_type` is not yet in `map__omop_visit_type` is excluded by BL-003's
inner join, not kept with a NULL concept — see BL-003 and
`data_test__map__omop_visit_type_coverage` for the safety net.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_detail_id` | uuid | Segment PK — the `encounter_history.id` that opens the segment, or the `encounters.id` for a synthesized whole-visit segment (BL-005). Native UUID (D1) |
| `visit_occurrence_id` | uuid | Parent encounter. FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `person_id` | uuid | Patient (`encounters.patient_id`) |
| `visit_detail_concept_id` | integer | OMOP Visit concept for this segment's `encounter_type`, from `map__omop_visit_type`. Never NULL — an unmapped `encounter_type` excludes the segment entirely rather than yielding a NULL concept (BL-003) |
| `visit_detail_start_date` | date | Date component of `visit_detail_start_datetime` |
| `visit_detail_start_datetime` | timestamp | Segment start (the `encounter_history` event datetime, or the encounter start for a synthesized segment) |
| `visit_detail_end_date` | date | Date component of `visit_detail_end_datetime`. NULL for the final segment of an open encounter |
| `visit_detail_end_datetime` | timestamp | Segment end (next segment's start, or the encounter `end_datetime`; NULL for the final segment of an open encounter) |
| `care_site_id` | uuid | Segment location — the raw `location_id`. FK to `ref__care_site.care_site_id` (location-type rows). NULL only when the segment has no `location_id` recorded (BL-006) |
| `department_id` | uuid | Segment department (`encounter_history.department_id`) — organizational unit, carried as an attribute (BL-007). FK to `ref__care_site.care_site_id` (department-type rows) |
| `provider_id` | uuid | Segment clinician (`encounter_history.clinician_id`) |
| `visit_detail_source_value` | text | Segment `encounter_type`, retained verbatim (D1) |
| `preceding_visit_detail_id` | uuid | The prior segment's `visit_detail_id` in the same encounter; NULL for the first segment |

## Business logic

- **BL-001:** One row per encounter segment, sourced from `{{ ref('encounter_history') }}`
  and `{{ ref('encounters') }}` only (D10) — never `public.*`. Soft-delete and test-patient
  filtering are inherited from the base models; a history row whose encounter is filtered
  out is dropped by the inner join to `encounters`.
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
  carries the episode-level 262. The join to `map__omop_visit_type` is an **inner** join:
  `visit_detail_concept_id` is never NULL, by construction — a segment whose
  `encounter_type` has no row in the map is excluded from the model entirely, not kept
  with a NULL concept. This is a deliberate choice: a NULL concept sitting silently in the
  data was judged worse than a visibly incomplete `VISIT_DETAIL` row set, and the trade-off
  is guarded by AC-011, a singular test on `map__omop_visit_type` itself
  (`data_test__map__omop_visit_type_coverage`) that checks every `encounter_type` in
  `encounters` / `encounter_history` against the map directly — catching a schema-drift gap
  (a new Tamanu `encounter_type` not yet added to the map) at the source, independent of
  which downstream model's join type would otherwise hide or surface it.

  **Consequence for BL-005's guarantee.** "Every encounter has at least one row" (BL-005)
  holds only for encounters whose `encounter_type` — and every `encounter_history` phase's
  `encounter_type` — is covered by `map__omop_visit_type`. An encounter that trips AC-011
  loses whichever segment(s) carry the unmapped type from this model's output until the map
  is updated; it is not a per-row NULL, it is a missing row. AC-012
  (`data_test__clinical__visit_detail`) directly checks the guarantee itself — that every
  `encounters.id` still has at least one row here — independent of AC-011's root-cause
  signal. `clinical__visit_occurrence` makes the identical trade-off on the same mapping
  (its own BL-002, also an inner join, with the matching completeness check as its AC-011) —
  an unmapped `encounter_type` is a missing row on both models for the same encounter, not
  a NULL concept surviving on either.
- **BL-004:** `preceding_visit_detail_id` chains segments within an encounter via
  `lag(visit_detail_id)` over the same window, giving OMOP's intra-visit ordering.
- **BL-005:** An encounter with no `encounter_history` rows contributes exactly one
  synthesized segment covering the whole visit, taken from the encounter record itself
  (`encounters.start_datetime`/`end_datetime`, department, location, clinician, type) and
  keyed on `encounters.id`. This guarantees every encounter has at least one
  `VISIT_DETAIL` row, **provided its `encounter_type` is covered by `map__omop_visit_type`**
  (BL-003's inner join is the exception to this guarantee). The `encounters.id` key cannot
  collide with an `encounter_history.id` (distinct UUID spaces), preserving AC-002.
- **BL-006:** `care_site_id` is the segment's raw `location_id` — no join to `bases/locations`
  is made or needed; the value is carried straight through from `encounter_history` /
  `encounters`. It FKs to `ref__care_site` (location-type rows). It is NULL only when the
  segment has no `location_id` at all (possible only for the synthesized whole-visit
  segment, BL-005, since `encounter_history.location_id` is `not_null` but
  `encounters.location_id` is not).

  **No soft-delete validation.** A `location_id` pointing at a since-soft-deleted location
  is *not* NULLed out here — it passes through as-is. `ref__care_site`'s location-type rows
  are sourced from `bases/locations`, which excludes soft-deleted locations, so such a row
  would not resolve there; AC-004's `relationships` test would flag it. This is an accepted,
  low-stakes gap: `data_tests: +severity: warn` project-wide means that test warns rather
  than fails the build, and validating against a live `locations` join was judged not worth
  the added dependency for a case the test already surfaces. Facility is not surfaced at
  this layer at all; a `ds__` dataset that needs it joins `bases/locations` itself (see
  `ds__emergency_visit` BL-003 for the pattern).
- **BL-007:** `department_id` (the organizational unit, `encounter_history.department_id`)
  is carried as an attribute. It FKs to `ref__care_site` (department-type rows).

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `visit_detail_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `visit_detail_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-001 | dbt `relationships` |
| AC-004 | Every non-null `care_site_id` (location) exists in `ref__care_site.care_site_id` | BL-006 | dbt `relationships` |
| AC-005 | Every non-null `visit_detail_concept_id` exists in `map__omop_visit_type.concept_id` | BL-003 | dbt `relationships` |
| AC-006 | When `visit_detail_end_datetime` is non-null, it is `>= visit_detail_start_datetime` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-007 | Segments of one encounter do not overlap: each ends where the next begins, the last at the encounter end | BL-002, BL-004 | dbt unit test (`test_clinical__visit_detail_segments_do_not_overlap`) |
| AC-008 | Every non-null `department_id` exists in `ref__care_site.care_site_id` | BL-007 | dbt `relationships` |
| AC-009 | Every `person_id` exists in `clinical__person.person_id` | BL-001 | dbt `relationships` |
| AC-010 | Every non-null `provider_id` exists in `ref__provider.provider_id` | BL-007 | dbt `relationships` |
| AC-011 | Every `encounter_type` value in `encounters` / `encounter_history` exists in `map__omop_visit_type.local_code` (flags schema drift before it silently excludes a segment here) | BL-003 | singular test (`data_test__map__omop_visit_type_coverage`) |
| AC-012 | Every `encounters.id` has at least one corresponding row here (the direct completeness check for BL-003's inner join) | BL-003, BL-005 | singular test (`data_test__clinical__visit_detail`) |

`test_clinical__visit_detail_synthesized_segment` additionally covers BL-005
(history-less encounter → one whole-visit segment).

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements (only `metric__` / `derived__` get a `metric_definitions.csv` row).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `encounter_history` | `bases/` | Per-segment department, location, type, clinician, datetime (the timeline); `location_id` used directly as `care_site_id` (BL-006) |
| `encounters` | `bases/` | Segment/encounter bounds, `person_id`, and the whole-visit fallback (BL-005) |
| `map__omop_visit_type` | `maps/` | encounter_type → OMOP Visit concept, per segment (inner join; coverage guarded by AC-011) |
| `clinical__visit_occurrence` | `clinical/` | Parent VISIT_OCCURRENCE; `visit_occurrence_id` FK target (AC-003) |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-009) |
| `ref__care_site` | `ref/` | `care_site_id` (location) and `department_id` FK target (AC-004, AC-008) |
| `ref__provider` | `ref/` | `provider_id` FK target (AC-010) |

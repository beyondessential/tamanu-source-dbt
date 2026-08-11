# dbt Model Spec: `clinical__visit_occurrence` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__visit_occurrence` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-28 |
| **Last updated** | 2026-08-11 |

The OMOP-lite `VISIT_OCCURRENCE` domain — the canonical encounter surface every
`clinical__`, `derived__`, `metric__`, and `dataset__` model joins to for visit
context. Second model of the canonical clinical layer; the event hub of the
OMOP foreign-key graph (`visit_occurrence_id` is carried by condition, procedure,
measurement, and observation event tables). See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per encounter, in OMOP `VISIT_OCCURRENCE`
shape: native UUID primary key, standardised visit-type concept ID alongside the
Tamanu encounter-type source value, visit start/end datetimes, attending provider
reference, and the encounter's location as its care-site reference.

**Clinical context.** Tamanu records all patient–facility interactions as
`encounters`, typed by `encounter_type` (admission, clinic, emergency, etc.). OMOP
analytics expect a single canonical `VISIT_OCCURRENCE` row per encounter keyed by
`visit_occurrence_id`. This model is that contract.

**Who reads it.** Every downstream canonical model that needs a visit anchor:
`clinical__condition_occurrence` and future event tables (via `visit_occurrence_id`),
`clinical__visit_detail` (the intra-visit phase breakdown, keyed by `visit_occurrence_id`),
`derived__cohort_*` (visit counts, admission windows), `metric__` calculations
(admission rates, length-of-stay distributions), and `dataset__` encounter summaries.

## Grain

**One row per:** encounter, **provided its `encounter_type` is covered by
`map__omop_visit_type`** (BL-002's inner join is the exception to this — an encounter whose
`encounter_type` has no row there is excluded entirely, not kept with a NULL concept; see
BL-002 and `data_test__map__omop_visit_type_coverage`).

Source `encounters` (via `bases/`) already filters soft-deleted encounters and the
test patient. No fan-out risk: `encounters.id` is the PK of the source table.
All joins in this model are many-to-one (encounter → map row), so grain is preserved.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_occurrence_id` | uuid | `encounters.id`. Native UUID PK — no remap to OMOP integer IDs (D1) |
| `person_id` | uuid | `encounters.patient_id`. FK to `clinical__person.person_id` |
| `visit_concept_id` | integer | OMOP Visit concept from `map__omop_visit_type` (9201 Inpatient, 9202 Outpatient, 9203 ER, 0 no-match, or 262 for ER→admission). Never NULL — an unmapped `encounter_type` excludes the encounter entirely rather than yielding a NULL concept (BL-002) |
| `visit_start_date` | date | Date component of `start_datetime` |
| `visit_start_datetime` | timestamp | `encounters.start_datetime`. Always non-null |
| `visit_end_date` | date | Date component of `end_datetime`. NULL for open encounters |
| `visit_end_datetime` | timestamp | `encounters.end_datetime`. NULL for open encounters |
| `visit_type_concept_id` | integer | Constant 32817 (EHR administration record) — all encounters originate from the Tamanu EHR |
| `provider_id` | uuid | `encounters.clinician_id`. The attending clinician at encounter creation. NULL when no clinician recorded |
| `care_site_id` | uuid | `encounters.location_id` — the encounter's own location. FK to `ref__care_site.care_site_id` (location-type rows) |
| `visit_source_value` | text | `encounters.encounter_type`. Tamanu local code, retained alongside the concept ID (D1) |

## Business logic

- **BL-001:** One row per encounter, sourced from `{{ ref('encounters') }}` only — never
  `public.*` (D10). Deleted / test-patient filtering is inherited from the base model.
- **BL-002:** `visit_concept_id` is the OMOP standard Visit concept for the encounter
  type. For all types except `admission` it is looked up from `map__omop_visit_type`
  on `encounter_type = local_code`. The join is an **inner** join: `visit_concept_id` is
  never NULL, by construction — an encounter whose `encounter_type` has no row in the map
  is excluded from the model entirely, not kept with a NULL concept. This is a deliberate
  choice, matching `clinical__visit_detail`'s identical trade-off on the same mapping (its
  own BL-003): a NULL concept sitting silently in the data was judged worse than a visibly
  incomplete `VISIT_OCCURRENCE` row set, and the trade-off is guarded by AC-010, a singular
  test on `map__omop_visit_type` itself (`data_test__map__omop_visit_type_coverage`) that
  checks every `encounter_type` in `encounters` / `encounter_history` against the map
  directly — catching a schema-drift gap (a new Tamanu `encounter_type` not yet added to the
  map) at the source, independent of which downstream model reads it. The local value is
  preserved verbatim as `visit_source_value`. `observation` maps to 9203 (Emergency Room
  Visit) because it is part of the Tamanu emergency workflow, not a standalone outpatient
  encounter. For `admission` encounters, the concept depends on encounter history: if
  `encounter_history` contains a prior `emergency`, `triage`, or `observation`
  phase for the same encounter, `visit_concept_id` is 262 (Emergency Room and
  Inpatient Visit); otherwise it is 9201 (Inpatient Visit). This reflects the OMOP
  CDM convention that a single ER-to-inpatient episode is one visit with concept 262,
  not two separate visit occurrences. The 262 concept is registered in
  `map__omop_visit_type` under `local_code = 'admission_from_emergency'` — a synthetic code
  no real `encounter_type` ever equals, so it is never reached by the inner join above; it
  exists purely so the CASE's literal `262` has a registered concept for the
  referential-integrity test on `visit_concept_id` (AC-004) to validate against.

  **Same trade-off as `clinical__visit_detail`, both ways now.** Both `clinical__` models
  make the identical choice on this mapping: exclude the row rather than emit a NULL
  concept. An unmapped `encounter_type` is therefore a *missing* row on both models for the
  same encounter — there is no longer a model where it survives as a visible, NULL-concept
  row. Two tests guard this, at different points: `data_test__map__omop_visit_type_coverage`
  flags the root cause (the unmapped `encounter_type` value) at the source; AC-011
  (`data_test__clinical__visit_occurrence`) directly checks that every `encounters.id` still
  has a row here, independent of the coverage test — the completeness check itself, not an
  inference from it.
- **BL-003:** `visit_type_concept_id` is the constant 32817 ("EHR administration
  record") for every row. All Tamanu encounters originate from EHR entry; no
  deployment-specific override is needed (unlike ethnicity or billing mappings).
- **BL-004:** `visit_start_date` and `visit_start_datetime` are always non-null
  (inherited from `bases/encounters`, which sources from a `not_null`-tested source
  column). `visit_end_date` and `visit_end_datetime` are NULL for open / in-progress
  encounters — no sentinel value is substituted, so a NULL end date means "not yet
  discharged" unambiguously.
- **BL-005:** `provider_id` is `clinician_id` from `bases/encounters` (the Tamanu
  `examiner_id`, renamed at base layer). This is the clinician recorded at encounter
  creation; mid-encounter clinician changes tracked in `encounter_history` are not
  reflected here (they belong to a future `clinical__provider_visit` event if needed).
- **BL-006:** `care_site_id` is the encounter's own location (`encounters.location_id`),
  effectively always populated since every encounter has a location. It is an FK to
  `ref__care_site.care_site_id` (the
  location-type rows of the OMOP `CARE_SITE` wrapper). The referential-integrity test on
  the column is AC-008. A location's grouping (`location_group`, the physical
  "clinic"/"ward") is a separate, coarser concept: consumers that need it (e.g.
  `ds__outpatient_visit`) join `bases/locations` directly. Department remains available
  at the segment grain on `clinical__visit_detail`.
- **BL-007:** `visit_source_value` carries the raw Tamanu `encounter_type` value
  alongside the OMOP concept. It is not a direct identifier and is not withheld on
  analytics targets.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `visit_occurrence_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `visit_occurrence_id` is `unique` | grain | dbt `unique` |
| AC-003 | `person_id` is `not_null` and every value exists in `clinical__person.person_id` | BL-001 | dbt `not_null` + `relationships` |
| AC-004 | Every non-null `visit_concept_id` exists in `map__omop_visit_type.concept_id` | BL-002 | dbt `relationships` |
| AC-005 | `visit_type_concept_id` is `not_null` and always 32817 | BL-003 | dbt `not_null` + `accepted_values` |
| AC-006 | `visit_start_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-007 | When `visit_end_datetime` is non-null, `visit_end_datetime >= visit_start_datetime` | BL-004 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-008 | Every non-null `care_site_id` exists in `ref__care_site.care_site_id` | BL-006 | dbt `relationships` |
| AC-009 | Every non-null `provider_id` exists in `ref__provider.provider_id` | BL-005 | dbt `relationships` |
| AC-010 | Every `encounter_type` value in `encounters` / `encounter_history` exists in `map__omop_visit_type.local_code` (flags schema drift before it silently excludes an encounter here) | BL-002 | singular test (`data_test__map__omop_visit_type_coverage`) |
| AC-011 | Every `encounters.id` has a corresponding `visit_occurrence_id` here (the direct completeness check for BL-002's inner join) | BL-002 | singular test (`data_test__clinical__visit_occurrence`) |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` and `derived__` artefacts get a `metric_definitions.csv`
row (D5, dbt-conventions § Documentation).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `encounters` | `bases/` | Encounter identity, type, datetimes, clinician, location, used directly as `care_site_id` (BL-006) |
| `encounter_history` | `bases/` | Prior encounter types per encounter; used to detect ER→admission transitions (BL-002) |
| `map__omop_visit_type` | `maps/` | Tamanu encounter_type → OMOP Visit concept (inner join; coverage guarded by AC-010) |
| `clinical__person` | `clinical/` | Parent PERSON domain; `person_id` FK target |
| `ref__care_site` | `ref/` | OMOP CARE_SITE wrapper; `care_site_id` FK → its location-type rows (AC-008), same grain as `clinical__visit_detail` |
| `ref__provider` | `ref/` | OMOP PROVIDER wrapper over users; `provider_id` FK target (AC-009) |

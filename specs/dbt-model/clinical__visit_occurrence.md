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
| **Last updated** | 2026-06-28 |

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
reference, and department care-site reference.

**Clinical context.** Tamanu records all patient–facility interactions as
`encounters`, typed by `encounter_type` (admission, clinic, emergency, etc.). OMOP
analytics expect a single canonical `VISIT_OCCURRENCE` row per encounter keyed by
`visit_occurrence_id`. This model is that contract.

**Who reads it.** Every downstream canonical model that needs a visit anchor:
`clinical__condition_occurrence` and future event tables (via `visit_occurrence_id`),
`derived__cohort_*` (visit counts, admission windows), `metric__` calculations
(admission rates, length-of-stay distributions), and `dataset__` encounter summaries.

## Grain

**One row per:** encounter.

Source `encounters` (via `bases/`) already filters soft-deleted encounters and the
test patient. No fan-out risk: `encounters.id` is the PK of the source table.
All joins in this model are many-to-one (encounter → map row), so grain is preserved.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `visit_occurrence_id` | uuid | `encounters.id`. Native UUID PK — no remap to OMOP integer IDs (D1) |
| `person_id` | uuid | `encounters.patient_id`. FK to `clinical__person.person_id` |
| `visit_concept_id` | integer | OMOP Visit concept from `map__omop_visit_type` (9201 Inpatient, 9202 Outpatient, 9203 ER, 0 no-match). NULL if unmapped |
| `visit_start_date` | date | Date component of `start_datetime` |
| `visit_start_datetime` | timestamp | `encounters.start_datetime`. Always non-null |
| `visit_end_date` | date | Date component of `end_datetime`. NULL for open encounters |
| `visit_end_datetime` | timestamp | `encounters.end_datetime`. NULL for open encounters |
| `visit_type_concept_id` | integer | Constant 32817 (EHR administration record) — all encounters originate from the Tamanu EHR |
| `provider_id` | uuid | `encounters.clinician_id`. The attending clinician at encounter creation. NULL when no clinician recorded |
| `care_site_id` | uuid | `encounters.department_id`. The department the encounter is assigned to. NULL when no department recorded |
| `visit_source_value` | text | `encounters.encounter_type`. Tamanu local code, retained alongside the concept ID (D1) |

## Business logic

- **BL-001:** One row per encounter, sourced from `{{ ref('encounters') }}` only — never
  `public.*` (D10). Deleted / test-patient filtering is inherited from the base model.
- **BL-002:** `visit_concept_id` is the OMOP standard Visit concept for the encounter
  type. For all types except `admission` it is looked up from `map__omop_visit_type`
  on `encounter_type = local_code`. The local value is preserved verbatim as
  `visit_source_value`. An unmapped type yields a NULL concept — the row is kept,
  never dropped. `observation` maps to 9203 (Emergency Room Visit) because it is
  part of the Tamanu emergency workflow, not a standalone outpatient encounter.
  For `admission` encounters, the concept depends on encounter history: if
  `encounter_history` contains a prior `emergency`, `triage`, or `observation`
  phase for the same encounter, `visit_concept_id` is 262 (Emergency Room and
  Inpatient Visit); otherwise it is 9201 (Inpatient Visit). This reflects the OMOP
  CDM convention that a single ER-to-inpatient episode is one visit with concept 262,
  not two separate visit occurrences. The 262 concept is registered in
  `map__omop_visit_type` under `local_code = 'admission_from_emergency'` so the
  referential-integrity test on `visit_concept_id` (AC-004) covers it.
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
- **BL-006:** `care_site_id` is `department_id` from `bases/encounters`. It represents
  the department the encounter is assigned to at creation. No `ref__care_site` model
  exists yet; `care_site_id` is carried as a raw UUID FK so future joins are
  forward-compatible when `ref__care_site` is built.
- **BL-007:** `visit_source_value` carries the raw Tamanu `encounter_type` value
  alongside the OMOP concept. It is not a direct identifier and is not withheld on
  analytics targets.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `visit_occurrence_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `visit_occurrence_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `person_id` exists in `clinical__person.person_id` | BL-001 | dbt `relationships` |
| AC-004 | Every non-null `visit_concept_id` exists in `map__omop_visit_type.concept_id` | BL-002 | dbt `relationships` |
| AC-005 | `visit_type_concept_id` is `not_null` and always 32817 | BL-003 | dbt `not_null` |
| AC-006 | `visit_start_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-007 | When `visit_end_datetime` is non-null, `visit_end_datetime >= visit_start_datetime` | BL-004 | dbt singular test |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` and `derived__` artefacts get a `metric_definitions.csv`
row (D5, dbt-conventions § Documentation).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `encounters` | `bases/` | Encounter identity, type, datetimes, clinician, department |
| `encounter_history` | `bases/` | Prior encounter types per encounter; used to detect ER→admission transitions (BL-002) |
| `map__omop_visit_type` | `maps/` | Tamanu encounter_type → OMOP Visit concept (universal) |
| `clinical__person` | `clinical/` | Parent PERSON domain; `person_id` FK target |

## Open questions

- **OQ-1:** `care_site_id` references `department_id` without a corresponding
  `ref__care_site` canonical lookup. A future `ref__care_site` model (wrapping
  `bases/departments` and `bases/facilities`) should be added so the FK can be
  validated. Until then, AC on this column is deferred.
- **OQ-2:** Mid-encounter transitions — department/location transfers *and*
  encounter-type changes (e.g. `triage` → `emergency` → `admission`) — are
  tracked in `encounter_history` but not surfaced here. In Tamanu, an ER-to-
  admission flow is a **single encounter** whose type changes over time; there
  is no second encounter record, so `preceding_visit_occurrence_id` does not
  apply. `VISIT_OCCURRENCE` correctly reflects the final/current type. OMOP
  handles the intra-visit phases via `VISIT_DETAIL` rows — a future
  `clinical__visit_detail` model should expose one row per `encounter_history`
  segment (carrying `encounter_type`, department, location, and datetime range
  per segment) built from `int__admission_history_*` and the `encounter_type`
  column in `bases/encounter_history`.
- **OQ-3:** `surveyResponse` encounters are included with `visit_concept_id = NULL`
  (no OMOP equivalent). If downstream models should exclude survey encounters,
  they can filter on `visit_source_value != 'surveyResponse'` or on non-null
  `visit_concept_id`.

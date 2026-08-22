# dbt Model Spec: `clinical__condition_occurrence` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__condition_occurrence` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-03 |
| **Last updated** | 2026-08-22 |

The OMOP-lite `CONDITION_OCCURRENCE` domain — one row per recorded diagnosis, from two
sources: encounter diagnoses and program-registry conditions. The encounter branch hangs off
the `visit_occurrence_id` hub; the registry branch has no encounter and anchors on the
enrolment instead. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping, `vocab__` future),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per encounter diagnosis, in OMOP
`CONDITION_OCCURRENCE` shape: native UUID PK, the Tamanu diagnosis (ICD-10) retained as the
source value, diagnosis datetime, certainty as the condition status, and the person /
visit / provider foreign keys that anchor it in the OMOP graph.

**Clinical context.** Tamanu records diagnoses as `encounter_diagnoses` rows against an
encounter, each pointing at a `reference_data` diagnosis (ICD-10 code), with a `certainty`
and an `is_primary` flag. OMOP analytics expect these as `CONDITION_OCCURRENCE` rows keyed
by `condition_occurrence_id` and joined to `VISIT_OCCURRENCE`/`PERSON`.

**Who reads it.** `derived__cohort_*` (disease cohorts — e.g. NCD patients identified by
diagnosis), `metric__` NCD indicators (prevalence, controlled-rate denominators keyed on a
diagnosis), and `dataset__` diagnosis line-lists.

## Grain

**One row per:** encounter diagnosis. `bases/encounter_diagnoses` already filters
soft-deleted rows, the test patient, and `disproven`/`error` certainties, and its
`encounter_diagnoses.id` is the PK of the source table. All joins here (→ `encounters` for
person/visit, → `reference_data` for the diagnosis code) are many-to-one, so grain is
preserved.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `condition_occurrence_id` | uuid | `encounter_diagnoses.id`. Native UUID PK — no remap to OMOP integer IDs (D1) |
| `person_id` | uuid | `encounters.patient_id` (via `encounter_id`). FK to `clinical__person.person_id` |
| `condition_start_date` | date | Date component of the diagnosis datetime |
| `condition_start_datetime` | timestamp | `encounter_diagnoses.date`. Always non-null |
| `condition_end_date` | date | NULL — encounter diagnoses are point-in-time (no resolution date recorded) |
| `condition_end_datetime` | timestamp | NULL — as above |
| `condition_type_source_value` | text | `'encounter diagnosis'` or `'program registry condition'` — provenance, and the branch discriminator |
| `condition_status_source_value` | text | `encounter_diagnoses.certainty` (e.g. confirmed, suspected). Retained verbatim |
| `is_primary` | boolean | `encounter_diagnoses.is_primary` — primary vs secondary diagnosis on the encounter |
| `provider_id` | uuid | `encounter_diagnoses.diagnosed_by_id`. FK to `ref__provider.provider_id`. NULL when no clinician recorded |
| `visit_occurrence_id` | uuid | `encounter_diagnoses.encounter_id`. FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `condition_source_value` | text | The diagnosis `reference_data.code` (ICD-10), via `diagnosis_id`. The Tamanu local code (D1) |
| `condition_source_name` | text | The diagnosis `reference_data.name`, denormalised for readability |

`condition_concept_id` / `condition_source_concept_id` (OMOP standard SNOMED) are **not**
emitted — see BL-003. `condition_status_concept_id` and `condition_type_concept_id` are
likewise deferred (BL-005, BL-006): only the source values are populated for now.

## Business logic

- **BL-001:** One row per encounter diagnosis, sourced from `{{ ref('encounter_diagnoses') }}`,
  `{{ ref('encounters') }}` (person + visit anchor), and `{{ ref('reference_data') }}` (the
  diagnosis code/name) only (D10) — never `public.*`. Soft-delete, test-patient, and
  `disproven`/`error`-certainty filtering are inherited from `bases/encounter_diagnoses`.
  `encounter_diagnoses.id` is the PK; the joins are many-to-one, so grain is preserved.
- **BL-002:** OMOP foreign keys are wired from the encounter: `person_id` is the encounter's
  `patient_id`, `visit_occurrence_id` is the `encounter_id`, and `provider_id` is
  `diagnosed_by_id`. All are native UUIDs (D1) and resolve to `clinical__person`,
  `clinical__visit_occurrence`, and `ref__provider` respectively.
- **BL-003:** `condition_source_value` is the diagnosis's `reference_data.code` (ICD-10) and
  `condition_source_name` its `reference_data.name`. `condition_concept_id` (OMOP standard
  SNOMED) is **not** emitted: ICD-10 → SNOMED mapping requires the OMOP vocabulary tables
  (the future `vocab__` layer, D2), not a small `map__omop_*` seed. The source code is
  retained so the standard concept can be layered on when `vocab__` exists (OQ-2), never
  replacing the local value (D1).
- **BL-004:** `condition_start_date` / `condition_start_datetime` come from the diagnosis
  `date` (always present). `condition_end_date` / `condition_end_datetime` are NULL —
  Tamanu encounter diagnoses are point-in-time and carry no resolution date; no sentinel is
  substituted.
- **BL-005:** `condition_status_source_value` is the raw `certainty`; `is_primary` is
  carried as the primary/secondary flag. `condition_status_concept_id` is deferred (no
  status vocabulary in use). The base model already drops `disproven` and `error`
  certainties, so only clinically-asserted diagnoses appear.
- **BL-006:** `condition_type_source_value` is `'encounter diagnosis'` on this branch,
  recording provenance and discriminating it from the registry branch (BL-007).
  `condition_type_concept_id` is deferred pending a verified condition-type concept.

### Program-registry conditions

- **BL-007:** Registry conditions form a second branch, unioned to the encounter branch, one
  row per `patient_program_registration_conditions` record.
- **BL-008:** `visit_occurrence_id` is NULL on the registry branch — the condition is recorded
  against the enrolment, not an encounter.
- **BL-009:** `person_id` comes from `patient_program_registrations.patient_id`, reached through
  `patient_program_registration_conditions.patient_program_registration_id`.
- **BL-010:** `condition_status_source_value` is the condition category code (`confirmed`,
  `suspected`, `resolved`, …), the registry's equivalent of encounter-diagnosis certainty.
  `is_primary` is NULL: a registry condition is not ranked against the others on the enrolment.
- **BL-011:** A condition with a deletion datetime is excluded.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `condition_occurrence_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `condition_occurrence_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `person_id` exists in `clinical__person.person_id` | BL-002 | dbt `relationships` |
| AC-004 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-002 | dbt `relationships` |
| AC-005 | Every non-null `provider_id` exists in `ref__provider.provider_id` | BL-002 | dbt `relationships` |
| AC-006 | `condition_start_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-007 | When `condition_end_datetime` is non-null, `condition_end_datetime >= condition_start_datetime` | BL-004 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-008 | `condition_type_source_value` is `encounter diagnosis` or `program registry condition` | BL-006, BL-007 | dbt `accepted_values` |
| AC-009 | Registry-branch rows have a null `visit_occurrence_id`; encounter-branch rows do not | BL-008 | dbt singular test |
| AC-010 | Every registry-branch `person_id` exists in `clinical__person.person_id` | BL-009 | covered by AC-003 |
| AC-011 | Every non-null registry-branch `condition_status_source_value` exists in `program_registry_condition_categories.code` | BL-010 | dbt singular test |
| AC-012 | No registry-branch row corresponds to a source condition with a deletion datetime | BL-011 | dbt singular test |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` / `derived__` artefacts get a `metric_definitions.csv` row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `encounter_diagnoses` | `bases/` | Diagnosis identity, date, certainty, is_primary, diagnosis code FK, clinician |
| `encounters` | `bases/` | Person (`patient_id`) and visit (`encounter_id`) anchor |
| `reference_data` | `bases/` | Diagnosis ICD-10 code and name (via `diagnosis_id`) |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-003) |
| `clinical__visit_occurrence` | `clinical/` | `visit_occurrence_id` FK target (AC-004) |
| `ref__provider` | `ref/` | `provider_id` FK target (AC-005) |

## Open questions

- **OQ-2:** `condition_concept_id` (standard SNOMED) awaits the `vocab__` layer (D2) to map
  the retained ICD-10 `condition_source_value`. Until then only the source code/name are
  emitted.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-22 | Maui team | Program-registry conditions added as a second branch (BL-007..BL-011), resolving OQ-1. |

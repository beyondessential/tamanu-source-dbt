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
| **Last updated** | 2026-08-24 |

The OMOP-lite `CONDITION_OCCURRENCE` domain — one row per recorded diagnosis, from two
sources: encounter diagnoses and program-registry conditions. The encounter branch hangs off
the `visit_occurrence_id` hub; the registry branch has no encounter and anchors on the
enrolment instead. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping, `vocab__` future),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per recorded diagnosis, in OMOP
`CONDITION_OCCURRENCE` shape: native UUID PK, the Tamanu diagnosis code retained as the
source value, diagnosis datetime, the recorded certainty or category as the condition status,
and the person / visit / provider foreign keys that anchor it in the OMOP graph.

**Clinical context.** Tamanu records diagnoses two ways. `encounter_diagnoses` rows sit
against an encounter, each pointing at a `reference_data` diagnosis (ICD-10 code), with a
`certainty` and an `is_primary` flag. `patient_program_registration_conditions` rows sit
against a program-registry enrolment instead — the conditions a long-running programme tracks
for a patient — each pointing at a `program_registry_conditions` entry with a category rather
than a certainty, and no encounter behind it. OMOP analytics expect both as
`CONDITION_OCCURRENCE` rows keyed by `condition_occurrence_id` and joined to
`VISIT_OCCURRENCE`/`PERSON`.

**Who reads it.** `derived__cohort_*` (disease cohorts — e.g. NCD patients identified by
diagnosis), `metric__` NCD indicators (prevalence, controlled-rate denominators keyed on a
diagnosis), and `dataset__` diagnosis line-lists.

## Grain

**One row per:** encounter diagnosis, plus one row per program-registry condition (BL-007).
`bases/encounter_diagnoses` already filters soft-deleted rows, the test patient, and
`disproven`/`error` certainties, and `bases/patient_program_registration_conditions` filters
soft-deleted rows and the test patient; each branch's source PK (`encounter_diagnoses.id`,
`patient_program_registration_conditions.id`) is the PK of its own table, and the two occupy
disjoint UUID spaces so `condition_occurrence_id` stays unique across the union. All joins on
both branches (→ `encounters` for person/visit, → `reference_data` for the diagnosis code, →
`int__program_enrolments` for the person, → `program_registry_conditions` and
`program_registry_condition_categories` for the code and status) are many-to-one, so grain is
preserved.

## Output schema

Column sources are given per branch, encounter diagnosis first, program-registry condition
second (BL-007).

| Column | Type | Notes |
|---|---|---|
| `condition_occurrence_id` | uuid | `encounter_diagnoses.id` / `patient_program_registration_conditions.id`. Native UUID PK — no remap to OMOP integer IDs (D1) |
| `person_id` | uuid | `encounters.patient_id` (via `encounter_id`) / the enrolment's `person_id` from `int__program_enrolments` (BL-009). FK to `clinical__person.person_id` |
| `condition_start_date` | date | Date component of the diagnosis datetime |
| `condition_start_datetime` | timestamp | `encounter_diagnoses.date` / `patient_program_registration_conditions.date`. Always non-null |
| `condition_end_date` | date | NULL on both branches — neither source records a resolution date (BL-004) |
| `condition_end_datetime` | timestamp | NULL — as above |
| `condition_type_source_value` | text | `'encounter diagnosis'` or `'program registry condition'` — provenance, and the branch discriminator |
| `condition_status_source_value` | text | `encounter_diagnoses.certainty` (e.g. confirmed, suspected) / the condition category code (BL-010). Retained verbatim |
| `is_primary` | boolean | `encounter_diagnoses.is_primary` — primary vs secondary diagnosis on the encounter. NULL on the registry branch, which does not rank its conditions (BL-010) |
| `provider_id` | uuid | `encounter_diagnoses.diagnosed_by_id` / `patient_program_registration_conditions.recorded_by_id`. FK to `ref__provider.provider_id`. NULL when no clinician recorded |
| `visit_occurrence_id` | uuid | `encounter_diagnoses.encounter_id`. FK to `clinical__visit_occurrence.visit_occurrence_id`. NULL on the registry branch, which has no encounter (BL-008) |
| `condition_source_value` | text | The diagnosis `reference_data.code` (ICD-10), via `diagnosis_id` / `program_registry_conditions.code`. The Tamanu local code (D1) |
| `condition_source_name` | text | The diagnosis `reference_data.name` / `program_registry_conditions.name`, denormalised for readability |

`condition_concept_id` / `condition_source_concept_id` (OMOP standard SNOMED) are **not**
emitted — see BL-003. `condition_status_concept_id` and `condition_type_concept_id` are
likewise deferred (BL-005, BL-006): only the source values are populated for now.

## Business logic

- **BL-001:** One row per encounter diagnosis on this branch, sourced from `{{ ref('encounter_diagnoses') }}`,
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
  substituted. Registry conditions carry no resolution date either, so the end columns are NULL
  on both branches and AC-007 asserts that directly.
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
- **BL-009:** `person_id` comes from the enrolment reached through
  `patient_program_registration_conditions.patient_program_registration_id`, read through
  `int__program_enrolments` (`clinical__episode`'s BL-026) rather than the base registration
  table. The branch is scoped to the enrolments `clinical__episode` models, so conditions on
  enrolments recorded in error and on patients merged away are excluded — a condition tracked
  alongside an enrolment is only a diagnosis if the enrolment is one.
- **BL-010:** `condition_status_source_value` is the condition category code (`confirmed`,
  `suspected`, `resolved`, …), the registry's equivalent of encounter-diagnosis certainty.
  `is_primary` is NULL: a registry condition is not ranked against the others on the enrolment.
- **BL-011:** A condition with a deletion datetime is excluded (the source `deletion_date`,
  which `bases/patient_program_registration_conditions` exposes as `deleted_datetime`).

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `condition_occurrence_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `condition_occurrence_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `person_id` exists in `clinical__person.person_id` | BL-002 | dbt `relationships` |
| AC-004 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-002 | dbt `relationships` |
| AC-005 | Every non-null `provider_id` exists in `ref__provider.provider_id` | BL-002 | dbt `relationships` |
| AC-006 | `condition_start_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-007 | `condition_end_datetime` and `condition_end_date` are always null | BL-004 | `dbt_expectations.expect_column_values_to_be_null` |
| AC-008 | `condition_type_source_value` is `encounter diagnosis` or `program registry condition` | BL-006, BL-007 | dbt `accepted_values` |
| AC-009 | Registry-branch rows have a null `visit_occurrence_id`; encounter-branch rows do not | BL-008 | dbt singular test |
| AC-010 | Every registry-branch `person_id` exists in `clinical__person.person_id` | BL-009 | covered by AC-003 |
| AC-011 | Every non-null registry-branch `condition_status_source_value` exists in `program_registry_condition_categories.code` | BL-010 | dbt singular test |
| AC-012 | No registry-branch row corresponds to a source condition with a deletion datetime | BL-011 | dbt singular test |
| AC-013 | Every registry-branch row's enrolment appears in `clinical__episode` | BL-009 | dbt singular test |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` / `derived__` artefacts get a `metric_definitions.csv` row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `encounter_diagnoses` | `bases/` | Diagnosis identity, date, certainty, is_primary, diagnosis code FK, clinician |
| `encounters` | `bases/` | Person (`patient_id`) and visit (`encounter_id`) anchor |
| `reference_data` | `bases/` | Diagnosis ICD-10 code and name (via `diagnosis_id`) |
| `patient_program_registration_conditions` | `bases/` | Registry condition identity, date, condition and category FKs, recording clinician, deletion datetime (BL-007, BL-011) |
| `program_registry_conditions` | `bases/` | Registry condition code and name (BL-007) |
| `program_registry_condition_categories` | `bases/` | Condition category code, the registry branch's condition status (BL-010) |
| `int__program_enrolments` | `intermediate/` | The enrolment behind a registry condition, and the population that scopes the branch (BL-009) |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-003) |
| `clinical__episode` | `clinical/` | The episode every registry-branch row hangs off (AC-013) |
| `clinical__visit_occurrence` | `clinical/` | `visit_occurrence_id` FK target (AC-004) |
| `ref__provider` | `ref/` | `provider_id` FK target (AC-005) |

## Open questions

- **OQ-2:** `condition_concept_id` (standard SNOMED) awaits the `vocab__` layer (D2) to map
  the retained ICD-10 `condition_source_value`. Until then only the source code/name are
  emitted.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-23 | Maui team | Program-registry conditions added as a second branch (BL-007..BL-011, AC-008..AC-013), resolving OQ-1. The branch is scoped through `int__program_enrolments` to the enrolments `clinical__episode` models, so a condition on an enrolment recorded in error or on a merged-away patient cannot become an orphan diagnosis. AC-007 is now the null assertion both branches actually carry, replacing an end-after-start pair test that matched no rows. |

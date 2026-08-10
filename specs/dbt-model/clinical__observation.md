# dbt Model Spec: `clinical__observation` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__observation` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-12 |
| **Last updated** | 2026-07-12 |

The OMOP-lite `OBSERVATION` domain — one row per clinical fact that is neither a measurement
nor a drug exposure, unioning three standard sources: **program/referral-survey answers**
(qualitative form responses), **vaccinations not given** (`status = 'NOT_GIVEN'`, with the
reason as the value), and **triage assessments** (score and complaints, unpivoted). Each row
carries the Tamanu source code/name and value with person / visit / provider foreign keys.
Deployment-specific observation sources are a per-deployment extension. Completes the split
started in `clinical__measurement` (BL-006: non-vitals survey answers belong here) and
`clinical__drug_exposure` (BL-007: NOT_GIVEN belongs here). See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping, `vocab__`),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per observation in OMOP `OBSERVATION` shape: native
UUID (or synthetic) PK, the observed fact retained as source code/name, the recorded value
(numeric where quantitative, verbatim otherwise), the observation datetime, and the person /
visit / provider foreign keys. OMOP's dividing line: `MEASUREMENT` holds values obtained by
measuring (vitals, labs); `OBSERVATION` holds everything else clinically relevant — survey
responses, refusal/not-done facts, assessments, social history.

**Clinical context.** Three sources, unioned:
- **Survey answers** — responses to `programs` and `referral` surveys (the Vitals survey feeds
  `clinical__measurement` instead), one `survey_response_answer` per question, typed by its
  `program_data_element`. Echo question types (`PatientData`, `UserData`) copy demographics
  already canonical in `clinical__person`, and `Instruction` rows are not answers — excluded.
- **Vaccinations not given** — `vaccine_administrations` rows with `status = 'NOT_GIVEN'`: a
  refusal/not-done fact, not an exposure. The value is the not-given reason
  (`not_given_reason_id` → `reference_data`, `type = 'vaccineNotGivenReason'`, falling back to
  the free-text `reason`); the vaccine is the observed thing.
- **Triage** — a `triages` row holds an acuity `score` plus chief/secondary complaints in
  *wide* form. `int__triage_observations` unpivots it to one row per recorded element,
  anchored to the triage's encounter and clinician.

**Who reads it.** `derived__cohort_*` and `metric__` indicators that need qualitative facts —
program-form flags (smoking status, risk factors), refusal reporting (vaccine hesitancy), and
emergency-department triage acuity line-lists.

**Standard model, deployment extension.** `tamanu-source-dbt` is the *standard* model: the
survey branch captures *all* program/referral answers generically, with no deployment-specific
data-element knowledge. A deployment that wants certain survey answers treated as measurements
instead (e.g. BP captured in an NCD program form — see MAUI-6425) extends
`clinical__measurement` in its `tamanu-dbt-<deployment>` project; see OQ-2 for the resulting
overlap. This is by design; the standard model stays universal.

## Grain

**One row per:** recorded program/referral-survey answer (PK `survey_response_answers.id`),
vaccination not given (PK `administered_vaccines.id`), or recorded triage element (synthetic
PK `<triage_id>-<element>`), unioned. Only rows with a recorded fact are kept (BL-006,
BL-008); NOT_GIVEN rows are kept even without a reason — the refusal itself is the fact
(BL-007). The three id spaces are disjoint, so `observation_id` is unique; all joins are
many-to-one, so grain is preserved.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `observation_id` | uuid or text | `survey_response_answers.id` (survey), `administered_vaccines.id` (not-given), or synthetic `<triage_id>-<element>` (triage). PK (D1) |
| `person_id` | uuid | `encounters.patient_id` via the source's encounter. FK to `clinical__person.person_id` |
| `observation_date` | date | Date component of the observation datetime |
| `observation_datetime` | timestamp | Survey: response `start_datetime`. Not-given: `datetime`. Triage: `triage_time` (application-required) |
| `observation_type_source_value` | text | `'program survey'`, `'referral survey'`, `'vaccination not given'`, or `'triage'` — provenance / union discriminator |
| `value_as_number` | numeric | The value cast to numeric when numeric (e.g. triage score, numeric survey answers); NULL otherwise |
| `value_source_value` | text | The recorded value verbatim — answer body, not-given reason, score, or complaint name. NULL only for a not-given row with no reason recorded |
| `provider_id` | uuid or text | Survey: `submitted_by_id`. Not-given: `coalesce(recorded_by_id, given_by)`. Triage: `clinician_id`. FK to `ref__provider.provider_id` except not-given rows (AC-005) |
| `visit_occurrence_id` | uuid | The source's `encounter_id`. FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `observation_source_value` | text | The observed thing's code — `program_data_elements.code`, the vaccine code (via schedule, else NULL), or the triage element key (`triage_score`, `chief_complaint`, `secondary_complaint`) |
| `observation_source_name` | text | The observed thing's readable name — data-element name, `vaccine_name`, or the triage element label |

`observation_concept_id` / `observation_source_concept_id`, `value_as_concept_id`, and
`unit_concept_id` are **not** emitted — see BL-003 and OQ-1.

## Business logic

- **BL-001:** The model is the `union all` of three branches — survey answers (BL-006),
  vaccinations not given (BL-007), and triage (BL-008) — sourced from
  `{{ ref('survey_response_answers') }}`, `{{ ref('survey_responses') }}`,
  `{{ ref('surveys') }}`, `{{ ref('program_data_elements') }}`,
  `{{ ref('vaccine_administrations') }}`, `{{ ref('vaccine_schedules') }}`,
  `{{ ref('reference_data') }}`, `{{ ref('int__triage_observations') }}`, and
  `{{ ref('encounters') }}` only (D10) — never `public.*`. Soft-delete / test-patient
  filtering is inherited from the base models; the branch PKs occupy disjoint id spaces so
  `observation_id` is unique, and the joins are many-to-one, so grain is preserved.
- **BL-002:** OMOP foreign keys are wired from the source row's encounter — `person_id` from
  `patient_id`, `visit_occurrence_id` from `encounter_id`, and `provider_id` from the survey
  submitter / triage clinician, or (not-given) `coalesce(recorded_by_id, given_by)` — with ids
  cast to `varchar` for a type-safe union. `provider_id` only resolves to `ref__provider` for
  survey/triage rows, since not-given's `given_by` fallback is free text, not a user FK
  (AC-005 is scoped accordingly).
- **BL-003:** The observed fact is retained as `observation_source_value` (code) and
  `observation_source_name`; `observation_concept_id` and `value_as_concept_id` are **not**
  emitted, since mapping Tamanu data elements / reasons / complaints to standard concepts
  needs the `vocab__` layer (D2), never replacing local values (D1, OQ-1).
- **BL-004:** `observation_datetime` is when the fact was recorded — the survey response
  `start_datetime`, the vaccination-not-given `datetime`, or the triage's `triage_time`
  (application-required, so the canonical triage moment). `observation_date` is its date
  component.
- **BL-005:** `observation_type_source_value` records provenance and is the union
  discriminator — `program survey`, `referral survey`, `vaccination not given`, or `triage` —
  with deployment extensions carrying their own values.
- **BL-006 (survey branch):** Every answer with a recorded (non-blank) `body` to a survey with
  `survey_type` in (`programs`, `referral`) is included — the Vitals survey feeds
  `clinical__measurement` instead (its BL-006), and `obsolete` surveys are excluded. Sensitive
  surveys (`is_sensitive`) are **included**: the `clinical__` layer is
  `classification: restricted` throughout, matching sensitive lab-test types in
  `clinical__measurement`. Echo / non-answer data-element types (`PatientData`, `UserData`,
  `Instruction`) are excluded; numeric answers also populate `value_as_number` (same
  signed-decimal pattern as `clinical__measurement` BL-003).
- **BL-007 (vaccination-not-given branch):** Every `vaccine_administrations` row with
  `status = 'NOT_GIVEN'` is included — the refusal/not-done fact is the observation, so rows
  are kept even when no reason was recorded (`value_source_value` NULL). The value is the
  not-given reason (`not_given_reason_id` → `reference_data.name`, falling back to the
  free-text `reason`); the vaccine identity is carried like `clinical__drug_exposure` BL-007
  (`vaccine_name` as the name; code via `scheduled_vaccine_id` → `vaccine_schedules` →
  `reference_data` when scheduled, else NULL). The status enum also has forward-looking
  values (`DUE`, `SCHEDULED`, `OVERDUE`, `UPCOMING`, `MISSED`, `UNKNOWN`) — these represent
  schedule state, not a recorded clinical fact, and are surfaced by the separate
  `upcoming_vaccinations` view rather than by rows here, so they're excluded.
- **BL-008 (triage branch):** Triage assessments are unpivoted from the wide `triages` row by
  `int__triage_observations` — one row per recorded element: `triage_score` (numeric, also in
  `value_as_number`), `chief_complaint`, and `secondary_complaint` (complaint names resolved
  from `reference_data` by id — an unfiltered join, since the complaint FKs only reference
  `triageReason` rows), blanks dropped. The `observation_id` is
  synthesised as `<triage_id>-<element>` (unique — one triage row per element), and the
  unpivot lives in the int model to keep this model a clean union.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `observation_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `observation_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `person_id` exists in `clinical__person.person_id` | BL-002 | dbt `relationships` |
| AC-004 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-002 | dbt `relationships` |
| AC-005 | Every non-null `provider_id` on a survey/triage row exists in `ref__provider.provider_id` (not-given excluded — `given_by` fallback is free text) | BL-002 | dbt `dbt_utils.relationships_where` |
| AC-006 | `observation_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-007 | `observation_type_source_value` is one of `program survey` / `referral survey` / `vaccination not given` / `triage` | BL-005 | dbt `accepted_values` |
| AC-008 | Every survey/triage row has a non-null `value_source_value` (not-given rows may be NULL — the refusal is the fact) | BL-006, BL-008 | singular test |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` / `derived__` artefacts get a `metric_definitions.csv` row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `survey_response_answers` | `bases/` | The answer value (`body`) and its data-element FK (survey branch) |
| `survey_responses` | `bases/` | Datetime, encounter (person + visit) anchor, submitter |
| `surveys` | `bases/` | Restrict the survey branch to `survey_type` in (`programs`, `referral`) |
| `program_data_elements` | `bases/` | The question (code + name + type, for the echo-type exclusion) |
| `vaccine_administrations` | `bases/` | NOT_GIVEN rows, reason, `vaccine_name`, encounter, recorder |
| `vaccine_schedules` | `bases/` | Resolves `scheduled_vaccine_id` to `reference_data.id` (vaccine code) |
| `reference_data` | `bases/` | Not-given reason name (`type = 'vaccineNotGivenReason'`) and vaccine code |
| `int__triage_observations` | `intermediate/` | Unpivots `triages` (+ `reference_data` complaints) into tall triage observations |
| `encounters` | `bases/` | Person (`patient_id`) via the source `encounter_id` |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-003) |
| `clinical__visit_occurrence` | `clinical/` | `visit_occurrence_id` FK target (AC-004) |
| `ref__provider` | `ref/` | `provider_id` FK target (AC-005) |

## Open questions

- **OQ-1:** `observation_concept_id` (LOINC/SNOMED), `value_as_concept_id` (standard concepts
  for answers/reasons/complaints), and `unit_concept_id` await the `vocab__` layer (D2).
  Source code/name/value are retained so the standard concepts layer on without reshaping.
- **OQ-2:** When a deployment reclassifies specific survey answers into its extended
  `clinical__measurement` (e.g. NCD-form BP), those answers also appear here as observations —
  a double representation. The deployment's override should exclude those data elements from
  its `clinical__observation`; settle the mechanics with the first deployment that needs it.
- **OQ-3:** Patient-level characteristics in `patient_additional_data` (`blood_type`,
  `marital_status`, `educational_level`, occupation) are OMOP observations too. Add a fourth,
  patient-level branch via an `int__patient_characteristic_observations` unpivot (the
  `int__patient_birth_measurements` pattern) when a consumer needs them.

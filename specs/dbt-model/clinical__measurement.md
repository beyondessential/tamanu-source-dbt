# dbt Model Spec: `clinical__measurement` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__measurement` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-04 |
| **Last updated** | 2026-09-05 |

The OMOP-lite `MEASUREMENT` domain — one row per clinical measurement (numeric or
categorical), unioning three standard sources: **vitals** (blood pressure, weight, glucose,
AVPU, …) recorded via the Tamanu **Vitals survey**, **lab-test results**, and **birth
anthropometry** (birth weight/length, APGAR, gestational age) from `patient_birth_data`.
Deployment-specific measurements are a per-deployment extension. Feeds the NCD
"under control" indicators, which key on recent BP / glucose readings. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping, `surveys`/`vocab__`),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per recorded answer to a Vitals-survey response —
i.e. one recorded vital sign (systolic/diastolic BP, weight, height, blood glucose, heart
rate, SpO2, AVPU, …), in OMOP `MEASUREMENT` shape: native UUID PK, the value (numeric where
the vital is quantitative, else the categorical source value), the Tamanu vital retained as
the source value, the measurement datetime, and the person / visit / provider foreign keys.
Vitals are **not always numeric** — categorical vitals (e.g. AVPU, urine dipstick) are
measurements too, carried via `value_source_value` with `value_as_number` NULL.

**Clinical context.** Three sources, unioned:
- **Vitals** — Tamanu's dedicated `vitals` table is **deprecated**; vitals are now responses
  to the core **Vitals survey** (`surveys.survey_type = 'vitals'`), one
  `survey_response_answer` per vital, typed by the answer's `program_data_element`.
- **Labs** — a completed `lab_tests` row carries a `result`, typed by its `lab_test_type`
  (code, name, unit), under a `lab_request` tied to an encounter.
- **Birth anthropometry** — `patient_birth_data` holds birth weight/length, APGAR scores,
  and gestational age in *wide* form (one row per patient). `int__patient_birth_measurements`
  unpivots it to one row per measure; these are patient-level (no encounter).

OMOP analytics expect all three as `MEASUREMENT` rows keyed by `measurement_id`; lab results
and birth anthropometry are `MEASUREMENT`s in OMOP, so they belong here, not in a separate
model.

**Who reads it.** `derived__cohort_*` and `metric__` NCD indicators — most importantly the
hypertension / diabetes "under control" family, which reads the most recent BP / glucose
measurement per patient (see the `hypertension_controlled` worked example in D5); and
`dataset__` vitals line-lists.

**Standard model, deployment extension.** `tamanu-source-dbt` is the *standard* model: it
covers the standard Tamanu **Vitals survey**, which every deployment shares. A deployment
that records additional measurements (deployment-specific vitals, or measurements captured
in a program/registry survey) **extends `clinical__measurement` in its own
`tamanu-dbt-<deployment>` project** — the per-deployment override mechanism (D2) — to union
those in. This is by design, not an omission; the standard model stays universal.

## Grain

**One row per:** recorded Vitals-survey answer (PK `survey_response_answers.id`),
lab test carrying a reading (PK `lab_tests.id`), or recorded birth measure (synthetic
PK `<patient_id>-birthdata-<measure>`), unioned. Only rows with a recorded (non-blank) value
are kept (BL-006, BL-007, BL-008); numeric values populate `value_as_number`, categorical
values carry `value_source_value` with `value_as_number` NULL. The three id spaces are
disjoint, so `measurement_id` is unique across the union; all joins are many-to-one, so grain
is preserved.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `measurement_id` | uuid | `survey_response_answers.id` (vital), `lab_tests.id` (lab), or synthetic `<patient_id>-birthdata-<measure>` (birth). PK (D1) |
| `person_id` | uuid | `encounters.patient_id` (vitals/labs, via `encounter_id`) or `patient_id` directly (birth). FK to `clinical__person.person_id` |
| `measurement_date` | date | Date component of the measurement datetime |
| `measurement_datetime` | timestamp | Vitals: response `start_time`. Labs: `lab_tests.completed_datetime` (→ published/requested). Birth: birth datetime (→ registration date) |
| `measurement_type_source_value` | text | `'vitals survey'`, `'lab'`, or `'birth data'` — provenance / union discriminator |
| `value_as_number` | numeric | The value cast to numeric when numeric; **NULL for categorical results** (BL-003, BL-006, BL-007) |
| `value_source_value` | text | The recorded value, whitespace-trimmed. Always populated — the canonical value for categorical results |
| `unit_source_value` | text | Unit of measure. Labs: `lab_test_types.unit`. NULL for vitals (units implicit, not stored per answer) |
| `provider_id` | uuid | Vitals: response submitter. Labs: requesting clinician. Birth: NULL (no user recorded). FK to `ref__provider.provider_id` |
| `visit_occurrence_id` | uuid | The source's `encounter_id`; **NULL for birth measurements** (patient-level). FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `measurement_source_id` | uuid | The source system's identifier for the thing measured — `lab_tests.lab_test_type_id` (lab) or `survey_response_answers.data_element_id` (vital). NULL for birth anthropometry (no reference-data record) |
| `measurement_source_value` | text | The measurement type's code — `program_data_elements.code` (vital) or `lab_test_types.code` (lab) |
| `measurement_source_name` | text | The measurement type's name, denormalised for readability |

`measurement_concept_id` / `measurement_source_concept_id` (OMOP standard LOINC),
`value_as_concept_id` (standard concept for a categorical result), and `unit_concept_id`
are **not** emitted — see BL-003 and OQ-1.

## Business logic

- **BL-001:** The model is the `union all` of three branches — vitals (BL-006), labs
  (BL-007), and birth anthropometry (BL-008) — sourced from `{{ ref('survey_response_answers') }}`,
  `{{ ref('survey_responses') }}`, `{{ ref('surveys') }}`, `{{ ref('program_data_elements') }}`,
  `{{ ref('lab_tests') }}`, `{{ ref('lab_requests') }}`, `{{ ref('lab_test_types') }}`,
  `{{ ref('map__lab_test_result_encoding') }}`,
  `{{ ref('int__patient_birth_measurements') }}`, and `{{ ref('encounters') }}` only (D10) —
  never `public.*`. Soft-delete / test-patient filtering is inherited from the base models;
  the branch PKs (`survey_response_answers.id`, `lab_tests.id`, and the synthetic
  `<patient_id>-birthdata-<measure>`) occupy disjoint id spaces so `measurement_id` is unique,
  and the joins are many-to-one, so grain is preserved.
- **BL-002:** OMOP foreign keys are wired from the source row's encounter: `person_id` is the
  encounter's `patient_id`, `visit_occurrence_id` is the `encounter_id` (the vitals response's
  or the lab request's), and `provider_id` is the vitals submitter / lab requester. Ids are
  cast to `varchar` for a type-safe union. All resolve to `clinical__person`,
  `clinical__visit_occurrence`, and `ref__provider`.
- **BL-003:** `value_as_number` is the value cast to numeric **only when it is numeric** (a
  signed-decimal pattern); for categorical results it is NULL. `value_source_value` always
  keeps the recorded value — the canonical value for categorical results (e.g. AVPU) and the
  raw value for numeric ones. `measurement_source_value`/`_name` are the measurement type's
  code/name (vital data element or lab test type); `unit_source_value` is the lab test's unit
  (NULL for vitals). `measurement_concept_id` (LOINC) and `value_as_concept_id` (a standard
  concept for a categorical result) are **not** emitted: mapping Tamanu data elements / lab
  test types / result options to standard concepts needs the `vocab__` layer (D2, and the
  `lookup__vital_type` seed noted there), not inline logic. Source code/name/value are
  retained so the standard concepts layer on later (OQ-1), never replacing local values (D1).
- **BL-004:** `measurement_datetime` is when the measurement was taken — the vitals response
  `start_time`, or for labs `lab_tests.completed_datetime` (falling back to the request's
  `published`/`requested` datetime). `measurement_date` is its date component.
- **BL-005:** `measurement_type_source_value` records provenance and is the union
  discriminator: `'vitals survey'`, `'lab'`, or `'birth data'`. Deployment extensions
  carry their own values.
- **BL-006 (vitals branch):** Every Vitals-survey (`survey_type = 'vitals'`) answer with a
  recorded (non-blank) `body` is included — **numeric and categorical alike**, since a
  categorical vital (e.g. AVPU) is still a measurement in OMOP (value in
  `value_source_value`). Only blank/unanswered questions are excluded. The
  measurement/observation split is by **survey**, not value type: the Vitals survey feeds
  `clinical__measurement`; qualitative results from *other* surveys (social history,
  program-survey flags) feed `clinical__observation`.
- **BL-007 (lab branch):** Every `lab_tests` row carrying a reading is included, joined through
  `lab_requests` to its encounter and `lab_test_types` for the test code/name/unit. A reading is
  a recorded (non-blank) `result`, or a result encoded in the test type (BL-009). A test with
  neither is excluded — a measurement exists only once a reading exists. Numeric results
  populate `value_as_number`; qualitative results (e.g. "positive"/"negative") carry
  `value_source_value`.
- **BL-008 (birth-data branch):** Birth anthropometry (birth weight, birth length, APGAR at
  1/5/10 min, gestational age estimate) is unpivoted from the wide `patient_birth_data` by
  `int__patient_birth_measurements` — one row per recorded measure, blanks dropped. These are
  **patient-level**: `person_id` is the `patient_id` directly (the int model inner-joins
  `patients`, so only valid non-test/non-merged patients appear), `visit_occurrence_id` and
  `provider_id` are NULL, and `measurement_datetime` is the birth datetime
  (`patients.date_of_birth` + `time_of_birth`, falling back to the registration date). The
  `measurement_id` is synthesised as `<patient_id>-birthdata-<measure>` (unique — one birth
  record per patient). Unpivot logic lives in the int model to keep this model a clean union.
- **BL-009 (encoded results):** A point-of-care test is recorded by choosing a result-bearing
  test type rather than by entering a result, so where `lab_tests.result` is blank and
  `map__lab_test_result_encoding` covers the test type, the encoded result is the reading. The
  map carries the reading as the test reports it (`encoded_result`) and whether that reading
  indicates the target condition was detected (`is_positive`); it is empty in this repo and is
  the extension point a deployment overrides — unique on `lab_test_type_id` — to name its own
  result-bearing test types, so the branch behaves identically everywhere until one does.
- **BL-010 (source identifier):** `measurement_source_id` carries the source system's identifier
  for the thing measured — the lab test type for a lab, the program data element for a vitals
  answer, and nothing for birth anthropometry — alongside the code in `measurement_source_value`.
- **BL-011 (withdrawn requests):** A request whose status is `cancelled`, `deleted`,
  `entered-in-error`, `invalidated`, `rejected` or `sample-not-collected` yields no measurement,
  even where a stale result lingers on it.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `measurement_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `measurement_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `person_id` exists in `clinical__person.person_id` | BL-002 | dbt `relationships` |
| AC-004 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-002 | dbt `relationships` |
| AC-005 | Every non-null `provider_id` exists in `ref__provider.provider_id` | BL-002 | dbt `relationships` |
| AC-006 | `value_source_value` is `not_null` (every measurement has a recorded value; `value_as_number` is nullable for categorical results) | BL-006, BL-007 | dbt `not_null` |
| AC-007 | `measurement_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-008 | No lab measurement comes from a request in a withdrawn status | BL-011 | dbt singular |
| AC-009 | Every lab measurement carries a non-blank reading | BL-007, BL-009 | dbt singular |
| AC-010 | Where the typed result is blank and the test type is in the encoding map, the encoded result is the reading, and a typed result wins where both exist | BL-009 | dbt unit test |
| AC-011 | A lab measurement's `measurement_source_id` is its `lab_test_type_id` | BL-010 | dbt unit test |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` / `derived__` artefacts get a `metric_definitions.csv` row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `survey_response_answers` | `bases/` | The measurement value (`body`) and its data-element FK |
| `survey_responses` | `bases/` | Datetime, encounter (person + visit) anchor, submitter |
| `surveys` | `bases/` | Restrict the vitals branch to `survey_type = 'vitals'` |
| `program_data_elements` | `bases/` | The vital type (code + name) |
| `lab_tests` | `bases/` | Lab result value, completed datetime, test-type FK (lab branch) |
| `lab_requests` | `bases/` | Lab encounter anchor, requester, request datetimes |
| `lab_test_types` | `bases/` | Lab test code, name, and unit |
| `map__lab_test_result_encoding` | `maps/` | Test types whose identity carries the result, for point-of-care readings with no typed result (BL-009) |
| `int__patient_birth_measurements` | `intermediate/` | Unpivots `patient_birth_data` (+ `patients`) into tall birth measurements (birth branch) |
| `encounters` | `bases/` | Person (`patient_id`) via the source `encounter_id` (vitals/labs) |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-003) |
| `clinical__visit_occurrence` | `clinical/` | `visit_occurrence_id` FK target (AC-004) |
| `ref__provider` | `ref/` | `provider_id` FK target (AC-005) |

## Open questions

- **OQ-1:** `measurement_concept_id` (LOINC), `value_as_concept_id` (a standard concept for
  categorical results such as AVPU levels), and `unit_concept_id` await a measurement-type
  map (`lookup__vital_type`, D2) / the `vocab__` layer. `unit_source_value` is populated for
  labs; vitals units remain implicit in the Tamanu vital data element (not stored per answer).

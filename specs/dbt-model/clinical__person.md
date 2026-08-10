# dbt Model Spec: `clinical__person` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__person` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-28 |
| **Last updated** | 2026-07-22 |

The OMOP-lite `PERSON` domain — the canonical patient-demographics surface every
other `clinical__`, `derived__`, `metric__`, and `dataset__` model joins to. First
model of the canonical clinical layer; root of the OMOP foreign-key graph
(`person_id` is carried by every event table). See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per real, non-merged patient, in OMOP
`PERSON` shape: native UUID primary key, decomposed birth date, death date, and
OMOP concept-ID shadow columns sitting *alongside* the local source values
(never replacing them — D1 OMOP-lite).

**Clinical context.** Tamanu records patient demographics across `patients`,
`patient_additional_data`, and `patient_birth_data`. OMOP analytics expect a single
canonical `PERSON` row keyed by `person_id`. This model is that contract.

**Who reads it.** Every downstream canonical model that needs patient identity or
demographics: `clinical__visit_occurrence` and the event tables (via `person_id`),
`derived__cohort_*` (`subject_id = person_id`), `metric__` disaggregations
(`gender_concept_id`, age derived from birth), and `dataset__` patient summaries.

## Grain

**One row per:** patient.

Source `patients` (via `bases/`) already filters soft-deleted, merged, and the test
patient. Relies on the Tamanu invariant that `patient_additional_data` and
`patient_birth_data` hold at most one row per `patient_id` (application-enforced
1:1), so the left joins do not fan out. AC-002 (`person_id` unique) guards against
violation of that invariant.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `person_id` | uuid | `patients.id`. Native UUID PK — no remap to OMOP integer IDs (D1) |
| `person_source_value` | text | `patients.display_id` (MRN / business identifier). Direct identifier — populated only on `reporting_*` targets, NULL on the replica (BL-006) |
| `gender_concept_id` | integer | OMOP Gender concept from `map__omop_sex` (8507 Male, 8532 Female, 0 no-match). NULL if the local sex value is unmapped |
| `gender_source_value` | text | Local Tamanu sex value, retained alongside the concept (D1) |
| `year_of_birth` | integer | From `date_of_birth`; NULL if DOB unknown |
| `month_of_birth` | integer | From `date_of_birth` |
| `day_of_birth` | integer | From `date_of_birth` |
| `birth_datetime` | timestamp | `date_of_birth` at `birth_time`. NULL when no time of birth was recorded |
| `ethnicity_source_value` | text | `patient_additional_data.ethnicity_id`. Concept shadow is deployment-specific (BL-004) — not resolved here |
| `location_id` | uuid | `patients.village_id`. FK to `ref__location` (the patient's village). OMOP `PERSON.location_id` |

## Business logic

- **BL-001:** One row per patient, sourced from `{{ ref('patients') }}` only — never
  `public.*` (D10). Deleted / merged / test-patient filtering is inherited from the
  base model.
- **BL-002:** `gender_concept_id` is the OMOP concept for the patient's sex, looked
  up from `map__omop_sex` on `lower(sex) = local_code`. The local value is preserved
  verbatim as `gender_source_value`. An unmapped sex yields a NULL concept (the row is
  kept, never dropped).
- **BL-003:** Birth is decomposed from the source `date_of_birth` into `year_of_birth`,
  `month_of_birth`, `day_of_birth` (no redundant full-date column is emitted — OMOP
  PERSON carries only the components). `birth_datetime` combines the source date with
  `patient_birth_data.birth_time` (source `time_of_birth`) when present, and is NULL otherwise — no midnight
  default, so the timestamp never implies a precision the data lacks. When
  `birth_datetime` is non-null, its date equals
  `make_date(year_of_birth, month_of_birth, day_of_birth)`.
- **BL-004:** `ethnicity_source_value` carries the raw `ethnicity_id`. No
  `ethnicity_concept_id` shadow is emitted: ethnicity → OMOP mappings are
  deployment-specific (`map__omop_ethnicity` lives in `tamanu-dbt-<deployment>`), and
  concept columns are added only when actively used, never speculatively
  (derived-elements-conventions § map__omop seeds).
- **BL-005:** All demographic enrichment joins (`patient_additional_data`,
  `patient_birth_data`, `map__omop_sex`) are `left join` so a missing record yields
  NULL rather than dropping the patient. Only the patient record itself is required.
- **BL-006:** `person_source_value` carries the patient's `display_id` (the OMOP
  source identifier / MRN). `display_id` is a direct identifier that `bases/` drops on
  analytics targets, so it is selected only when `not is_analytics_target()`
  (`reporting_*` production targets) and emitted as NULL on the replica. This keeps the
  canonical clinical layer replica-safe while still exposing the MRN where PII is
  permitted (D10, production-promotion).
- **BL-007:** `location_id` is the patient's `village_id`, exposed as an OMOP
  `PERSON.location_id` FK into `ref__location`. The local value is unchanged — the FK
  simply makes it a typed, validated join target rather than a raw reference.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `person_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `person_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every non-null `gender_concept_id` exists in `map__omop_sex.concept_id` | BL-002 | dbt `relationships` |
| AC-004 | When `birth_datetime` is non-null, its date equals `make_date(year_of_birth, month_of_birth, day_of_birth)` | BL-003 | dbt singular test |
| AC-005 | Every non-null `location_id` exists in `ref__location.location_id` | BL-007 | dbt `relationships` |
| AC-006 | `year_of_birth` is between `1900` and the current year (no future births); NULL passes | BL-003 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-007 | `month_of_birth` is between `1` and `12`; NULL passes | BL-003 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-008 | `day_of_birth` is between `1` and `31`; NULL passes | BL-003 | `dbt_expectations.expect_column_values_to_be_between` |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` and `derived__` artefacts get a `metric_definitions.csv`
row (D5, dbt-conventions § Documentation).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `patients` | `bases/` | Patient identity, sex, DOB, DOD, village |
| `patient_additional_data` | `bases/` | Ethnicity source value |
| `patient_birth_data` | `bases/` | Time of birth for `birth_datetime` |
| `map__omop_sex` | `maps/` | Tamanu sex → OMOP Gender concept (universal) |
| `ref__location` | `ref/` | OMOP LOCATION target for `location_id` (patient's village) |

## Open questions

- **OQ:** Death is intentionally **not** modelled here — OMOP keeps death in a
  dedicated `DEATH` table, not on `PERSON`. `patients.date_of_death` is available via
  `bases/` and can be surfaced as a future `clinical__death` domain when a consumer
  needs it.

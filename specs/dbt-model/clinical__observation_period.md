# dbt Model Spec: `clinical__observation_period` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__observation_period` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-19 |
| **Last updated** | 2026-07-22 |

The OMOP-lite `OBSERVATION_PERIOD` domain — the span during which a patient is
"at-risk to have a clinical event recorded". Placed in `clinical__` for usage
simplicity although OMOP categorises it as a derived element (D2). Completes the
seven-domain canonical clinical set. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One continuous span per patient over which the
absence of a record can be read as the absence of an event. Bounds derive from the
patient's recorded clinical activity across all five event domains, per the OMOP CDM
v5.4 EHR convention: *"the start date of the first occurrence … of a Clinical Event
is defined as the start of the OBSERVATION_PERIOD record, and the end date of the
last occurrence … becomes the end of the OBSERVATION_PERIOD for each Person."*

**Clinical context.** Tamanu is an EHR with no enrolment concept, so observation
periods are inferred from recorded activity rather than coverage spans. One period
per patient is the deliberate starting shape: OMOP forbids overlapping or
back-to-back periods ("Any two overlapping or adjacent OBSERVATION_PERIOD records
have to be merged into one"), and Tamanu records no capture discontinuities that
would justify splitting. Clinical episodes (e.g. pregnancies) are **not** observation
periods — they belong to `derived__episode_<name>` (derived-elements-conventions
§ Episodes).

**Who reads it.** `derived__` incidence / prevalence / LTFU logic (denominator
person-time), `metric__` rate calculations, and any analysis needing "was this
patient observable during period X". **This model is the whole-history, reusable
input** — a cohort-scoped LTFU/incidence denominator (registration-to-exit) must
still wrap it (or build its own bounds) via an `int__<name>_observation_period`
ephemeral per derived-elements-conventions § Observation period. Consuming this
model directly as a cohort denominator would overstate person-time to the patient's
entire recorded history, not the cohort's enrolment window.

## Grain

**One row per:** patient with at least one recorded clinical event. Grain is
guaranteed by `group by person_id` over the unioned event dates.

## Output schema

Exactly the OMOP v5.4 `OBSERVATION_PERIOD` columns:

| Column | Type | Notes |
|---|---|---|
| `observation_period_id` | uuid | Equals `person_id` — one period per person, native UUID, no remap (D1) (BL-003) |
| `person_id` | uuid | FK to `clinical__person.person_id` |
| `observation_period_start_date` | date | Earliest recorded event date across all domains (BL-002) |
| `observation_period_end_date` | date | Latest recorded event date across all domains (BL-002) |
| `period_type_concept_id` | integer | Constant 44814724 — "Period covering healthcare encounters" (BL-004) |

## Business logic

- **BL-001:** One row per patient with ≥ 1 recorded clinical event. Sourced only from
  the five canonical event domains — `clinical__visit_occurrence`,
  `clinical__condition_occurrence`, `clinical__measurement`, `clinical__drug_exposure`,
  `clinical__observation` — which themselves satisfy D10; no direct `bases/` or
  `public.*` access.
- **BL-002:** `observation_period_start_date` is the `min`, and
  `observation_period_end_date` the `max`, over the union of contributing event dates:
  visit start **and** end dates, condition start dates, measurement dates, drug
  exposure start **and** end dates (`drug_exposure_end_datetime::date` — the domain
  carries no end-date column), and observation dates. End-type dates count because
  OMOP's EHR convention bounds the period by the *"end date of the last occurrence"*
  of a clinical event. NULL dates are excluded leg-by-leg; open visits therefore
  contribute only their start. Future-dated ends (e.g. a prescription with an
  end date after the replica snapshot date) are **not** capped — the raw `max()`
  is taken as recorded, so `observation_period_end_date` can extend into the
  future. This is a deliberate design decision, not a placeholder.
- **BL-003:** `observation_period_id` equals `person_id`. With exactly one period per
  person the person key is the natural period key; no synthetic id is minted (D1). If
  period-splitting is ever introduced, the id becomes a derived key and this clause
  is superseded.
- **BL-004:** `period_type_concept_id` is the constant 44814724 ("Period covering
  healthcare encounters") — all periods derive from EHR activity; no per-row variation,
  no map seed (same pattern as `clinical__visit_occurrence.visit_type_concept_id`).
- **BL-005:** Patients with **no** recorded events are not emitted. Documented
  OMOP-lite deviation: OMOP requires ≥ 1 period per person, but an event-less patient
  has no derivable bounds, and fabricating one (e.g. registration date) would break
  the "absence of a record means absence of an event" contract.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `observation_period_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `observation_period_id` is `unique` (one period per person) | grain, BL-003 | dbt `unique` |
| AC-003 | `person_id` is `not_null` and every value exists in `clinical__person.person_id` | BL-001 | dbt `not_null` + `relationships` |
| AC-004 | `observation_period_start_date` and `observation_period_end_date` are `not_null` | BL-002 | dbt `not_null` |
| AC-005 | `period_type_concept_id` is `not_null` and always 44814724 | BL-004 | dbt `not_null` + `accepted_values` |
| AC-006 | `observation_period_end_date >= observation_period_start_date` on every row | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-007 | Bounds span all domains: start from the earliest event (any domain), end from the latest (including a drug-exposure end date); a visit-less patient (e.g. birth measurements only) still gets a period; an open visit contributes only its start | BL-001, BL-002, BL-005 | dbt unit test (`test_clinical__observation_period_spans_all_domains`) |
| AC-008 | A future-dated event end (e.g. a drug exposure end date after today) flows through as `observation_period_end_date` uncapped | BL-002 | dbt unit test (`test_clinical__observation_period_does_not_cap_future_dated_ends`) |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` and `derived__` artefacts get a `metric_definitions.csv`
row (D5, dbt-conventions § Documentation).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_occurrence` | `clinical/` | Visit start / end dates |
| `clinical__condition_occurrence` | `clinical/` | Condition start dates |
| `clinical__measurement` | `clinical/` | Measurement dates (incl. visit-less birth anthropometry) |
| `clinical__drug_exposure` | `clinical/` | Drug exposure start / end dates |
| `clinical__observation` | `clinical/` | Observation dates |
| `clinical__person` | `clinical/` | Parent PERSON domain; `person_id` FK target (AC-003) |

## Open questions

None outstanding.

# dbt Model Spec: `clinical__drug_exposure` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__drug_exposure` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-09 |
| **Last updated** | 2026-07-22 |

The OMOP-lite `DRUG_EXPOSURE` domain — one row per drug exposure, unioning three standard
sources: **medication prescriptions** (the clinical intent to treat), **vaccine
administrations** (`status = 'GIVEN'`), and **pharmacy dispenses** (the physical hand-over of
stock). Each row carries the Tamanu drug/vaccine as the source value with person / visit /
provider foreign keys. Deployment-specific drug sources are a per-deployment extension. Feeds
the NCD "on treatment" indicators (e.g. patients on antihypertensives / metformin) and
immunisation-coverage metrics. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping, `vocab__`),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact measures.** One row per drug exposure in OMOP `DRUG_EXPOSURE` shape:
native UUID PK, the exposure start/end datetimes, the Tamanu drug/vaccine retained as the
source value, and the person / visit / provider foreign keys. A "drug exposure" spans the
whole medication lifecycle — a clinician *prescribing* a drug, a *vaccine being given*, and a
pharmacy *dispensing* stock are all exposures in OMOP, distinguished by
`drug_exposure_type_source_value` so a consumer can pick the evidence level it needs.

**Clinical context.** Three sources, unioned:
- **Prescriptions** — a `prescriptions` row is the clinical intent to treat: drug
  (`medication_id` → `reference_data`, `type = 'drug'`), prescriber, dose/route/frequency,
  start/end dates, and a discontinuation trail. It has no encounter of its own — the
  `encounter_prescriptions` link table ties it to an encounter.
- **Vaccinations** — a `vaccine_administrations` row records a vaccine event against an
  encounter, carrying the denormalised `vaccine_name` and a `status`; only `GIVEN` rows are
  actual exposures. `scheduled_vaccine_id` (nullable — ad hoc/catch-up doses aren't scheduled)
  resolves through `vaccine_schedules` to `reference_data` (`type = 'drug'`, the same
  namespace as prescriptions) for a coded `drug_source_value` when available.
- **Dispenses** — a `medication_dispenses` row is the physical supply event, reached through
  the pharmacy chain (`pharmacy_order_prescriptions` → `pharmacy_orders` → encounter, and →
  the originating `prescription` for the drug identity). It carries only quantity/when/by-whom.

Prescriptions are the universal signal (every deployment prescribes); the pharmacy/dispensing
module is newer and not present in every deployment. All three are `DRUG_EXPOSURE` rows in
OMOP, so they belong in one model, type-discriminated, not in separate models.

**Who reads it.** `derived__cohort_*` and `metric__` NCD indicators — most importantly the
hypertension / diabetes "on treatment" family, which asks whether a patient has a current
prescription for a relevant drug class; and immunisation-coverage `dataset__` line-lists.

**Standard model, deployment extension.** `tamanu-source-dbt` is the *standard* model: it
covers the standard Tamanu prescription, vaccine, and dispense tables that every deployment
shares. A deployment that records additional drug sources **extends `clinical__drug_exposure`
in its own `tamanu-dbt-<deployment>` project** — the per-deployment override mechanism (D2) —
to union those in. This is by design, not an omission; the standard model stays universal.

## Grain

**One row per:** medication prescription linked to an encounter (PK
`encounter_prescriptions.id` — see BL-006), vaccine administration with `status = 'GIVEN'`
(PK `administered_vaccines.id`), or pharmacy dispense (PK `medication_dispenses.id`), unioned.
The three id spaces are disjoint, so `drug_exposure_id` is unique across the union; all joins
are many-to-one relative to the row's own PK, so grain is preserved.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `drug_exposure_id` | uuid | `encounter_prescriptions.id` (prescription — not `prescriptions.id`, see BL-006), `administered_vaccines.id` (vaccination), or `medication_dispenses.id` (dispense). PK (D1) |
| `person_id` | uuid | `encounters.patient_id` via the source's encounter. FK to `clinical__person.person_id` |
| `drug_exposure_start_date` | date | Date component of the start datetime |
| `drug_exposure_start_datetime` | timestamp | Prescription: `start_date` (→ `date`). Vaccination: `date`. Dispense: `dispensed_at` |
| `drug_exposure_end_datetime` | timestamp | Prescription: `end_date`. Vaccination / dispense: the start datetime (point events) |
| `drug_exposure_type_source_value` | text | `'prescription'`, `'vaccination'`, or `'dispense'` — provenance / union discriminator |
| `quantity` | numeric | Prescription: `quantity`. Dispense: `quantity`. Vaccination: NULL |
| `refills` | integer | Prescription: `repeats`. NULL for vaccination / dispense |
| `route_source_value` | text | Prescription: `route`. Vaccination: `injection_site`. Dispense: the prescription's `route` |
| `stop_reason` | text | Prescription: `discontinuing_reason` (when discontinued). NULL for vaccination / dispense |
| `provider_id` | uuid or text | Prescription: `prescriber_id`. Vaccination: `coalesce(recorded_by_id, given_by)` — the recording user when captured, else the free-text administerer name. Dispense: `dispensed_by_user_id`. FK to `ref__provider.provider_id` for prescription/dispense only (AC-005) |
| `visit_occurrence_id` | uuid | The source's `encounter_id`. FK to `clinical__visit_occurrence.visit_occurrence_id` |
| `drug_source_value` | text | Prescription / dispense: `reference_data.code`. Vaccination: `reference_data.code` via `scheduled_vaccine_id` when the dose is scheduled, else NULL (ad hoc/catch-up) |
| `drug_source_name` | text | Prescription / dispense: `reference_data.name`. Vaccination: `vaccine_name`, always populated regardless of `drug_source_value` |

`drug_concept_id` / `drug_source_concept_id` (OMOP standard RxNorm / CVX),
`route_concept_id`, and `drug_type_concept_id` are **not** emitted — see BL-003 and OQ-1.

## Business logic

- **BL-001:** The model is the `union all` of three branches — prescriptions (BL-006),
  vaccinations (BL-007), and dispenses (BL-008) — sourced from `{{ ref('prescriptions') }}`,
  `{{ ref('encounter_prescriptions') }}`, `{{ ref('reference_data') }}`,
  `{{ ref('vaccine_administrations') }}`, `{{ ref('vaccine_schedules') }}`,
  `{{ ref('medication_dispenses') }}`, `{{ ref('pharmacy_order_prescriptions') }}`,
  `{{ ref('pharmacy_orders') }}`, and `{{ ref('encounters') }}` only (D10) — never `public.*`.
  Soft-delete / test-patient
  filtering is inherited from the base models; the branch PKs occupy disjoint id spaces so
  `drug_exposure_id` is unique, and the joins are many-to-one, so grain is preserved.
- **BL-002:** OMOP foreign keys are wired from the source row's encounter — `person_id` from
  `patient_id`, `visit_occurrence_id` from `encounter_id`, and `provider_id` from the
  prescriber / dispenser, or (vaccination) `coalesce(recorded_by_id, given_by)` — with ids
  cast to `varchar` for a type-safe union. `person_id` and `visit_occurrence_id` always
  resolve; `provider_id` only resolves to `ref__provider` for prescription/dispense rows,
  since vaccination's `given_by` fallback is free text, not a user FK (AC-005 is scoped
  accordingly).
- **BL-003:** The Tamanu drug/vaccine is retained as `drug_source_value` (code) and
  `drug_source_name`. `drug_concept_id` (RxNorm) and the vaccine CVX concept are **not**
  emitted: mapping Tamanu drugs / vaccines to standard concepts needs the `vocab__` layer (D2),
  not inline logic, and source code/name are retained so the concepts layer on later (OQ-1),
  never replacing local values (D1).
- **BL-004:** `drug_exposure_start_datetime` is when the exposure began — the prescription
  `start_date` (falling back to `date`), the vaccination `date`, or the dispense
  `dispensed_at`. `drug_exposure_end_datetime` is the prescription `end_date`; vaccinations and
  dispenses are point events, so their end equals their start.
- **BL-005:** `drug_exposure_type_source_value` records provenance and is the union
  discriminator — `prescription`, `vaccination`, or `dispense` — with deployment extensions
  carrying their own values.
- **BL-006 (prescription branch):** Every `prescriptions` row is included, joined to its
  encounter through `encounter_prescriptions` and to `reference_data` via `medication_id` for
  the drug code/name — a plain id join, not filtered on `type = 'drug'`, since `medication_id`
  only ever references a drug-type row by Tamanu's own referential convention. `drug_exposure_id`
  is `encounter_prescriptions.id`, not `prescriptions.id`: a prescription carries no
  `encounter_id` of its own — the association is only reachable through
  `encounter_prescriptions` — and only that table's own `id` is declared unique (not
  `prescription_id`), so a prescription genuinely linked to more than one encounter must not
  collide on the exposure's primary key. Discontinued prescriptions are **kept** — the
  exposure still occurred — with `stop_reason` carrying `discontinuing_reason`; `quantity`,
  `refills` (`repeats`), and `route` come from the prescription.
- **BL-007 (vaccination branch):** Only `vaccine_administrations` rows with `status = 'GIVEN'`
  are included. `NOT_GIVEN` is not an exposure (it belongs in `clinical__observation`),
  `RECORDED_IN_ERROR` is a deleted GIVEN, and `HISTORICAL` is a hidden shadow of a separate
  GIVEN record — all three are excluded to avoid double-counting. `drug_source_name` is
  always the row's own `vaccine_name`; `drug_source_value` is left-joined through
  `scheduled_vaccine_id` → `vaccine_schedules` → `reference_data` and is NULL for
  administrations not tied to a scheduled dose.
- **BL-008 (dispense branch):** Every `medication_dispenses` row is included, reached through
  `pharmacy_order_prescriptions` → `pharmacy_orders` for the encounter, and via
  `pharmacy_order_prescriptions` → the originating `prescriptions` row (and `reference_data`)
  for the drug identity. The dispenser is the dispense's own `dispensed_by_user_id`, not a
  `pharmacy_orders` column. `quantity` is the dispensed quantity; `route` is inherited from
  the prescription.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `drug_exposure_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `drug_exposure_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `person_id` exists in `clinical__person.person_id` | BL-002 | dbt `relationships` |
| AC-004 | Every `visit_occurrence_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-002 | dbt `relationships` |
| AC-005 | Every non-null `provider_id` on a `prescription`/`dispense` row exists in `ref__provider.provider_id` (vaccination excluded — `given_by` fallback is free text) | BL-002 | dbt `dbt_utils.relationships_where` |
| AC-006 | `drug_exposure_start_datetime` is `not_null` | BL-004 | dbt `not_null` |
| AC-007 | `drug_exposure_type_source_value` is one of `prescription` / `vaccination` / `dispense` | BL-005 | dbt `accepted_values` |
| AC-008 | `drug_source_name` is `not_null` (every exposure names a drug/vaccine) — a data-quality signal at project `warn` severity: a failure means a `medication_id` / `vaccine_name` didn't resolve (e.g. a soft-deleted or absent `reference_data` row), not that the row should be dropped | BL-003 | dbt `not_null` |
| AC-009 | When `drug_exposure_end_datetime` is non-null, `drug_exposure_end_datetime >= drug_exposure_start_datetime` | BL-004 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |

## Registry entry

None. `clinical__` models are canonical clinical facts, not indicators or derived
elements — only `metric__` / `derived__` artefacts get a `metric_definitions.csv` row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `prescriptions` | `bases/` | Prescription drug, prescriber, dose/route, dates, discontinuation (prescription branch) |
| `encounter_prescriptions` | `bases/` | Links a prescription to its encounter (person + visit); its own `id` is the prescription branch's `drug_exposure_id` (BL-006) |
| `reference_data` | `bases/` | Drug code + name (`type = 'drug'`) for prescription / dispense branches |
| `vaccine_administrations` | `bases/` | Vaccine event, status, `vaccine_name`, encounter, vaccinator (vaccination branch) |
| `vaccine_schedules` | `bases/` | Resolves `scheduled_vaccine_id` to `reference_data.id` (vaccination branch's code) |
| `medication_dispenses` | `bases/` | Dispensed quantity, datetime, dispenser (dispense branch) |
| `pharmacy_order_prescriptions` | `bases/` | Links a dispense to its pharmacy order and originating prescription |
| `pharmacy_orders` | `bases/` | Dispense encounter anchor |
| `encounters` | `bases/` | Person (`patient_id`) via the source `encounter_id` |
| `clinical__person` | `clinical/` | `person_id` FK target (AC-003) |
| `clinical__visit_occurrence` | `clinical/` | `visit_occurrence_id` FK target (AC-004) |
| `ref__provider` | `ref/` | `provider_id` FK target (AC-005) |

## Open questions

- **OQ-1:** `drug_concept_id` (RxNorm), the vaccine CVX concept, `route_concept_id`, and
  `drug_type_concept_id` await a drug/vaccine map (D2) / the `vocab__` layer. Source
  code/name are retained so the standard concepts can be layered on without reshaping.
- **OQ-2:** `days_supply` and OMOP `drug_era` (collapsing prescriptions + dispenses into
  continuous exposure eras) are out of scope for this canonical fact. Because prescriptions
  and dispenses are both emitted (type-discriminated), a consumer counting exposures must
  filter by `drug_exposure_type_source_value` to avoid counting the same medication twice —
  to revisit if an era model is needed.

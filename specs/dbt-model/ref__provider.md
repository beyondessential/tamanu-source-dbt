# dbt Model Spec: `ref__provider` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `ref__provider` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `ref` |
| **Materialisation** | `view` (always — OMOP health-system wrapper) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-03 |
| **Last updated** | 2026-07-03 |

OMOP `PROVIDER` wrapper over Tamanu `users` — the clinicians/examiners recorded against
encounters and events. Gives `clinical__` models a stable, OMOP-named FK target for
`provider_id`, completing the `ref__` health-system trio alongside `ref__location` and
`ref__care_site`. See
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (`ref__` layer,
`ref__provider` → OMOP `PROVIDER`),
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (native UUID PK),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

## Purpose

**What this artefact represents.** One row per Tamanu `user`, wrapped in OMOP `PROVIDER`
column naming. In Tamanu the `examiner_id` on an encounter (and `clinician_id` on encounter
history) is a `users` row; `provider_id` across the clinical layer resolves here.

**Why a wrapper.** `clinical__visit_occurrence`, `clinical__visit_detail`, and future event
tables all carry `provider_id`. Wrapping `bases/users` in OMOP naming gives them a typed,
validated FK target (`provider_id`) instead of a raw UUID, keeping the layer contract
intact and portable across OMOP tooling (D2).

**Who reads it.** `clinical__visit_occurrence` (`provider_id` FK → attending clinician);
`clinical__visit_detail` (`provider_id` FK → per-segment clinician); future event tables
(`clinical__condition_occurrence`, `clinical__measurement`, …) that carry `provider_id`.

## Grain

**One row per:** user. Soft-deleted users are already filtered by `bases/users`.
`users.id` is the PK of the source table. This model is a thin projection over
`bases/users` with **no joins**, so there is no fan-out risk. In particular
`user_designations` (a user↔designation many-to-many) is deliberately **not** joined —
doing so would multiply rows per user (see BL-004).

## Output schema

| Column | Type | Notes |
|---|---|---|
| `provider_id` | uuid | `users.id`. Native UUID PK — no remap to OMOP integer IDs (D1). OMOP `PROVIDER.provider_id` |
| `provider_name` | text | `users.display_name`. OMOP `PROVIDER.provider_name` |
| `provider_source_value` | text | `users.display_id` (the business identifier). OMOP `PROVIDER.provider_source_value` |
| `role` | text | `users.role` — the Tamanu account role (e.g. practitioner, admin). Single-valued; carried to distinguish clinical from non-clinical users |

The remaining OMOP `PROVIDER` columns are omitted:
- `specialty_concept_id` / `specialty_source_value` — a user's clinical designations live in
  `user_designations`, a **many-to-many** (a user can hold several). There is no single
  specialty to place in one column without fanning out the grain, so specialty is deferred
  (BL-004). `role` is retained as the nearest single-valued signal.
- `care_site_id` — Tamanu users are not assigned a single primary care site (they work
  across departments), so there is no clean value to populate.
- `gender_concept_id` / `year_of_birth` — not recorded on the `users` record (these belong
  to patients, not staff).

## Business logic

- **BL-001:** One row per user, sourced from `{{ ref('users') }}` only (D10) — never
  `public.*`. Soft-delete filtering is inherited from the base model. No joins, so grain
  is `users.id` verbatim.
- **BL-002:** OMOP column naming is applied — `users.id → provider_id`,
  `users.display_name → provider_name`, `users.display_id → provider_source_value`. Native
  UUID PK (D1); the local identifier is retained as the source value, never replaced.
- **BL-003:** `role` (`users.role`) is carried as a single-valued attribute so consumers
  can distinguish clinicians from non-clinical accounts without joining another table.
- **BL-004:** Specialty, care site, and demographics are **not** emitted. Clinical
  designations are a user↔designation many-to-many (`user_designations`) with no single
  value per provider; users have no single primary care site; and DOB/gender are not on
  the user record. Columns are added only when a real, single value backs them (the
  `ref__location` / `ref__care_site` precedent); revisit specialty via a
  `user_designations` aggregation or a `map__omop_specialty` when a consumer needs it.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `provider_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `provider_id` is `unique` (one row per user) | grain | dbt `unique` |

## Registry entry

None. `ref__` models are OMOP health-system wrappers, not indicators or derived
elements (only `metric__` / `derived__` get a `metric_definitions.csv` row).

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `users` | `bases/` | Clinician/user identity (id, display_id, display_name, role) |

## Consumers

| Model | Use |
|---|---|
| `clinical__visit_occurrence` | `provider_id` FK → attending clinician (AC-009 there) |
| `clinical__visit_detail` | `provider_id` FK → per-segment clinician (AC-010 there) |
| (future) event tables | `provider_id` FK on condition/measurement/observation/drug domains |

## Open questions

- **OQ-1:** Specialty (`specialty_source_value` / `specialty_concept_id`) is deferred
  pending a rule for collapsing the `user_designations` many-to-many to one value per
  provider (e.g. a primary-designation flag or a `map__omop_specialty`).

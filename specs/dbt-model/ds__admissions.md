# Dataset Spec: `ds__admissions`

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__admissions`, `ds__sensitive_admissions` |
| **Macro** | `admissions_dataset(is_sensitive=false)` (`macros/datasets/admissions.sql`) |
| **Type** | Consumer-shaped dataset (`ds__`) |
| **Layer** | `ds__` |
| **Materialisation** | env-aware (view in the production bundle) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-03 |
| **Consumed by** | `admissions-line-list` report (`macros/reports/admissions_line_list.sql`) |

## Purpose

One wide row per admission encounter: the patient, the admitting clinician, and the
encounter's movement history and diagnoses flattened into parallel arrays and
delimited strings, so a consumer reads a single definition rather than re-deriving the
history consolidation.

## Grain

One row per `admission` encounter in the requested sensitivity partition. Every
admission encounter appears, including one with no qualifying history rows (BL-002) and
one with no diagnoses — the movement, clinician and diagnosis columns are then null.

## Inputs

`encounters_core()` for scope (see `specs/dbt-model/encounters_core.md`), then
`ref('encounter_history')`, `ref('users')`, `ref('departments')`, `ref('locations')`,
`ref('location_groups')`, `ref('patients')`, `ref('reference_data')` and
`ref('encounter_diagnoses')`.

| Argument | Purpose |
|---|---|
| `is_sensitive` | Facility partition, passed straight to `encounters_core()`. `false` = non-sensitive facilities only |

## Output schema

Patient: `patient_id`, `display_id`, `first_name`, `last_name`, `date_of_birth`, `age`,
`sex`, `village_id`, `village`, `billing_type_id`, `billing_type`.

Admission: `admitting_clinician_id`, `admitting_clinician`, `admission_datetime`,
`admission_status`, `discharge_datetime`, `facility_id`, `facility`.

Movement history, as three parallel triples — an id array, a comma-joined name string
and a semicolon-joined datetime string: `department_ids` / `departments` /
`department_datetimes`, `location_group_ids` / `location_groups` /
`location_group_datetimes`, `location_ids` / `locations` / `location_datetimes`.

Diagnoses: `primary_diagnoses`, `primary_diagnoses_codes`, `secondary_diagnoses`,
`secondary_diagnoses_codes`.

## Business logic

- **BL-001:** Scope and the sensitivity partition come from
  `encounters_core(is_sensitive=..., encounter_type='admission')`, aliased back to this
  dataset's own column names. `localise_timestamps` is deliberately left off — see
  BL-010.
- **BL-002:** The history consolidation is **left**-joined from the encounter, narrowed
  at join time to that encounter's `admission`-type history rows whose `change_type` is
  null (the creation row) or intersects
  `{encounter_type, examiner, department, location}`. Narrowing at join time rather than
  in a later `where` is what lets the `lag()` and `row_number()` windows see only
  relevant rows; the left join is what keeps an admission with no such rows in the
  output.
- **BL-003:** The admitting clinician is the first clinician by history datetime,
  except on a **transfer** — an encounter carrying at least one history row whose
  `change_type` includes `encounter_type` — where it is the second clinician, when one
  exists. Only the creation row and `examiner` rows count as clinician changes. (The
  `encounter_type_change_sequence = 1` term in the code adds nothing: that sequence is
  partitioned on the same condition it is then compared against, so the earliest
  qualifying row always has sequence 1.)
- **BL-004:** The department aggregates cover history rows whose `change_type` is null or
  intersects `{encounter_type, department}`, in datetime order, with no deduplication.
- **BL-005:** The location aggregates cover history rows whose `change_type` is null or
  intersects `{encounter_type, location}`, in datetime order, with no deduplication.
- **BL-006:** The location-group aggregates cover the creation row unconditionally,
  plus each change row of BL-005 whose
  `location_group_id is distinct from prev_location_group_id` — `prev` being the previous
  row's group by datetime within the encounter. Two properties matter and they are
  separable. **The creation row bypasses the dedup**, so an admission always contributes
  its admitting group, ungrouped or not. **`is distinct from`** is used rather than
  `!= ... or prev is null`, so a move **into** an ungrouped location counts as a change
  and is kept, while a move between two ungrouped locations does not. Together these give
  `encounter_summary_core` the same row set for the same history; a flat dedup predicate
  gated on `is distinct from` alone would satisfy the second and silently break the
  first, dropping the creation row of an encounter that is ungrouped throughout.
- **BL-007:** Diagnoses are split by `is_primary` into name-with-code and code-only
  strings, in diagnosis datetime order. `certainty not in ('disproven', 'error')` is
  applied here as well as in the `encounter_diagnoses` base model, so it is redundant at
  run time; it is not safe to remove while any unit test stubs that base, because a stub
  replaces the base model including its filters.
- **BL-008:** `age` is completed years between `admission_datetime` (BL-003) and the
  patient's date of birth, so it is the age at admission and does not drift. It is null
  where `admission_datetime` is (BL-002).
- **BL-009:** `admission_status` is `active` where the encounter has no `end_datetime`
  and `discharged` otherwise; `discharge_datetime` is the `end_datetime` itself.
- **BL-010:** No output is timezone-shifted. A dataset must not carry the `:timezone`
  bind placeholder, because datasets build on analytics where `parameter()` and
  `to_user_selected_timezone()` do not resolve to a viewer's choice. The datetime strings
  use `var('datetime_without_seconds_format')` only.

## Acceptance criteria

| ID | Criterion | Clause | Asserted by |
|---|---|---|---|
| AC-001 | An admission moving from a grouped location into an ungrouped one emits both entries. | BL-006 | `test_ds__admissions_location_group_null_dedup` (enc_A) |
| AC-002 | An admission ungrouped throughout emits no location-group entries, so the columns are null. | BL-006 | `test_ds__admissions_location_group_null_dedup` (enc_B) |
| AC-003 | Two consecutive locations sharing one group collapse to a single location-group entry. | BL-006 | `test_ds__admissions_location_group_null_dedup` (enc_C) |
| AC-004 | Only `admission` encounters appear. | BL-001 | `test_ds__admissions_filters_admission_encounters_only` |
| AC-005 | With `is_sensitive = false` no sensitive facility's admission appears, and vice versa. | BL-001 | `test_ds__admissions_sensitive_facilities` |
| AC-006 | `age` is the age at admission. | BL-008 | `test_ds__admissions_age_calculation` |

## Open questions

- **OQ-001** *(owner: Maui team; due: before the next behavioural change to this
  dataset)* — the three movement-history columns of a triple are built by separate
  aggregates over the same rows, but `string_agg` skips null names while `array_agg`
  keeps null ids, so a kept row with an ungrouped location leaves
  `location_group_datetimes` and `location_group_ids` one element longer than
  `location_groups`. A consumer reading the three positionally will misalign them. This
  predates BL-006 — the previous predicate misaligned the same way on a first row with a
  null group — so BL-006 changes which encounters are affected, not whether the defect
  exists. Fixing it means choosing between emitting a placeholder name and excluding
  ungrouped rows outright, and either is a further output change.

## Change log

| Date | Change |
|---|---|
| 2026-09-03 | Location-group dedup aligned to `is distinct from` (BL-006), resolving OQ-002 of `specs/reports/encounter-summary.md`. Spec created. |

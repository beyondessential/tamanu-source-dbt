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

**The row describes the admission phase of the encounter, not the whole encounter**
(BL-002). In OMOP-lite terms the population is chosen at `clinical__visit_occurrence`
grain — which encounters are admissions — while every datetime, clinician and movement
column is reported at `clinical__visit_detail` grain, over the segments whose
`encounter_type` is `admission`. `encounter_summary` answers the whole-encounter question
for the same encounter, so the two legitimately disagree; see *Relationship to
`encounter_summary_core`*.

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

  The `encounter_type = 'admission'` half of that predicate is **the decision that this
  dataset reports the admission phase**, and it is deliberate. A history snapshot records
  the encounter's state *after* an edit, so an encounter admitted from an outpatient
  presentation carries earlier rows stamped `outpatient`; this predicate discards them.
  An admission therefore **dates from conversion, not from presentation** — the clinical
  event the report is about is the admission, and a patient who waited in outpatients
  before being admitted was not an inpatient for that time. The consequences are
  consistent rather than incidental: `admission_datetime`, `age` (BL-008), the admitting
  clinician (BL-003) and the first entry of each movement triple (BL-004, BL-005,
  BL-006) all describe the moment of admission. Reversing the choice would mean removing
  this predicate, and every one of those columns would change with it.
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
  and is kept, while a move between two ungrouped locations does not. A kept row whose group is null is **named**
  `(no area)` rather than skipped: `array_agg` keeps a null id while `string_agg` drops
  a null name, so without it the id and datetime columns of the triple run longer than
  the names, and a consumer reading them positionally pairs a ward with another move's
  timestamp. Together these give
  `encounter_summary_core` the same row set for the same history; a flat dedup predicate
  gated on `is distinct from` alone would satisfy the second and silently break the
  first, dropping the creation row of an encounter that is ungrouped throughout.
- **BL-007:** Diagnoses are split by `is_primary` into name-with-code and code-only
  strings, in diagnosis datetime order. `certainty not in ('disproven', 'error')` is
  applied here as well as in the `encounter_diagnoses` base model, so it is redundant at
  run time; it is not safe to remove while any unit test stubs that base, because a stub
  replaces the base model including its filters.
- **BL-008:** `age` is completed years between `admission_datetime` (BL-003) and the
  patient's date of birth, so it is the age at admission — at conversion, per BL-002 —
  and does not drift. It is null where `admission_datetime` is (BL-002).
- **BL-009:** `admission_status` is `active` where the encounter has no `end_datetime`
  and `discharged` otherwise; `discharge_datetime` is the `end_datetime` itself.
- **BL-010:** No output is timezone-shifted. A dataset must not carry the `:timezone`
  bind placeholder, because datasets build on analytics where `parameter()` and
  `to_user_selected_timezone()` do not resolve to a viewer's choice. The datetime strings
  use `var('datetime_without_seconds_format')` only.

## Relationship to `encounter_summary_core`

Both this dataset and `encounter_summary_core` open with a CTE named
`encounter_history_consolidated` that resolves an encounter's history rows against
`departments`, `locations`, `location_groups` and `users`, and adds a `row_number()` and
a `lag()` over the same partition. **They are deliberately not merged into a shared
macro.** They share a shape, not a definition; seven differences are load-bearing, and
parameterising all of them would need more arguments than the ~38 shared lines are
worth. Per the reuse decision rule this is the "not the same thing" outcome, so the
divergences are enumerated here instead.

| | Difference | `encounter_summary_core` | This dataset |
|---|---|---|---|
| D1 | Drive direction | history-driven, inner join to the scope | scope-driven, **left** join to history |
| D2 | History scope | every row of the encounter — whole-encounter grain | only `admission`-phase rows — phase grain, BL-002 |
| D3 | Dimension joins | inner to `departments` and `locations` | left to both |
| D4 | Which actor | `updated_by_id` (source `actor_id`) → `encountering_clinician` | `clinician_id` (source `examiner_id`) → `admitting_clinician` |
| D5 | `row_number()` | `partition by encounter_id, change_type` → `change_sequence` | `partition by encounter_id, ('encounter_type' = any(change_type))` → `encounter_type_change_sequence` |
| D6 | `change_type` narrowing | none | `is null or && {encounter_type, examiner, department, location}` |
| D7 | Projection | selects `encounter_type`, for the `encounter_type_*` aggregates | does not |

Three of these are worth expanding, because they are the ones a merge attempt would get
wrong quietly:

- **D2 is the deliberate one, and the others follow from it.** The two models answer
  different questions about the same encounter: `encounter_summary` describes the
  encounter as a whole, this dataset describes its admission phase. An encounter admitted
  from an outpatient presentation therefore has two different — and both correct — start
  datetimes across the two models. This is settled (BL-002), not drift to be reconciled.
- **D1 and D3 are consequences of D2.** The `encounter_type` filter can eliminate every
  history row an encounter has, so the left join to history is what keeps the encounter
  in the output at all, and the left joins to the dimensions are what stop an all-null
  `eh` from dropping it again. Changing any one of the three in isolation changes the
  grain.
- **D4 is two different people.** `bases/encounter_history` exposes both `actor_id` (who
  made the edit) and `examiner_id` (the clinician on the encounter) under different
  names. Neither column is redundant and neither model wants the other's.
- **D5 is not drift.** The two `row_number()`s derive different columns for different
  purposes — BL-003 here, the creation-row pick in the core — and both would have to
  survive a merge under distinct names.

**D6 is currently inert.** The Tamanu application writes `change_type` as an array
containing only the four `EncounterChangeType` values — `location`, `encounter_type`,
`department`, `examiner` — or NULL on the creation snapshot, and writes no history row at
all when an edit touches none of those four columns. Every non-null `change_type` is
therefore a non-empty subset of exactly the set D6 tests for overlap against, so the
predicate excludes nothing. It defends against values older or newer versions might
write, not against anything present today.

One consequence of the application's write model applies to both consolidations and is
easy to misread: a single edit changing several of the four columns produces **one**
history row whose `change_type` holds several values, and the snapshot records the
values moved *to*, not from. Every predicate over `change_type` in either model is
therefore an array-membership or array-overlap test rather than an equality test. The
core's `change_sequence` is the exception — it partitions by the whole array value, so
`{location}` and `{location,department}` are separate partitions. That is harmless while
its only consumer filters on `change_type is null`, where every creation row shares one
partition, but it does not mean what its name suggests.

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

None outstanding.

## Change log

| Date | Change |
|---|---|
| 2026-09-03 | Location-group dedup aligned to `is distinct from` (BL-006), matching `encounter_summary_core`. Spec created. |
| 2026-09-05 | An ungrouped move is named `(no area)` in `location_groups` (BL-006), so the three movement columns of a triple stay the same length. |
| 2026-09-04 | Recorded that the two history consolidations are deliberately not merged. Decided that an admission dates from **conversion**, not presentation, making the phase scope in BL-002 a decision rather than an open question. No code change. |

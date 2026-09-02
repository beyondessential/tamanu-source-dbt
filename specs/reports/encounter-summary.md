# Report Spec: `encounter-summary`

## Identity

| Field | Value |
|---|---|
| **Name** | `encounter-summary-by-start-date`, `encounter-summary-by-end-date` (+ sensitive twins) |
| **Macros** | `encounter_summary_report(date_field, is_sensitive)` — presentation; `encounter_summary_core(date_field, is_sensitive)` — resolution |
| **Type** | Tamanu report (reporting schema) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Version branch** | `2.54` (origin; forward-ported upward) |
| **Created** | 2026-09-02 |

One row per encounter, with the patient, the encounter's movement history, and its
clinical aggregates flattened into a single wide row.

## Purpose

The report body was a single 519-line macro with 13 CTEs. A deployment repo needing extra
columns — Aspen joining `patient_birth_data` is the live case — had no option but to fork
the whole body, which then drifts from the standard report with nothing in CI to catch it.

Splitting resolution from presentation lets a deployment repo call
`encounter_summary_core()` and write its own projection, adding joins, instead of forking.
Per the reuse decision rule in `.maui/knowledge/standards/dbt-conventions.md` this is
mechanism 4 (shared core macro) on the "there is no shared model and none is wanted"
branch.

**Why not a `ds__encounter_summary` dataset.** The date range is applied in the scope CTE,
*before* eight grouped CTEs that each join it. A dataset view filtered from outside would
put the range on a join-derived column, which Postgres will not push into those grouped
subqueries, so every aggregate would be computed over the full encounter history on each
run — the BL-030 failure mode of `audit-outpatient-appointments`, eight times over.

This mirrors how `outpatient_appointments_audit_core` was piloted: originate on the
version branch that needs it (that one landed at 2.54 and above, not 2.52), then
forward-port upward.

## Grain

One row per encounter in the requested sensitivity partition whose `date_field` falls in
the report window. `date_field` is `start_datetime` or `end_datetime`; the `end_datetime`
variant additionally requires a non-null `end_datetime`, so open encounters are absent.

## The core's output contract

`encounter_summary_core()` emits **resolved but unformatted** values: naive timestamps,
durations as their component timestamps, aggregates as arrays or text. Every caller
applies its own `translate_label` / `to_char` / timezone shift.

- **BL-001:** `encounter_id` and `patient_id` are emitted first and deliberately. They are
  the join keys an extending caller needs, and the *formatted* report output exposes
  neither — its only identifier is the patient `display_id`, which is patient-grain and so
  fans out across a patient's encounters. Without these, extending the report by joining
  encounter-scoped data is not possible.
- **BL-002:** The projection emits nothing that depends on `flags.WHICH` — no `to_char`, no
  `to_user_selected_timezone`. That helper renders a `:timezone` bind placeholder under
  `dbt compile` and is a plain no-op otherwise, so emitting it unconditionally would both
  carry a placeholder into any compiled artefact and hand a non-report caller columns
  silently identical to the raw ones.
- **BL-003:** `order by` is deliberately absent. A caller wraps the core in a subquery,
  where ordering is not guaranteed to survive, so each caller applies its own.
- **BL-004:** `department_ids` and `location_group_ids` are emitted because the outer
  `departmentId` / `locationGroupId` filters test membership of arrays produced *by* the
  aggregation, so they cannot be applied before it. An extending caller filtering the same
  way needs them.
- **BL-005:** The `parameter()` filters in the scope CTE and the outer `where` stay in the
  core, which is why it lives under `macros/reports/` rather than beside a dataset.

## Division and sub-division

This change also adds `Division` and `Sub-division` to the report, resolved from
`patient_additional_data.division_id` / `subdivision_id` via `reference_data`. Both
translation strings (`patientDivision`, `patientSubDivision`) and both base-model columns
already existed on this branch, so no upstream work was required.

They are placed in the projection after `Billing type` and in the join graph after `bt`,
matching where the higher version branches already have them, so the forward-port is a
no-op on those lines.

The report `notes` in the four configs are unchanged: they enumerate encounter-level
information and do not list patient demographics (ethnicity, billing type and village are
likewise absent).

## Known defects, deliberately preserved

The extraction is behaviour-preserving, so it carries these forward unchanged. Both are
pre-existing on every version branch, not introduced here.

- **OQ-001 (B-D1):** `encounter_history.actor_id` is nullable at source — it has no
  `not_null` test, unlike `department_id`, `location_id` and `examiner_id` — but the
  consolidation inner-joins `users` on it. A null-actor history row is dropped, and where
  *every* history row for an encounter has a null actor, the inner join to
  `encounter_changes` drops the encounter from the report entirely. `admissions_dataset`
  never joins users-as-actor and so is unaffected.
- **OQ-002 (B-D3):** The location-group dedup uses `is distinct from`, while
  `admissions_dataset` uses `!= or prev is null`. They disagree on two null cases: a first
  row with a null group, and a transition *into* a null group. Affects
  `location_group_datetimes` / `_ids` / `_groups` and `discharge_location_group_datetime`.

Fixing either changes report output, so each needs its own change with a row-level diff
and sign-off — not a refactor. Note for deployment upgrades: if these land before a
version cut, that upgrade will change encounter summary output, and encounters that
currently do not appear will start appearing.

## Acceptance criteria

| ID | Criterion | Clause |
|---|---|---|
| AC-001 | Extracting the core changes no report output beyond the two added columns. | BL-002, BL-003 |
| AC-002 | The core emits `encounter_id` and `patient_id`, so a caller can join encounter- and patient-grain data. | BL-001 |
| AC-003 | Compiling the report yields no `:` bind placeholder from the core's projection. | BL-002 |
| AC-004 | `Division` and `Sub-division` appear in all four report models. | — |

### Verification (2026-09-02)

Both compiled variants were run pre- and post-extraction against a populated
`reporting_release` database, date range widened to `[2000-01-01, 2100-01-01]` and every
optional filter null, and compared with `except all` in both directions. The two new
columns were removed from the comparison by casting each row to `jsonb` and dropping those
keys, so the check is on pre-existing output only.

| Model | Rows before | Rows after | Only in before | Only in after |
|---|---|---|---|---|
| `encounter-summary-by-start-date` | 687 | 687 | 0 | 0 |
| `encounter-summary-by-end-date` | 686 | 686 | 0 | 0 |
| `sensitive-encounter-summary-by-start-date` | 0 | 0 | 0 | 0 |
| `sensitive-encounter-summary-by-end-date` | 0 | 0 | 0 | 0 |

AC-001 holds for the standard variants on 1373 real rows. **The sensitive comparison is
vacuous** — every facility in that database has `is_sensitive = false`, so both sides
legitimately return zero rows. The sensitive path rests on
`test_encounter_summary_by_start_date_excludes_sensitive_facilities` and on the extraction
being structurally identical, not on real data.

Also: 60/60 unit tests pass, and `sqlfluff lint` is clean on all four report models. The
seven `encounter_summary` fixtures required the two new columns in both their
`patient_additional_data` stub and their `expect` block.

## Change log

| Date | Change |
|---|---|
| 2026-09-02 | Split `encounter_summary_report` into a resolution core and a presentation wrapper (519 to 89 lines, plus a 533-line core); added Division and Sub-division. |

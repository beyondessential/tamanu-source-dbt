# dbt Macro Spec: `encounters_in_scope` (shared core)

## Identity

| Field | Value |
|---|---|
| **Name** | `encounters_in_scope` |
| **Type** | shared macro (no model of its own) |
| **Layer** | cross-layer — `macros/encounters_in_scope.sql` |
| **Materialisation** | n/a — inlined into each caller |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-02 |
| **Last updated** | 2026-09-02 |

Encounters resolved to their facility and partitioned by sensitivity — the
`encounters -> locations -> facilities` join with `f.is_sensitive`, which is the most
repeated block in the repo.

## Purpose

Three macros carried their own byte-for-byte copy of this join and its `is_sensitive`
predicate: `encounter_invoice_audit_report`, `encounter_summary_report` and
`admissions_dataset`. A miss in any one copy silently widens or narrows the facility
partition for that surface alone, and nothing in CI would catch it.

Per the reuse decision rule in `.maui/knowledge/standards/dbt-conventions.md`, this is
mechanism 4 (shared core macro) on the "there is no shared model and none is wanted"
branch: the callers span the dataset and report layers, and two of them need the scope
rows filtered *before* the aggregate CTEs that consume them, so a `ds__` view boundary
would not serve.

## Grain

One row per encounter that resolves to a facility in the requested sensitivity
partition, after any caller-supplied narrowing. Never more than one row per encounter —
both joins are on primary keys.

## Inputs

### Arguments

| Argument | Default | Purpose |
|---|---|---|
| `is_sensitive` | `false` | Facility partition. `false` = non-sensitive facilities only. |
| `encounter_type` | `none` | Optional. Restricts to a single `encounter_type` (e.g. `'admission'`). |
| `extra_predicates` | `none` | Optional SQL text appended to the `where` clause. |

### Upstream models

- `ref('encounters')`
- `ref('locations')`
- `ref('facilities')`

## Output schema

| Column | Notes |
|---|---|
| `encounter_id` | `e.id`, renamed |
| `patient_id` | |
| `encounter_type` | |
| `reason_for_encounter` | |
| `start_datetime` | raw, naive |
| `end_datetime` | raw, naive |
| `start_datetime_local` | `start_datetime` in the viewer's selected timezone |
| `end_datetime_local` | `end_datetime` in the viewer's selected timezone |
| `location_id` | |
| `department_id` | |
| `clinician_id` | `e.examiner_id`, renamed by the base model |
| `patient_billing_type_id` | |
| `facility_id` | `f.id`, renamed |
| `facility` | `f.name`, renamed |

The projection is a deliberate **superset** of what any single caller needs, so each
caller keeps its existing downstream column names and each adoption is a
shape-only compiled diff. Emitting both the raw and localised timestamps costs
nothing — the shift is a per-row expression, not an extra scan.

## Business logic

- **BL-001:** Facility scope is partitioned by the `is_sensitive` argument: the join to
  `facilities` carries `and f.is_sensitive = <argument>`, so a caller passing `false`
  sees only non-sensitive facilities and one passing `true` sees only sensitive ones.
- **BL-002:** The test patient is excluded upstream by the `encounters` base model and
  is deliberately **not** re-applied here. Re-applying it would imply the base model's
  guarantee is untrusted, and the two would then have to be kept in step.
- **BL-003:** Alias contract. `extra_predicates` is raw SQL spliced into this macro's
  own `where` clause, so it may reference exactly the aliases `e` (encounters), `l`
  (locations) and `f` (facilities). Nothing else is in scope. These aliases must not be
  renamed without updating every caller — there is no way for the compiler to catch a
  break.
- **BL-004:** `extra_predicates` is **row-selecting only**. It narrows which encounters
  are returned and nothing else. This macro contains no window function or aggregate,
  so a caller's predicate cannot change the value of any emitted column — only which
  rows survive. A future change that introduces a window function here would invalidate
  this clause and must be treated as behaviour-changing for every caller.
- **BL-005:** This macro contains no `parameter()` call. Datasets build on analytics
  targets, where `parameter()` falls through to a `var()` literal rather than a bind
  placeholder; a filter baked in here would therefore behave differently for dataset
  and report callers. Report-only filters live in `encounter_scope_common_filters()`
  instead.
- **BL-006:** `locations` and `facilities` are **inner** joins, so an encounter whose
  `location_id` is null or dangling produces no row at all. This matches what all three
  original copies did, and is what makes the facility partition total: an encounter that
  cannot be resolved to a facility cannot be assigned to either partition.

## Companion macro

`encounter_scope_common_filters()` (`macros/reports/encounter_scope_filters.sql`) emits
the three optional-id filters — facility, patient billing type, supervising clinician —
that the encounter-scoped reports applied identically. It is predicate text for
`extra_predicates` and obeys the same alias contract (BL-003). It is **report-only**
because it calls `parameter()`; see BL-005.

Date ranges and report-specific flags are deliberately excluded from it: they genuinely
differ between callers. `encounter_summary` filters on a caller-chosen `date_field`,
while `encounter_invoice_audit` filters on `start_datetime` and carries
`includeOpenEncounters`.

## Acceptance criteria

| ID | Criterion | Clause |
|---|---|---|
| AC-001 | With `is_sensitive=false`, no row resolves to a facility with `is_sensitive = true`, and vice versa. | BL-001 |
| AC-002 | No row has `patient_id = var('test_patient')`, despite the macro not filtering it. | BL-002 |
| AC-003 | Adopting the macro at a call site produces a compiled-SQL diff that is shape-only plus the superset columns — no changed join keyword, predicate or column expression. | BL-003, BL-004 |
| AC-004 | `grep -c "parameter(" macros/encounters_in_scope.sql` returns 0. | BL-005 |
| AC-005 | An encounter whose `location_id` does not resolve to a location produces no row. | BL-006 |

AC-001 and AC-003 are covered for the `encounter_invoice_audit` call site by
`test_encounter_invoice_audit_aggregation` and
`test_encounter_invoice_audit_cancelled_invoice_products`, which stub `ref('encounters')`,
`ref('locations')` and `ref('facilities')` directly and so exercise this macro
end-to-end. AC-003 was verified for that adoption by a full-project compiled diff: 2 of
2952 compiled models changed, both intended, and both token-identical apart from the
superset columns and one redundant wrapping paren.

## Callers

| Caller | Adopted | Notes |
|---|---|---|
| `encounter_invoice_audit_report` | yes | First adoption — the only call site with unit-test coverage. |
| `admissions_dataset` | not yet | Will pass `encounter_type='admission'` and alias `encounter_id` back to `id`, `facility` to `facility_name`. |
| `encounter_summary_report` | not yet | Will pass a `date_field`-driven range. |

## Open questions

- **OQ-001:** `admissions_dataset` currently applies no `patient_id != test_patient`
  predicate and no date range, so its adoption should be a pure substitution. Confirm
  against the compiled diff when PR-3 lands.

## Change log

| Date | Change |
|---|---|
| 2026-09-02 | Created. Extracted from `encounter_invoice_audit_report`; adopted there first. |

# dbt Macro Spec: `encounters_core` (shared core)

## Identity

| Field | Value |
|---|---|
| **Name** | `encounters_core` |
| **Type** | shared macro (no model of its own) |
| **Layer** | cross-layer — `macros/encounters_core.sql` |
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

This macro is the single definition of the `encounters -> locations -> facilities` join
and its `is_sensitive` predicate. Its callers span the dataset and report layers, so a
divergence between copies would silently widen or narrow the facility partition for one
surface alone, and nothing in CI would catch it.

### Naming

The macro is `encounters_core`; the CTE at each call site is `encounters_in_scope`. The
two names carry different jobs — the CTE says what the rows *are* at that point in the
query, the macro says what the shared logic *is* — and naming both the same reads as a
tautology that hides which half is the macro.

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
| `localise_timestamps` | `false` | Report-only. Adds `start_datetime_local` / `end_datetime_local`. A dataset caller must leave it off — see BL-005. |

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
shape-only compiled diff. Emitting both the raw and localised timestamps adds no scan —
the shift is a per-row expression. The superset columns are not entirely free, though:
where a caller references the CTE more than once (as `encounter_invoice_audit` does, in
`invoice_data` and again in the final select) Postgres 12+ materialises it, so the extra
columns are materialised for every in-scope row even though that caller never reads them.
Small against a bounded date range, and the price of keeping each adoption a shape-only
diff, but it is a real cost rather than none.

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
- **BL-004:** `extra_predicates` is **row-selecting only**, in a narrower sense than the
  reuse convention uses that term. The convention's row-selecting parameters are pushdown
  optimisations whose caller re-applies the same predicate as an outer safety net, so
  correctness never depends on the early filter being exact (BL-030 of
  `audit-outpatient-appointments`). That does **not** apply here: `extra_predicates` is the
  *only* place the caller's date range and optional filters are applied, so correctness does
  depend on it being exact. What the term means here is the other half of the property:
  the predicate narrows which encounters are returned and nothing else. This macro
  contains no window function or aggregate, so a caller's predicate cannot change the
  value of any emitted column — only which rows survive. A future change that introduces
  a window function here would invalidate this clause and must be treated as
  behaviour-changing for every caller.
- **BL-005:** This macro emits **no report-only construct by default** — nothing that
  renders a bind placeholder under `dbt compile`. Two things would break that, and both
  are kept out of the default path:
    - `parameter()` is not called at all. Report-only filters live in
      `encounter_scope_common_filters()` instead.
    - `to_user_selected_timezone()` is called **only** under `localise_timestamps`,
      which defaults to false. That helper emits `(... at time zone coalesce(nullif(
      :timezone, ''), ...))` under `dbt compile` and is a plain **no-op** otherwise
      (`macros/datetime.sql`). Both halves are hazards for a dataset caller: the compile
      form carries `:timezone` into the reporting bundle, where
      `generate_reporting_schema_script()` wraps compiled SQL verbatim in
      `create or replace view` — invalid Postgres; and the run form would give a dataset
      `*_local` columns silently identical to the raw ones, which is a misleading name
      rather than an error.
  The rule this generalises to: **a shared macro reachable from a dataset must not emit
  anything that depends on `flags.WHICH`.** Grepping for `parameter(` alone does not
  establish that — the hazard here arrived through a helper.
- **BL-006:** `locations` and `facilities` are **inner** joins, so an encounter whose
  `location_id` is null or dangling produces no row at all. This matches what all three
  original copies did, and is what makes the facility partition total: an encounter that
  cannot be resolved to a facility cannot be assigned to either partition.

## Companion macro

`encounter_scope_common_filters()` (`macros/reports/encounter_scope_common_filters.sql`) emits
the three optional-id filters — facility, patient billing type, supervising clinician —
that the encounter-scoped reports applied identically. It is predicate text for
`extra_predicates` and obeys the same alias contract (BL-003). It is **report-only**
because it calls `parameter()`; see BL-005.

Date ranges and report-specific flags are deliberately excluded from it: they genuinely
differ between callers. `encounter_summary` filters on a caller-chosen `date_field`,
while `encounter_invoice_audit` filters on `start_datetime` and carries
`includeOpenEncounters`.

### Anchoring note

BL-001, BL-002 and BL-006 are anchored as `-- BL-00N:` comments at their implementation
sites in `macros/encounters_core.sql`. BL-003, BL-004 and BL-005 are **contract
clauses with no single code site** — they constrain what a caller may pass and what this
macro may contain, so there is nothing to anchor them to; the macro header states them in
prose. They are recorded here as configuration-only for the same reason BL-038 of
`audit-outpatient-appointments` is. Note that `encounter_invoice_audit.sql` declares its
*own* BL-002/003/004 with unrelated meanings, which is exactly why the macro header names
this spec file (`See specs/dbt-model/encounters_core.md ...`) in the file-level form
maui-team#104 introduced.

## Acceptance criteria

| ID | Criterion | Clause |
|---|---|---|
| AC-001 | With `is_sensitive=false`, no row resolves to a facility with `is_sensitive = true`, and vice versa. | BL-001 |
| AC-002 | No row has `patient_id = var('test_patient')`, despite the macro not filtering it. Structurally guaranteed by the `encounters` base model, and **not assertable by a unit test**: a stub replaces that model including its filter, so a fixture supplying the test patient would prove nothing about production behaviour. | BL-002 |
| AC-003 | Adopting the macro at a call site produces a compiled-SQL diff that is shape-only plus the superset columns — no changed join keyword, predicate or column expression. | BL-003, BL-004 |
| AC-004 | Compiling a **dataset** caller of this macro yields SQL containing no `:` bind placeholder. Requires a dataset caller to exist; `admissions_dataset` is the first. Grepping for `parameter(` is necessary but not sufficient — `to_user_selected_timezone()` reaches the same hazard through a helper, so the check is on the compiled output, not the source. | BL-005 |
| AC-005 | An encounter whose `location_id` does not resolve to a location produces no row. | BL-006 |

AC-001, AC-003 and AC-005 are asserted at the `encounter_invoice_audit` call site by
`test_encounter_invoice_audit_aggregation` and
`test_encounter_invoice_audit_cancelled_invoice_products`, which stub `ref('encounters')`,
`ref('locations')` and `ref('facilities')` directly and so exercise this macro
end-to-end. AC-003 is checked per adoption by a compiled-SQL diff; the evidence for each
adoption belongs on its PR.

Those fixtures carry a second, sensitive facility with an encounter on it, and an
encounter whose `location_id` resolves to nothing. Both sit inside the default date window
and reuse existing patients, so either surfacing fails `expect`. Without them the
`and f.is_sensitive` predicate could be deleted outright and the tests still pass, which
is what makes them assertions rather than decoration:

| Mutation | Result |
|---|---|
| drop `and f.is_sensitive = {{ is_sensitive }}` | fails |
| `locations` inner join → `left join` | passes — the inner join to `facilities` still drops the row via the null `facility_id` |
| both joins → `left join` | fails |

The third row is the useful one: BL-006's outcome is asserted, but either inner join alone
enforces it, so the two are redundant with each other rather than independently
load-bearing.

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
- **OQ-002:** `encounter_summary_report` **will not** produce a shape-only diff, so AC-003
  does not hold for it as written. Its line 23 applies
  `e.patient_id != '{{ var("test_patient") }}'`, which BL-002 declines to re-apply. The
  `encounters` base model already filters it, so dropping it is behaviour-neutral, but the
  compiled diff for that adoption will show a **removed predicate**. PR-4 should carry a
  row-count check against real data rather than resting on the compiled diff alone.

## Change log

| Date | Change |
|---|---|
| 2026-09-02 | Created. Extracted from `encounter_invoice_audit_report`; adopted there first. |

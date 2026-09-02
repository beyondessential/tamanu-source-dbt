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

Three macros carried their own copy of this join and its `is_sensitive` predicate:
`encounter_invoice_audit_report`, `encounter_summary_report` and `admissions_dataset`.
The copies are near-identical rather than byte-identical — `admissions_dataset` puts
`is_sensitive` in the `where` clause with single-line joins, and `encounter_summary_report`
carries an extra `patient_id != test_patient` predicate the base model already applies —
which is itself the symptom. A miss in any one copy silently widens or narrows the
facility partition for that surface alone, and nothing in CI would catch it.

### Naming

The convention gives mechanism 4 the form `<entity>_core(...)`, which would make this
`encounters_core`. It is deliberately named `encounters_in_scope` instead, on the
convention's own "match the existing name over inventing a regular form" rule: every
call site already had a CTE of that name, so the adoptions read as a substitution rather
than a rename, and the compiled diffs stay reviewable. The `_core` suffix is reserved for
the case it was coined for — a body macro shared by a dataset and its paired report — and
this macro has no paired dataset. The cost is that `with encounters_in_scope as ( {{
encounters_in_scope(...) }} )` reads awkwardly at each call site; that was judged the
lesser evil against renaming the CTE in three places.

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
sites in `macros/encounters_in_scope.sql`. BL-003, BL-004 and BL-005 are **contract
clauses with no single code site** — they constrain what a caller may pass and what this
macro may contain, so there is nothing to anchor them to; the macro header states them in
prose. They are recorded here as configuration-only for the same reason BL-038 of
`audit-outpatient-appointments` is. Note that `encounter_invoice_audit.sql` declares its
*own* BL-002/003/004 with unrelated meanings, which is exactly why the macro header names
this spec file (`See specs/dbt-model/encounters_in_scope.md ...`) in the file-level form
maui-team#104 introduced.

## Acceptance criteria

| ID | Criterion | Clause |
|---|---|---|
| AC-001 | With `is_sensitive=false`, no row resolves to a facility with `is_sensitive = true`, and vice versa. | BL-001 |
| AC-002 | No row has `patient_id = var('test_patient')`, despite the macro not filtering it. | BL-002 |
| AC-003 | Adopting the macro at a call site produces a compiled-SQL diff that is shape-only plus the superset columns — no changed join keyword, predicate or column expression. | BL-003, BL-004 |
| AC-004 | `grep -c "parameter(" macros/encounters_in_scope.sql` returns 0. | BL-005 |
| AC-005 | An encounter whose `location_id` does not resolve to a location produces no row. | BL-006 |

AC-001, AC-003 and AC-005 are covered for the `encounter_invoice_audit` call site by
`test_encounter_invoice_audit_aggregation` and
`test_encounter_invoice_audit_cancelled_invoice_products`, which stub `ref('encounters')`,
`ref('locations')` and `ref('facilities')` directly and so exercise this macro
end-to-end. AC-003 was verified for that adoption by a full-project compiled diff: 2 of
2952 compiled models changed, both intended, and both token-identical apart from the
superset columns and two redundant wrapping parens.

**AC-001 and AC-005 are asserted, not merely asserted-of.** The first version of these
fixtures had a single facility with `is_sensitive = false`, which meant the
`and f.is_sensitive` predicate could be deleted outright and both tests still passed —
the spec claimed a coverage it did not have. The fixtures now carry a second, sensitive
facility with an encounter on it, and an encounter whose `location_id` resolves to
nothing. Both are inside the default date window and reuse existing patients, so either
one surfacing would fail `expect`. Confirmed by mutation:

| Mutation | Result |
|---|---|
| baseline | 20 passed |
| drop `and f.is_sensitive = {{ is_sensitive }}` | **1 failed** |
| `locations` inner join → `left join` | 20 passed — the inner join to `facilities` still drops the row via the null `facility_id` |
| both joins → `left join` | **1 failed** |

The third row is worth keeping: BL-006's outcome is asserted, but either inner join alone
is sufficient to enforce it, so the two are redundant with each other rather than
independently load-bearing.

**Both halves of the partition are now asserted.** The standard-variant tests above pin
`is_sensitive = false` (a sensitive facility's encounter must not appear).
`test_encounter_invoice_audit_sensitive_partition` pins the inverse on
`sensitive-audit-encounter-invoice`: given the same two facilities, the sensitive variant
must return the sensitive facility's encounter and only that one. It is the **only unit
test in the repo that targets a sensitive variant** — before it, replacing
`f.is_sensitive = {{ is_sensitive }}` with a hardcoded `= false` passed every test in the
project. Confirmed by mutation: that substitution now fails this test (and only this one).

This matters because sensitive-facility deployments exist, so the `true` half of the
partition is live behaviour, not a theoretical branch — and the database available for the
row-level check has no sensitive facilities, so fixtures are the only place it can be
pinned.

### Row-level verification against real data (2026-09-02)

Both compiled variants were run pre- and post-adoption against a populated
`reporting_release` database with the date range widened to `[2000-01-01, 2100-01-01]`
and every optional filter null, and compared with `except all` in both directions:

| Variant | Rows before | Rows after | Only in before | Only in after |
|---|---|---|---|---|
| `audit-encounter-invoice` | 687 | 687 | 0 | 0 |
| `sensitive-audit-encounter-invoice` | 0 | 0 | 0 | 0 |

**What that run did and did not establish.** The standard variant is a real result: 687
rows compared, byte-identical, spanning 6 distinct `encounter_type` values and including
the one open encounter (null `end_datetime`), so the BL-003 `includeOpenEncounters`
branch was exercised.

The sensitive comparison is **vacuous** — every facility in that database has
`is_sensitive = false`, so both sides legitimately return zero rows. BL-001's
`is_sensitive = true` half therefore has no real-data coverage here; it rests on the
compiled-SQL equivalence and on
`test_encounter_summary_by_start_date_excludes_sensitive_facilities`-style fixtures
elsewhere. Three further conditions were not differentiated by this dataset:

- only one facility is reached by any encounter, so the multi-facility partition and the
  `facilityId` filter were not distinguished;
- `ds__encounter_invoices` is empty, so all invoice columns were null on both sides —
  immaterial here, since the extraction does not touch the financial CTEs;
- no encounter has a null or dangling `location_id`, so BL-006's row-dropping inner join
  was not observed in practice.

None of these are regressions introduced by the extraction — they are gaps in the
available data. A run against a database with sensitive facilities and multiple
facilities in use would close them.

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

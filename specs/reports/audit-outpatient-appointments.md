# Report Spec: `audit-outpatient-appointments`

## Identity

| Field | Value |
|---|---|
| **Name** | `audit-outpatient-appointments` |
| **Type** | Tamanu report (shared macro + standard/sensitive wrappers), the `ds__outpatient_appointments_audit` dataset, and two base models |
| **Layer** | `base`, `ds`, `report` |
| **Materialisation** | base `view`; dataset `view`, or `incremental` on analytics targets; report `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6857](https://linear.app/bes/issue/MAUI-6857/audit-outpatient-appointments-report-times-out-full-change-log-scan) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-29 |
| **Last updated** | 2026-08-30 |

## Purpose

An audit log of modifications and cancellations to outpatient appointments — which Tamanu
users create and edit appointments, and what changed. Each row is one change event, carrying
the appointment's state at that point and its immediately preceding state.

**Consumers:** the Tamanu reporting UI; the dataset additionally serves analytics/Tupaia
consumers needing the full trail without report parameters.

## Grain

One meaningful change event per appointment — excluding the initial creation and status-only
transitions that aren't cancellations (BL-023, BL-025).

## Inputs

### Parameters (report only)

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | last 24 hours | Lower bound on the event's `appointment_start_datetime` — not on when the edit was made (BL-029) |
| `toDate` | date | last 24 hours | Upper bound on the same column |
| `facilityId` | uuid | null | Optional single-facility restriction |

### Macro argument (report and dataset)

`is_sensitive` — `false` (standard) / `true` (sensitive); selects the facility partition (BL-033).

### Upstream models

| Reference | Why |
|---|---|
| `ref('outpatient_appointments_change_events')` | The change history, window-function-free so it can be filtered with pushdown (BL-037) |
| `ref('outpatient_appointments')` | Appointment population (BL-036) and the schedule's `cancelled_at_date` (BL-026) |
| `ref('patients')` | Demographics |
| `ref('users')` ×4 (clinician, prev_clinician, creator, modifier) | Display names |
| `ref('location_groups')` ×2, `ref('reference_data')` ×2 | Area and appointment-type names, current and previous |
| `ref('facilities')` | Facility name and sensitivity partition (BL-033) |

### Freshness

The report reads through `bases/` at request time, so it is always current. The dataset on
analytics targets is only as fresh as its last incremental build (BL-032).

## Output schema

Standard and sensitive share one macro, so columns are identical by construction.

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId`, `patientFirstName`, `patientLastName` | text | Patient identity |
| `patientDateOfBirth` | text | Formatted date of birth |
| `auditChangeNumber` | integer | 1-based sequence of meaningful changes (BL-024) |
| `appointmentDateTime` | text | Appointment start as of this event |
| `appointmentType`, `appointmentClinician`, `appointmentLocationGroup` | text | State as of this event |
| `appointmentPriority`, `appointmentIsRepeating`, `appointmentIsCancelled` | text | `Yes`/`No` |
| `auditCreatedBy` | text | User who created the appointment |
| `auditModifiedBy`, `auditModifiedDateTime` | text | Who made this change, and when |
| `auditPrevAppointmentDateTime`, `auditPrevAppointmentType`, `auditPrevClinician`, `auditPrevLocationGroup`, `auditPrevPriority` | text | Previous values, blank if unchanged (BL-027) |

The dataset emits a different shape entirely — snake_case, unformatted, no translation keys
— covering the same facts plus `change_id`, `patient_id`, `facility_id`/`facility`,
`updated_at_sync_tick` (the incremental cursor), the raw `*_id` columns behind each
resolved name, and `appointment_end_datetime`/`prev_end_datetime`, which have no report
equivalent.

## Business logic

Code should reference these IDs as `-- BL-XXX:` comments; it does not yet (DV-005).

- **BL-023:** One row per meaningful change event, from
  `bases/outpatient_appointments_change_events` — which excludes soft-deleted change rows,
  rows with no `appointment_type_id`, and the test patient. The creation event
  (`change_sequence = 1`) is excluded at report and dataset grain, but *retained* by the
  extraction macro because `outpatient_appointments_dataset` uses it to find the creator.
- **BL-024:** `change_number` is `row_number()` per `appointment_id` ordered by
  `modified_datetime`, over rows passing BL-025 and the creation exclusion. It orders on
  `modified_datetime` alone, unlike the extraction macro's `(logged_at, record_updated_at,
  id)`, so events sharing a timestamp get an arbitrary, run-unstable order.
- **BL-025:** A change is meaningful when the status became `Cancelled`, or any of
  start/end datetime, clinician, location group, appointment type or priority differs from
  the preceding event. A non-cancelling status transition produces no row.
- **BL-026:** Appointments auto-cancelled by a schedule bulk-cancellation are excluded, to
  distinguish them from individual cancellations: dropped when `status = 'Cancelled'`, the
  schedule's `cancelled_at_date` is set, and the *change event's* `start_datetime` falls
  after it. `cancelled_at_date` is reached through the appointment's **current**
  `schedule_id` (via `ref('outpatient_appointments')`), not the `schedule_id` recorded on
  each event. Those differ only if a schedule was attached after the first change was
  logged; `schedule_id` is not otherwise mutated.
- **BL-027:** `prev_*` columns populate only where the value differs from the current row's,
  otherwise blank. `prev_priority` carries an extra `is not null` guard, so a transition out
  of null renders blank — the other columns do not do this.
- **BL-028:** Patient, location group and facility are inner joins, so an event whose
  `location_group_id` is null or dangling produces no row at all.
- **BL-029 (report):** `fromDate`/`toDate` filter the event's own
  `appointment_start_datetime`, not `modified_datetime`. With the 24-hour default this means
  "changes to appointments scheduled around now", not "edits made recently". `toDate` is
  compared as a date, so an appointment later in the day on `toDate` is excluded — the house
  pattern, though `audit_discharge_line_list` deliberately deviates.
- **BL-030 (report):** The report first finds `appointment_id`s with an event in
  `[fromDate, toDate]` via a plain filtered scan with no window functions, then reconstructs
  full history only for those — `lag()`/`first_value()`/`change_sequence` need an
  appointment's entire history to be correct. The date filter is re-applied at the end, so
  correctness never depends on the early filter being exact.
- **BL-031:** The windowed extraction is centralised in
  `outpatient_appointments_change_log_events(record_id_filter=none)`, called three ways:
  unfiltered as the base model (also feeding `outpatient_appointments_dataset`'s creator
  lookup), filtered by the report (BL-030), and filtered by the incremental dataset
  (BL-032). Filtering narrows *which* appointments are included, never how much of an
  included appointment's history is seen.
- **BL-032:** The datasets build as `view` except on analytics targets, where they are
  incremental. The cursor is `updated_at_sync_tick` — the cursor Tamanu's own sync readers
  use (no clock-skew risk) and the one `logs.changes` column still btree-indexed after
  migration `#10639`, where `logged_at` is BRIN-only. A first build or `--full-refresh`
  computes full history; later runs reprocess appointments with a row at or past
  `max(updated_at_sync_tick)`. The comparison is `>=`, not `>`: a sync tick is shared by
  every row in that session, so a strict comparison would permanently skip rows landing on
  the boundary tick after the previous run read it.
- **BL-033:** Facility scope is partitioned by `is_sensitive` on both report and dataset.
- **BL-034:** The incremental strategy is `delete+insert` on `unique_key='appointment_id'`,
  not append. `change_number` and `prev_*` come from window functions partitioned by
  `appointment_id`, so a new event invalidates that appointment's *later* rows — whose own
  cursor never moves. Append would leave them stale with no signal. The model therefore
  emits each candidate's entire current row set, and dbt replaces by key.
- **BL-035:** An incremental refresh is **not** self-healing. `delete+insert` removes only
  keys present in the new result, and candidates come from the change log alone:
  1. An appointment recomputing to zero rows keeps its stale rows — reachable normally, via
     a later schedule bulk-cancellation (BL-026) or a soft-delete (BL-036).
  2. Changes outside the change log don't trigger reprocessing. A facility's `is_sensitive`
     flipping is the sharpest case: rows stay in the standard dataset indefinitely.
  3. A hard delete from `logs.changes` is undetectable, writing no new tick.
  4. **A soft-delete is invisible to candidate detection.** The candidate CTE reads
     `outpatient_appointments_change_events`, which filters `record_deleted_at is null`, so
     the row recording a deletion is never seen and the appointment never becomes a
     candidate. BL-036 therefore does not propagate to an incremental table: the dataset can
     retain rows for appointments the report excludes.

  A periodic `--full-refresh` is therefore a correctness requirement, not tuning.
- **BL-036:** The audit covers the population `bases/outpatient_appointments` defines,
  enforced by an inner join to it. That excludes more than soft-deletes, and all of it on
  *current* state rather than state at the time of each event:
  - appointments with `deleted_at` set;
  - appointments **hard-deleted** from `appointments` — their whole audit trail disappears;
  - appointments whose *current* `appointment_type_id` is null, even if every logged event
    had one.

  The joins to `patients` and `location_groups` behave the same way: a patient later
  soft-deleted or merged takes their audit trail with them (BL-028).
- **BL-037:** `bases/outpatient_appointments_change_events` carries the change-log filters
  and no window functions, because both the report (by date) and the dataset (by tick) must
  narrow the log *before* the windowed reconstruction. Filtering the windowed base cannot
  work: Postgres pushes neither a date nor a partition-key predicate below a `WindowAgg`,
  as measurement confirmed. A window-free base is what keeps the early filter possible while
  every model stays on `ref()`.

## Acceptance criteria

No automated tests exist yet (DV-004); statuses below come from manual verification against
a populated replica. **The incremental statuses (AC-026, AC-028, AC-029) were measured
before the candidate query was rewritten to read the thin base (BL-037), so they attest to
the mechanism rather than to the query now in place — they need re-running.** AC-025 was
re-verified after that rewrite.

| ID | Criterion | Implements | Status |
|---|---|---|---|
| AC-020 | No row for the creation event | BL-023 | planned test |
| AC-021 | Non-cancelling status transitions produce no row; cancellations do | BL-025 | planned test |
| AC-022 | Schedule bulk-cancellations excluded; individual cancellations kept | BL-026 | planned test |
| AC-023 | `change_number` counts only rows surviving BL-025, the creation exclusion, BL-026 and BL-036 — so an appointment with one meaningful change among several events numbers it 1 | BL-024 | planned test |
| AC-024 | Unchanged fields render `prev_*` blank; changed fields show the previous value | BL-027 | planned test |
| AC-025 | Output identical before and after the BL-030 rework for a fixed range | BL-030 | **passed** — `EXCEPT ALL` both directions, no differing rows |
| AC-026 | An incremental run matches what `--full-refresh` would produce | BL-032, BL-034 | **partly passed** — a second run was idempotent; not exercised with new events arriving between runs |
| AC-027 | Sensitive-facility appointments never appear in the standard output, or vice versa | BL-033 | planned test |
| AC-028 | A new event causes that appointment's rows to be replaced, not appended | BL-034 | **partly passed** — replacement confirmed, zero duplicate `change_id`s; a genuinely new event not yet observed through it |
| AC-029 | Rows on the previous run's watermark tick are still picked up | BL-032 | **passed** — reprocessed; a strict `>` would have found no candidates |
| AC-030 | Stale rows persist after a zero-row recompute or sensitivity flip until `--full-refresh` | BL-035 | not tested |

Performance (BL-030) was measured on a populated replica: cost was previously flat across a
far wider date range because the window functions processed the whole history either way;
it now scales with the range requested.

## Lineage

```
logs.changes ──► outpatient_appointments_change_events (thin base, BL-037)
                          │
                          ├──► outpatient_appointments_change_log_events()  (windowed, BL-031)
                          │         ├─ unfiltered ──► outpatient_appointments_change_logs (base)
                          │         │                      └──► ds__outpatient_appointments (creator lookup)
                          │         ├─ report filter (BL-030) ──► audit-outpatient-appointments (+sensitive)
                          │         └─ tick filter (BL-032) ───► ds__outpatient_appointments_audit (+sensitive)
                          │                                            └──► analytics / Tupaia
                          └──► candidate-id CTEs for both filters
```

## Open questions

_None._

## Divergence from current code

- **DV-004:** No automated tests for the base models, datasets or report; every AC above is
  unverified by tooling. *Resolution:* add the planned singular tests.
- **DV-005:** BL clauses are not anchored with `-- BL-XXX:` comments in the SQL.
  *Resolution:* add them in a follow-up, non-functional commit.
- **DV-006:** The incremental mechanism is only partly verified. A full build then a second
  run has been exercised: rows were replaced not duplicated, the watermark tick reprocessed,
  and the role held the required `DELETE`. Not observed: a run where new events arrive
  between builds, and BL-035's stale-row cases. *Resolution:* exercise both before this
  reaches production analytics.

## Risks

- **The cursor depends on an index Tamanu migrations have been reshaping.**
  `changes_updated_at_sync_tick_index` is baseline and untouched by the two migrations that
  changed the others, but this came from migration history, not a live `pg_indexes` check —
  and which indexes exist depends on the migrations a deployment has run. Confirm per target.
- **BL-029 is easy to misread**: the date range filters appointment start time, not edit
  time, which reads naturally as "recent edits". Intentional and pre-existing.
- **`delete+insert` needs `DELETE` on the target schema**, under whatever role the analytics
  connection uses — not merely `SELECT`/`INSERT`.
- **First incremental model in this repo**, so there is no local precedent if the
  replace-by-`appointment_id` mechanism proves wrong for an unconsidered edge case.
- **The incremental branch and the PII-masking branch test different target prefixes.**
  BL-032 keys on `target.name.startswith('analytics')`, while `bases/patients` strips
  direct identifiers under `is_analytics_target()`, which tests `analytics_`. On a target
  named `analytics_*` the dataset is incremental *and* selects three columns that no longer
  exist. Repo-wide for all datasets, not specific to this model, but it makes "analytics
  targets" an imprecise precondition.
- **The watermark is the maximum over *emitted* rows, not scanned rows.** BL-023/025/026/036
  all drop rows before the select, so `max(updated_at_sync_tick)` can sit well below the
  log's true maximum. Safe — the candidate set is a superset — but a refresh can reprocess
  considerably more than "since the last run".
- **`IS DISTINCT FROM` in `CASE WHEN` breaks `sqlfluff`'s parser**, so four compiled models
  sit in `.sqlfluffignore`. A parser limitation, not an SQL defect.
- **The report is empty where change logging is not enabled** — nothing distinguishes that
  from "no appointments were modified". Observed on a real deployment.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-30 | Maui team | Initial spec, written alongside the performance rework: early appointment-id filtering (BL-030), the shared extraction macro (BL-031), the thin change-events base (BL-037), incremental materialisation keyed on `updated_at_sync_tick` (BL-032, BL-034) and its refresh limits (BL-035), and exclusion of soft-deleted appointments (BL-036). |

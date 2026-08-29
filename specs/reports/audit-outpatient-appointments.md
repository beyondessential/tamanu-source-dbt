# Report Spec: `audit-outpatient-appointments`

## Identity

| Field | Value |
|---|---|
| **Name** | `audit-outpatient-appointments` |
| **Type** | Tamanu report (shared macro in `macros/reports/`, standard + sensitive wrappers in `models/reports/`), plus the `ds__outpatient_appointments_audit` dataset (shared macro in `macros/datasets/`) and the `outpatient_appointments_change_logs` base model (shared extraction macro in `macros/bases/`) |
| **Layer** | `base`, `ds`, `report` |
| **Materialisation** | base `view`; dataset `view` (non-analytics targets) / `incremental` (analytics targets); report `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6857](https://linear.app/bes/issue/MAUI-6857/audit-outpatient-appointments-report-times-out-full-change-log-scan) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-29 |
| **Last updated** | 2026-08-29 |

## Purpose

The report shows an audit log of all modifications and cancellations to outpatient
appointments: which Tamanu users are creating and editing appointments, and what changed.
Each row is one change event, carrying both the appointment's state at that point and its
immediately preceding state.

This spec was written retrospectively (Mode A) alongside a performance rework of the report:
its original form read the full appointment change history for every appointment ever
logged in the system on every single report run, regardless of the requested date range,
because the underlying window functions blocked predicate pushdown of the date filter. See
Business logic BL-030 and BL-032, and Risks.

**Consumer:** Tamanu reporting UI (live report). The dataset layer additionally serves
downstream consumers that need the full, unfiltered audit trail without a report's
date-range parameters (e.g. Tupaia/analytics).

## Grain

**One row per:** meaningful change event to an outpatient appointment — one row per
modification or cancellation, excluding the initial creation event and excluding
status-only transitions that don't change to `Cancelled` (BL-023, BL-025).

## Inputs

### Parameters (report only)

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | UI default: last 24 hours | Lower bound on the change event's own `appointment_start_datetime` (viewer-timezone aware) — **not** on when the edit was made. See BL-029. |
| `toDate` | date | UI default: last 24 hours | Upper bound on the same column. |
| `facilityId` | uuid | null | Optional restriction to a single facility. |

### Macro argument (report and dataset)

| Argument | Values | Purpose |
|---|---|---|
| `is_sensitive` | `false` (standard) / `true` (sensitive) | Selects the facility partition (BL-033). |

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `source('logs__tamanu', 'changes')` | The appointment change history itself — `table_name = 'appointments'` |
| `source('tamanu', 'appointment_schedules')` | Detects bulk schedule cancellation, to exclude auto-cancelled appointments from the audit (BL-026) |
| `ref('patients')` | Patient demographics |
| `ref('users')` (aliased 4 ways: clinician, prev_clinician, creator, modifier) | Display names for the clinician and the users who created/modified the appointment |
| `ref('location_groups')` (current + previous) | Area names |
| `ref('reference_data')` (current + previous) | Appointment type names |
| `ref('facilities')` | Facility name and the sensitive-facility partition (BL-033) |

### Freshness expectations

The live report reads directly against `logs.changes` and its joined bases at request time —
always current as of the moment the report runs. The dataset, on analytics targets, is only
as fresh as its last incremental build (BL-032).

## Output schema

Report output (standard and sensitive; identical columns, partitioned by facility sensitivity):

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId` | text | Patient display ID |
| `patientFirstName` | text | Patient given name |
| `patientLastName` | text | Patient family name |
| `patientDateOfBirth` | text | Date of birth, formatted |
| `auditChangeNumber` | integer | 1-based sequence of meaningful changes for this appointment (BL-024) |
| `appointmentDateTime` | text | Appointment start, as of this change event, formatted in the viewer's timezone |
| `appointmentType` | text | Appointment type label, as of this change event |
| `appointmentClinician` | text | Clinician, as of this change event |
| `appointmentLocationGroup` | text | Area, as of this change event |
| `appointmentPriority` | text | `Yes` / `No`, as of this change event |
| `appointmentIsRepeating` | text | `Yes` / `No` — whether the appointment belongs to a repeating schedule |
| `auditCreatedBy` | text | User who created the appointment (first-ever change event) |
| `auditModifiedBy` | text | User who made this change |
| `auditModifiedDateTime` | text | When this change was made, formatted in the viewer's timezone |
| `appointmentIsCancelled` | text | `Yes` / `No` — whether this change event's status is `Cancelled` |
| `auditPrevAppointmentDateTime` | text | Previous start datetime, blank if unchanged (BL-027) |
| `auditPrevAppointmentType` | text | Previous appointment type, blank if unchanged |
| `auditPrevClinician` | text | Previous clinician, blank if unchanged |
| `auditPrevLocationGroup` | text | Previous area, blank if unchanged |
| `auditPrevPriority` | text | Previous priority, blank if unchanged |

The dataset's own output additionally carries `facility_id`/`facility` (for filtering) and
`updated_at_sync_tick` (incremental cursor, not report-facing — BL-032).

## Business logic

Each rule has an ID. Reference these IDs in implementing code (`-- BL-023:`); none of the
current code carries these comments yet (see Divergence, DV-005).

- **BL-023:** Grain is one meaningful change event to an appointment, sourced from
  `logs.changes` where `table_name = 'appointments'`, excluding soft-deleted change records,
  rows with no `appointment_type_id` (non-appointment noise in the same log), and the
  configured test patient. The initial creation event (`change_sequence = 1`) is excluded at
  the report and dataset grain — the report shows modifications, not creation. It is
  deliberately *retained* by the shared extraction macro and the base model, because
  `outpatient_appointments_dataset` reads `change_sequence = 1` to identify each
  appointment's creator (BL-031).
- **BL-024:** `change_number` starts at 1 for an appointment's first meaningful change and
  increments per appointment (`row_number() over (partition by appointment_id order by
  modified_datetime)`), counted only over rows that pass BL-025 and BL-023's
  creation exclusion. Note this window orders on `modified_datetime` alone, unlike the
  shared extraction macro's three-key `(logged_at, record_updated_at, id)` ordering, so two
  meaningful changes sharing a `modified_datetime` get an arbitrary and run-unstable
  relative `change_number`.
- **BL-025:** A change is "meaningful" (and so appears as a row) when either: the status
  changed to `Cancelled` from something else, or any of start/end datetime, clinician,
  location group, appointment type, or priority differ from the immediately preceding
  change. A pure status transition that isn't a cancellation (e.g. `Confirmed` →
  `Arrived`) is not meaningful and produces no row.
- **BL-026:** An appointment auto-cancelled when its parent schedule was cancelled (bulk
  "cancel this and all future appointments") is excluded from the audit, distinguishing it
  from an individually-cancelled appointment. Detected via a left join to
  `appointment_schedules`: excluded when `status = 'Cancelled'`, the schedule's
  `cancelled_at_date` is set, and the appointment's `start_datetime` falls after that date.
  `schedule_id` never changes on an existing appointment once set, so this join is stable
  across an appointment's history.
- **BL-027:** Previous-value columns (`prev_start_datetime`, `prev_clinician`, etc.) are
  populated only where the value differs from the current value on that row; unchanged
  fields render blank rather than repeating the current value. `prev_priority` carries an
  additional `is not null` guard, so a priority transition out of null renders blank rather
  than showing the null-to-value change — the other guarded columns do not do this.
- **BL-028:** Rows are dropped where the change event's patient, location group, or that
  location group's facility cannot be resolved — these are inner joins, not left joins. A
  change event whose `record_data` carries a null or dangling `location_group_id` therefore
  produces no output row at all, in addition to the exclusions in the Grain section.
- **BL-029 (report only):** the report's `fromDate`/`toDate` filter is on the change event's
  own `appointment_start_datetime` — the appointment's scheduled time as of that specific
  change — not on `modified_datetime` (when the edit was made). With the UI's 24-hour
  default, this reads as "modifications to appointments happening around now", not "edits
  made in the last 24 hours". An appointment rescheduled from next month to today would
  appear; an appointment edited an hour ago but scheduled for next month would not. See
  Risks — this is easy to misread given the 24-hour default.
- **BL-030 (report, performance):** the live report narrows the search space before
  reconstructing change history. It first identifies which `appointment_id`s have at least
  one change event whose `appointment_start_datetime` falls in `[fromDate, toDate]`, via a
  plain filtered scan of `logs.changes` with no window functions
  (`candidate_appointment_ids`). Only then does it reconstruct full change history — via
  the shared `outpatient_appointments_change_log_events()` macro, filtered to that candidate
  set — because `lag()`/`first_value()`/`change_sequence` need an appointment's *entire*
  history to be correct, not just the rows inside the window. The original date filter is
  re-applied at the very end as a correctness safety net: it is what guarantees output
  correctness; the early filter exists purely to reduce how much the window functions have
  to process, and its own imprecision (if any) can never leak into the result.
- **BL-031 (base/dataset, shared extraction):** the `logs.changes` → window-function
  extraction (`lag()`/`first_value()`/`row_number()` for previous value, creator, and
  change sequence) is centralised in one macro,
  `outpatient_appointments_change_log_events(record_id_filter=none)`
  (`macros/bases/outpatient_appointments_change_logs.sql`), called three ways:
  - unfiltered, as the base model `outpatient_appointments_change_logs` — also consumed by
    `outpatient_appointments_dataset`'s creator lookup (`ds__outpatient_appointments` /
    `ds__sensitive_outpatient_appointments`), which needs every appointment's creator
    regardless of any date range;
  - filtered to a report-request-time candidate set (BL-030), by the live report;
  - filtered to a build-time candidate set (BL-032), by the incremental dataset.

  All three preserve full per-appointment history for whichever appointment_ids they
  include — filtering narrows *which* appointments are considered, never *how much* of an
  included appointment's history is seen — so `lag()`/`first_value()`/`change_sequence`
  stay correct in every mode.
- **BL-032 (dataset materialisation and incremental cursor):**
  `ds__outpatient_appointments_audit` / `ds__sensitive_outpatient_appointments_audit` build
  as a `view` everywhere except analytics targets (`target.name.startswith('analytics')`),
  where they build as an incremental table. The incremental cursor is
  `logs.changes.updated_at_sync_tick`, persisted on the dataset as `updated_at_sync_tick` —
  not `logged_at`/`modified_datetime` — because: (a) it's the same cursor Tamanu's own
  changelog/sync readers already use, so it carries no cross-server clock-skew risk that a
  wall-clock timestamp would; and (b) it's the one `logs.changes` column still backed by a
  btree index after a Tamanu migration (`#10639`, 2026-08-03) dropped six other indexes
  including the `table_name` and jsonb GIN indexes — post-migration, `logged_at` is
  BRIN-only, a poor fit for a selective watermark predicate. The first build (or any
  `--full-refresh`) computes the full unfiltered history, matching the base model.
  Subsequent incremental runs identify which `appointment_id`s have a `logs.changes` row at
  or past the watermark `max(updated_at_sync_tick)` already in the table (an inline
  `candidate_appointment_ids` CTE, mirroring BL-030 at build time instead of
  report-request time) and reprocess them per BL-034 — this narrowing is what keeps a
  refresh cheap; it does not by itself decide what gets written.

  The comparison is `>=`, not `>`. A sync tick is shared by every row written in that sync
  session, so a strict comparison would permanently skip any row landing on the boundary
  tick after the previous run read it — those rows would never be picked up again, because
  the watermark has already moved past them. Reprocessing the boundary tick costs nothing,
  since BL-034's replacement is idempotent per appointment.
- **BL-033:** Facility scope is partitioned by the `is_sensitive` macro argument on both the
  report and the dataset — the standard/sensitive split used throughout this repo.
- **BL-034 (incremental replacement strategy — not a plain append):** A plain append
  (insert only the row whose own `updated_at_sync_tick` is new) is NOT correct for this
  model, unlike a model that's a straight pass-through/filter of an append-only log with no
  window function. `change_number` and every `prev_*` column come from
  `lag()`/`row_number()` partitioned by `appointment_id` — an appointment's rows are
  mutually dependent on each other's presence and order. A correction or deletion anywhere
  in an appointment's history can change what every *later* row for that appointment should
  contain, and none of those later rows' own `updated_at_sync_tick` changes when that
  happens, so filtering the insert by "this row's own tick is new" can leave stale
  `prev_*`/`change_number` values in place with no signal that they're wrong. Instead,
  `appointment_id` is the unit of replacement, via dbt's built-in
  `incremental_strategy='delete+insert'` with `unique_key='appointment_id'`: the model query
  emits each candidate appointment's *entire* current correct row set (not just the rows
  that changed), and dbt deletes every existing target row whose `appointment_id` appears in
  that result before inserting it. Candidate identification deliberately does not filter
  `record_deleted_at is null`, so a row transitioning into deleted is itself a valid
  reprocessing trigger, even though such a row is excluded from the output by
  `outpatient_appointments_change_log_events()`'s own filter and never produces a row
  itself.

  The delete set must come from the *same* evaluation as the insert set. An earlier revision
  deleted via a `pre_hook` whose candidate query recomputed `max(updated_at_sync_tick)` from
  `{{ this }}`; because a `pre_hook` runs before the model query, that delete lowered the
  watermark the model query then read, widening the insert set beyond the delete set and
  duplicating rows for the difference. `delete+insert` closes that window — the model query
  runs first, against an untouched target, and the delete is keyed off the result it
  produced.

- **BL-035 (incremental refresh is not self-healing):** `delete+insert` removes only the
  `appointment_id`s present in the new result, and candidates are detected from
  `logs.changes` alone. Three consequences, all requiring a periodic `--full-refresh` rather
  than being corrected by the next incremental run:

  1. **An appointment that recomputes to zero rows keeps its stale rows.** It is absent from
     the result, so nothing deletes it. This is reachable in normal operation, not only by
     correcting history: under BL-026, an individually-cancelled appointment whose schedule
     is *later* bulk-cancelled flips from included to excluded, and its previously
     materialised row survives.
  2. **Changes outside `logs.changes` do not trigger reprocessing.** The output also depends
     on `appointment_schedules`, `facilities.is_sensitive`, `location_groups`, `users` and
     `patients`. Flipping a facility's sensitivity is the sharpest case: the affected rows
     stay in the standard dataset and never appear in the sensitive one, indefinitely.
  3. **A hard delete from `logs.changes` is undetectable**, since it writes no new sync tick.

  The `--full-refresh` cadence is therefore a correctness requirement of this model, not a
  tuning choice, and should be scheduled wherever it is built incrementally.
- **BL-036 (audit history is retained for deleted appointments; D10 exemption):** This model
  reads `logs.changes` and `appointment_schedules` directly rather than through `bases/`,
  which D10 otherwise forbids. The exemption is deliberate and specific to audit models:
  `bases/` exist partly to filter soft-deleted rows, and an audit trail must retain the
  history of records that were later deleted — filtering them is the opposite of the
  requirement.

  Concretely, `bases/outpatient_appointments.sql` excludes any appointment whose *current*
  `deleted_at` is set; this model instead excludes only change-log rows already flagged
  deleted when they were written. So a soft-deleted appointment keeps the history recorded
  before its deletion here, while disappearing entirely from `ds__outpatient_appointments`
  and the outpatient line list. The audit population intentionally differs from every other
  appointment model.

  The exemption is narrow. It covers the change-log source and the schedule lookup that
  BL-026 needs; every other dimension — patient, clinician, area, facility, appointment type
  — is still resolved through `ref()` models and inherits their filters normally, including
  the exclusion of deleted, merged and test patients.

## Acceptance criteria

No automated tests exist yet for this model family (see Divergence, DV-004). The criteria
below describe what should be tested to hold the business logic above; each is currently
unverified except by manual reasoning and the compile-time checks in Risks.

| ID | Criterion | Implements | Test (planned) |
|---|---|---|---|
| AC-020 | No row for the initial creation event (`change_sequence = 1`) | BL-023 | dbt singular test |
| AC-021 | A pure status transition that isn't a cancellation produces no row; a cancellation from any prior status does | BL-025 | dbt singular test |
| AC-022 | An appointment auto-cancelled by its schedule being bulk-cancelled produces no row; one individually cancelled does | BL-026 | dbt singular test |
| AC-023 | `change_number` is 1 for an appointment's first meaningful change and increments by 1 per subsequent meaningful change, with no gaps | BL-024 | dbt singular test |
| AC-024 | A field that didn't change between consecutive events renders its `prev_*` column blank; a field that did change renders the actual previous value | BL-027 | dbt singular test |
| AC-025 | The report returns identical rows before and after the early-filter rework (BL-030) for a fixed date range against the same data | BL-030 | **Passed** — `EXCEPT ALL` in both directions against a populated replica returned no differing rows. No automated test yet |
| AC-026 | An incremental run on an analytics target produces the same rows a `--full-refresh` would, for every appointment touched since the last run | BL-032, BL-034 | Not yet run against a real analytics target — first incremental model in this repo |
| AC-027 | Facility scope: a sensitive-facility appointment never appears in the standard report/dataset and vice versa | BL-033 | dbt singular test |
| AC-028 | A new change event for an appointment that already has materialised rows causes that appointment's rows to be fully replaced after the next incremental run — no stale `prev_*`/`change_number` values survive on its earlier rows | BL-034 | Not yet run against a real analytics target |
| AC-029 | Rows written on the same sync tick as the previous run's high-water mark are still picked up by the next incremental run, rather than being skipped permanently | BL-032 | Not yet run against a real analytics target |
| AC-030 | After an appointment recomputes to zero rows, or a facility's `is_sensitive` flips, an incremental run leaves the stale rows in place and only a `--full-refresh` corrects them — the documented behaviour, asserted so it is not mistaken for a bug later | BL-035 | Not yet run against a real analytics target |

## Lineage

```
source: logs.changes (table_name = 'appointments')
        │
        ▼
outpatient_appointments_change_log_events()          <- shared extraction macro (BL-031)
macros/bases/outpatient_appointments_change_logs.sql
        │
        ├─ unfiltered ────────────► outpatient_appointments_change_logs (base, view)
        │                                   │
        │                                   ▼
        │                           outpatient_appointments_dataset (creator lookup only)
        │                                   │
        │                                   ▼
        │                           ds__outpatient_appointments / ds__sensitive_...
        │                                   │
        │                                   ▼
        │                           outpatient-appointments-line-list (report)
        │
        ├─ report-request-time filter (BL-030) ──► audit_outpatient_appointments_report()
        │                                           macros/reports/audit_outpatient_appointments.sql
        │                                                   │
        │                                                   ▼
        │                                           audit-outpatient-appointments /
        │                                           sensitive-audit-outpatient-appointments (reports)
        │
        └─ build-time incremental filter (BL-032) ─► outpatient_appointments_audit_dataset()
                                                        macros/datasets/outpatient_appointments_audit.sql
                                                                │
                                                                ▼
                                                        ds__outpatient_appointments_audit /
                                                        ds__sensitive_outpatient_appointments_audit
                                                        (view, or incremental on analytics targets)
                                                                │
                                                                ▼
                                                        downstream analytics/Tupaia consumers
```

## Open questions

_None._

## Divergence from current code

- **DV-004:** No automated tests exist for `outpatient_appointments_change_logs`,
  `ds__outpatient_appointments_audit`/sensitive, or the report — the Acceptance Criteria
  above are all currently unverified by tooling. *Resolution:* add the singular tests listed
  in Acceptance Criteria.
- **DV-005:** Business logic clauses (BL-023…BL-034) are not yet anchored with `-- BL-XXX`
  comments in the implementing SQL, since this spec was written after the code (Mode A).
  *Resolution:* add the anchoring comments to `macros/bases/outpatient_appointments_change_logs.sql`,
  `macros/reports/audit_outpatient_appointments.sql`, and
  `macros/datasets/outpatient_appointments_audit.sql` in a follow-up, non-functional commit.
- **DV-006:** The incremental `delete+insert` mechanism (BL-032, BL-034) has not been
  exercised against data. A `dbt build` against an analytics target confirmed the models
  compile and that both audit datasets materialise as tables rather than views, but the
  change log there was empty, so no rows were produced and no refresh has ever run. Still
  unconfirmed: that a second run replaces a changed appointment's rows without duplicating
  them (AC-026, AC-028), and that the analytics role holds `DELETE` on the target schema and
  not merely `SELECT`/`INSERT`. *Resolution:* run twice against a change-log-populated
  analytics target before this reaches production analytics.

## Risks

- **Report path measured; incremental path not yet run against data.** BL-030 has been
  confirmed by `EXPLAIN ANALYZE` on a replica with a populated change log: before the change
  the query cost was effectively flat across a far wider date range, because the window
  functions processed the entire appointment change history either way; after it, cost
  scales with the range requested and the row count entering the window functions drops by
  orders of magnitude. BL-032/BL-034's incremental behaviour remains unverified — see
  DV-006.
- **The chosen cursor depends on an index that Tamanu migrations have been actively
  changing.** BL-032 selects `updated_at_sync_tick` partly because
  `changes_updated_at_sync_tick_index` is a btree, where `logged_at` is BRIN-only. That
  index is part of Tamanu's baseline set and is not touched by the two migrations that
  reshaped the others (`AddAuditLogsRecordTypeRecordIdIndexes`, a central-only swap of a
  different index; and `dropUnusedChangelogIndexes`, which drops six *other* indexes). This
  was established from migration history, not from a live `pg_indexes` query, and the
  indexes present depend on which of those migrations the target deployment has run — so
  confirm against the actual database rather than assuming.
- **BL-029's filter semantics are easy to misread.** The 24-hour default date range filters
  on the appointment's own start time, not on when the edit happened. This is intentional,
  existing behaviour, but still worth flagging since it reads naturally as "recent edits" to
  a new reader.
- **`IS DISTINCT FROM` inside `CASE WHEN` cannot be linted where this logic now lives.**
  `.sqlfluffignore` already carried this exclusion against the dataset files for a
  documented `sqlfluff` parser limitation (not a real SQL defect). It now also covers the
  two report files, since the same `is_meaningful_change`/`prev_*` logic lives in both
  places post-rework (BL-030, BL-031). A future reader finding these four files ignored by
  `sqlfluff` should look here rather than assume it's accidental.
- **First incremental model in this repo.** No other model in `tamanu-source-dbt` uses
  `materialized='incremental'` today (see DV-006) — there is no local precedent to compare
  behaviour against if something about the delete-by-`appointment_id`-then-reinsert
  mechanism (BL-034) turns out to be wrong for an edge case not yet considered.
- **`delete+insert` requires DELETE on the target schema.** dbt issues the delete under
  whatever role the connection uses for that target; confirm the analytics-target role has
  `DELETE` and not merely `SELECT`/`INSERT` before the first incremental run.
- **This report reads `logs.changes` and `appointment_schedules` directly**, unlike every
  other report in the repo. That is a deliberate D10 exemption for audit models (BL-036),
  not an oversight — but it carries a practical consequence: the executing role needs
  privileges on those objects in its own right, rather than inheriting them from a
  `reporting` view owner as the previous version did. A role with access only to the
  `reporting` schema cannot run this report.
- **The report is empty where change logging is not enabled.** Everything here derives from
  `logs.changes`; a deployment whose change-log triggers are not installed returns no rows at
  all, with nothing on the report to distinguish that from "no appointments were modified".
  This has been observed on a real deployment, so it is not hypothetical.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-29 | Maui team | Initial spec, written retrospectively alongside the performance rework: report-level early appointment-id filtering (BL-030), the shared `outpatient_appointments_change_log_events()` extraction macro (BL-031), the dataset's incremental materialisation on analytics targets keyed on `updated_at_sync_tick` (BL-032), its delete-by-`appointment_id`-then-full-reinsert incremental strategy (BL-034), and the limits of an incremental refresh (BL-035). |

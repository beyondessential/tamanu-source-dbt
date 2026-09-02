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
| **Last updated** | 2026-09-02 |

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
| `fromDate` | date | last 24 hours | Lower bound on `modified_datetime` — when the edit was made, not the appointment's scheduled time (BL-029) |
| `toDate` | date | last 24 hours | Upper bound on the same column, inclusive of the whole day (BL-029) |
| `facilityId` | uuid | null | Optional single-facility restriction |

### Macro argument (report and dataset)

`is_sensitive` — `false` (standard) / `true` (sensitive); selects the facility partition (BL-033).

### Upstream models

| Reference | Why |
|---|---|
| `ref('outpatient_appointments_change_events')` ×2 (candidate filter, extraction) | The change history, window-function-free so it can be filtered with pushdown (BL-037) |
| `ref('outpatient_appointments')` | Appointment population (BL-036) and the schedule's `cancelled_at_date` (BL-026) |
| `ref('patients')` | Demographics |
| `ref('users')` ×4 (clinician, prev_clinician, creator, modifier) | Display names |
| `ref('location_groups')` ×3, `ref('reference_data')` ×2 | Area and appointment-type names, current and previous; the third location group resolves the candidate filter's facility (BL-033) |
| `ref('facilities')` ×2 | Facility name and sensitivity partition, at the end and in the candidate filter (BL-033) |

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

The dataset emits a different shape entirely — 37 columns to the report's 20, snake_case,
unformatted, no translation keys. Beyond the same facts it carries `change_id`,
`appointment_id` (the `unique_key` BL-034 replaces on), `patient_id`, `schedule_id`,
`facility_id`/`facility`, `updated_at_sync_tick` (the incremental cursor), the raw
`*_id` columns behind each resolved name, and `appointment_end_datetime` /
`prev_end_datetime`, which have no report equivalent.

## Business logic

Each clause is anchored in the implementing SQL as a `-- BL-XXX:` comment, so a reader
can move between rule and code. Note what that does *not* buy: `check_spec_anchors.py`
only checks that anchor IDs and clause IDs are the same set — it never compares comment
text to the code beneath it, does not care which file an anchor sits in, and warns
rather than fails on a clause with no anchor. Keeping a clause true to its code is a
review obligation, not an automated one (DV-007).

- **BL-023:** One row per meaningful change event, from
  `bases/outpatient_appointments_change_events` — which excludes rows whose appointment
  was already flagged deleted when that row was written (`record_deleted_at`, not a
  property of the change row itself), rows with no `appointment_type_id`, and the test
  patient. The creation event
  (`change_sequence = 1`) is excluded at report and dataset grain, but *retained* by the
  extraction macro because `outpatient_appointments_dataset` uses it to find the creator.
- **BL-024:** `change_number` is `row_number()` per `appointment_id` ordered by
  `(modified_datetime, change_sequence)`, over rows surviving BL-025, the creation
  exclusion, BL-026 and BL-036 — all four are applied upstream of the numbering.
  `change_sequence` is the tiebreaker: without it, events sharing a `modified_datetime`
  would number arbitrarily and differ between the report, the dataset and successive
  refreshes of the materialised table.
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
- **BL-029:** `fromDate`/`toDate` filter `modified_datetime` — when the edit was made — over
  `[fromDate, toDate + 1 day)`, so the whole of `toDate` is in scope.
- **BL-030:** The report finds candidate `appointment_id`s with a window-free filtered scan
  and reconstructs full history only for those, because
  `lag()`/`first_value()`/`change_sequence` need an appointment's entire history to be
  correct. Every candidate predicate is re-applied at the end, so correctness never depends
  on the early filter being exact.
- **BL-039:** The candidate filter converts the bound rather than the column, via
  `from_user_selected_timezone()`, so `logged_at` stays bare and prunable by its BRIN index
  (BL-032). The bounds are widened a day at each end, which keeps the candidate set a
  superset across DST boundaries; the final `WHERE` trims to the exact range.
- **BL-031:** The windowed extraction is centralised in
  `outpatient_appointments_change_log_events(record_id_filter=none)`, called three ways:
  unfiltered as the base model (also feeding `outpatient_appointments_dataset`'s creator
  lookup), filtered by the report (BL-030), and filtered by the incremental dataset
  (BL-032). Filtering narrows *which* appointments are included, never how much of an
  included appointment's history is seen. Everything downstream of the extraction —
  meaningfulness, numbering, the joins and the `prev_*` resolution — is shared too, in
  `outpatient_appointments_audit_core()`; the report and dataset differ only in projection,
  so they cannot drift on business logic.
- **BL-032:** The datasets build as `view` except on analytics targets, where they are
  incremental. The cursor is `updated_at_sync_tick` — the cursor Tamanu's own sync readers
  use (no clock-skew risk) and the one `logs.changes` column still btree-indexed after
  migration `#10639`, where `logged_at` is BRIN-only. A first build or `--full-refresh`
  computes full history; later runs reprocess appointments with a row at or past
  `max(updated_at_sync_tick)`. The comparison is `>=`, not `>`: a sync tick is shared by
  every row in that session, so a strict comparison would permanently skip rows landing on
  the boundary tick after the previous run read it.
- **BL-033:** Which rows appear is partitioned by `is_sensitive` on both report and dataset,
  and the report additionally applies `facilityId`. Both are applied in the candidate filter
  as well as at the end, resolved from the facility recorded on the event and never from the
  appointment's current row, which can differ.

  `prev_location_group` and `prev_location_group_id` resolve through the same partition on
  the same equality, so neither variant names an area outside its own half. A row whose
  appointment crossed the boundary keeps its row but carries neither the previous area's name
  nor its id.
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
- **BL-038:** The sensitive variant of the dataset is disabled unless the deployment sets
  `has_sensitive_facility`. A permanently empty incremental table keeps a watermark of 0, so
  every run would rescan the whole change log to emit nothing — worse than the view it
  replaced. Gated in the macro's `config()`, not `dbt_project.yml`, because `var()` does not
  resolve while project config is rendered.
- **BL-037:** `bases/outpatient_appointments_change_events` carries the change-log filters
  and no window functions, because both the report (by date) and the dataset (by tick) must
  narrow the log *before* the windowed reconstruction. Filtering the windowed base cannot
  work: Postgres pushes neither a date nor a partition-key predicate below a `WindowAgg`,
  as measurement confirmed. A window-free base is what keeps the early filter possible while
  every model stays on `ref()`.

## Acceptance criteria

No automated tests exist yet (DV-004); statuses below come from manual verification against
a populated replica, re-run against the current code after the BL-031 shared-core refactor.

| ID | Criterion | Implements | Status |
|---|---|---|---|
| AC-020 | No row for the creation event | BL-023 | planned test |
| AC-021 | Non-cancelling status transitions produce no row; cancellations do | BL-025 | planned test |
| AC-022 | Schedule bulk-cancellations excluded; individual cancellations kept | BL-026 | planned test |
| AC-023 | `change_number` counts only rows surviving BL-025, the creation exclusion, BL-026 and BL-036 — so an appointment with one meaningful change among several events numbers it 1 | BL-024 | planned test |
| AC-024 | Unchanged fields render `prev_*` blank; changed fields show the previous value | BL-027 | planned test |
| AC-026 | An incremental run matches what `--full-refresh` would produce | BL-032, BL-034 | **passed** — full build then a second run: row count and distinct `change_id` unchanged, no duplicates. Not exercised with new events arriving between runs |
| AC-027 | Sensitive-facility appointments never appear in the standard output, or vice versa | BL-033 | planned test |
| AC-028 | A new event causes that appointment's rows to be replaced, not appended | BL-034 | **passed** — the second run deleted and re-inserted rather than appending, zero duplicate `change_id`s. A genuinely new event not yet observed through it |
| AC-029 | Rows on the previous run's watermark tick are still picked up | BL-032 | **passed** — reprocessed; a strict `>` would have found no candidates |
| AC-030 | Stale rows persist after a zero-row recompute or sensitivity flip until `--full-refresh` | BL-035 | not tested |
| AC-031 | Every row returned has `modified_datetime` in `[fromDate, toDate + 1 day)` | BL-029 | not tested |
| AC-035 | An event logged in the central zone's ambiguous DST hour is returned when `:timezone` differs from central | BL-039 | not tested — the compile branch is unreachable from dbt (DV-004) |
| AC-036 | A standard row whose previous area sits in a sensitive facility returns that area blank, not named | BL-033 | **passed** — `test_audit_outpatient_appointments_sensitive_prev_area` |
| AC-037 | The partition is symmetric: a sensitive row whose previous area sits in a standard facility also returns it blank | BL-033 | **passed** — `test_audit_outpatient_appointments_prev_area_symmetric` |
| AC-032 | With `facilityId` set, an appointment whose events span two facilities returns the event at that facility, with the `change_number` it has unfiltered | BL-033 | **passed** — `test_audit_outpatient_appointments_facility_pushdown` |
| AC-033 | An edit made today to an appointment scheduled months out appears; a months-old edit to an appointment scheduled today does not | BL-029 | **passed** — `test_audit_outpatient_appointments_filters_on_edit_time` |
| AC-034 | The bound is compared against a bare `logged_at`, leaving the BRIN index usable | BL-039 | not tested — needs `EXPLAIN` on a populated replica |

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
                          └──► candidate-id filters (report: + location_groups, facilities)
```

## Open questions

_None._

## Divergence from current code

- **DV-004:** Coverage is two unit tests on the report; the base models and datasets have
  none. Unit tests reach only the non-compile branch of `to_user_selected_timezone` /
  `from_user_selected_timezone`, where both are near no-ops — the timezone conversion the
  compiled report actually runs, and the equivalence between the candidate filter and the
  final `WHERE` under it, cannot be exercised by dbt at all. *Resolution:* add the remaining
  singular tests; verify the compiled form against a replica.
- **DV-008:** This change adds two upstream dependencies the dataset did not previously have
  — `outpatient_appointments_change_events` and `outpatient_appointments`. An analytics build
  must include them, or the dataset fails outright. *Resolution:* confirm the analytics
  pipeline selects the model with its upstream chain rather than in isolation.
- **DV-007:** `check_spec_anchors.py` is not run by CI — `.github/workflows/checks.yml`
  does not invoke it — so even its ID-set check is advisory. *Resolution:* add it to the
  checks workflow, and consider `--strict-spec-coverage` so an unanchored clause fails
  rather than warns.
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
- **`logged_at` is the edit time, not a sync timestamp.** A changelog entry is authored once
  on the server where the change happened and copied verbatim to its peer, which pauses
  auditing while applying, so neither `logged_at` nor `updated_by_user_id` is restamped in
  transit. The one exception in `specs/audit/changelog.md` — central authoring entries itself
  for mobile-originated changes, which would stamp the apply time — cannot reach appointments,
  which have no mobile model and no entry in mobile's `modelsMap`.
- **The report must read a central-server database.** BL-031's whole-history requirement
  holds on central and not on a facility server. A facility push snapshots rows at
  `updated_at_sync_tick > pushSince` and attaches every entry for those rows at
  `>= pushSince` with no upper bound, so the attach window is a tick wider than the snapshot;
  the entry and its row are stamped in one transaction, `pg_advisory_xact_lock` holds the
  push until writers at that tick commit, the watermark advances only on success, and the
  first push uses `-1`. Central therefore accumulates every entry exactly once, and
  re-delivery is idempotent (`ignoreDuplicates`). A central *pull* is bounded at both ends
  and skipped outright when the session's tick range is unavailable or the peer is mobile, so
  a facility holds only partial history for anything edited elsewhere. Pointed at a facility
  database this report would compute `prev_*` and `change_number` against gaps, silently.
- **An appointment changing facility is an edge case, not a workflow.** Tamanu's appointment
  form resolves its Area field through the `facilityLocationGroup` suggester, which forces
  `filterByFacility: true`, so a user can only ever pick an area in the facility they are
  logged into — on edit as well as create. `PUT /appointments/:id` does not enforce it,
  though, passing `locationGroupId` through unchecked, and the appointment record exists at
  every facility after sync. So the divergence BL-033 guards against is reachable via the API
  or via a user at another facility, and AC-032 and AC-036 specify behaviour rather than
  describe a common occurrence.
- **The candidate filter and the final `WHERE` are not the same predicate.**
  `modified_datetime` is naive central time, so the final `WHERE` round-trips it back through
  the central zone — non-injective at that zone's DST fall-back, where an event in the
  repeated hour resolves to a different instant than the candidate filter compared. Reachable
  on the default `Australia/Sydney` whenever `:timezone` differs from it. BL-039's widened
  bounds absorb it; without them the row is silently dropped, which is the one direction
  BL-030's safety net cannot recover.
- **BL-029 changed meaning.** The date range now filters edit time where it previously
  filtered appointment start time. Saved parameter sets, scheduled exports and user habits
  built around the old behaviour return a different row set for the same inputs. The reading
  is confirmed on MAUI-6857 by its owner, drawn from MAUI-6183's stated purpose; the
  requesting PM was not re-consulted, so a later challenge to the semantics lands here rather
  than on the implementation.
- **`delete+insert` needs `DELETE` on the target schema**, under whatever role the analytics
  connection uses — not merely `SELECT`/`INSERT`.
- **On a non-persistent target the incremental buys nothing.** An existing but empty table
  has a watermark of 0, so every appointment is a candidate and the run is a full recompute —
  verified: a truncated table rebuilt completely and correctly, but took ~74s against ~1s for
  a delta run. Where the database does not persist between builds, this behaves exactly like
  a `table` materialisation at the same cost. The design only pays off on a persistent
  analytics database.
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
| 2026-09-02 | Maui team | BL-029's reading confirmed on MAUI-6857 by its owner, closing the last open question. Neither Linear card states which timestamp the date range bounds, so the decision rests on MAUI-6183's stated purpose rather than a written requirement. |
| 2026-09-02 | Maui team | Verified against Tamanu's source that `logged_at` is the edit time for every appointment entry: entries are authored once and copied verbatim, and the mobile exception cannot apply because appointments have no mobile representation. Retires DV-010. |
| 2026-09-02 | Maui team | BL-029 now filters edit time rather than appointment start time, replacing a filter on `appointment_start_datetime` that neither MAUI-6183 nor MAUI-6857 stated as a requirement (MAUI-6857). The bound is `< toDate + 1 day` rather than the house `<= toDate`, because `parameter()` ignores `data_type` when compiling and `<=` would truncate to midnight outside compile only. BL-030 split — bound-side conversion to BL-039, whose candidate bounds are widened a day at each end so a non-injective round trip through the central zone cannot drop rows; facility pushdown into BL-033, which now also resolves `prev_location_group` and its id through the partition on the same equality row admission uses. AC-025 retired; AC-031 to AC-037 added. |
| 2026-08-30 | Maui team | Initial spec, written alongside the performance rework: early appointment-id filtering (BL-030), the shared extraction macro (BL-031), the thin change-events base (BL-037), incremental materialisation keyed on `updated_at_sync_tick` (BL-032, BL-034) and its refresh limits (BL-035), and exclusion of soft-deleted appointments (BL-036). |

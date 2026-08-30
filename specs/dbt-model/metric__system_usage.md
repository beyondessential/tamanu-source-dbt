# dbt Model Spec: Tamanu system-usage indicators (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | Tamanu system usage (suite of 2 `metric__` indicators: `clinical_events`, `active_users`) |
| **Type** | dbt model suite (canonical definitions) |
| **Layer** | `metric` (D5 wide format) |
| **Materialisation** | view |
| **Status** | `approved` |
| **Owner** | @julianam-w |
| **Linear issue** | [MAUI-6780](https://linear.app/bes/issue/MAUI-6780/data-request-for-mid-year-phr-report) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-08 |
| **Last updated** | 2026-08-08 |

Canonical definitions for two generic, deployment-agnostic Tamanu adoption
indicators registered in `csv/metric_definitions.csv`:

- `clinical_events` — how much clinical activity was captured in Tamanu.
- `active_users` — how many Tamanu users were active.

Both are **period** (per-reporting-month) counts, re-expressed on the OMOP-lite
`clinical__` layer (D1/D2). Unlike the MSF metric suites, the implementation is
**shared** — a single model in `tamanu-source-dbt/models/metrics/` that every
deployment inherits by pinning the release; no per-deployment SQL is required
(see § Implementations). This spec governs the *definitions* — what each
indicator measures, output shape, and semantic invariants.

## Purpose

**What this artefact measures.** Two monthly system-adoption indicators: the
volume of clinical events recorded in Tamanu, and the number of distinct users
active in Tamanu, per facility per month.

**Origin of the request.** MAUI-6780 asks for these two numbers for FSM and
Tokelau for the mid-year PHR report (01 Jan – 30 Jun 2026), "same as is in the
EOPO1 dashboard for BES Reporting". The EOPO1 dashboard is powered today by
`data-staging`'s `bes__phr_mel_1_1` (IO1.1) model, whose `total_clinical_events`
and `total_users` columns are the legacy equivalents of these two indicators.
This spec re-homes those definitions on the OMOP-lite layer so every deployment
(starting FSM + Tokelau) can surface them via Tupaia Data Tables (D9) rather
than the sunset `data-staging` chain (D7).

**Clinical / operational context.** These are not clinical outcome indicators;
they are **platform-usage** indicators used for programme monitoring, evaluation
and learning (MEL) — Pacific Health Resilience (PHR) reporting to donors. They
answer "is Tamanu being used, and how much".

**Who reads it.** BES PHR MEL / EOPO1 reporting, via Tupaia Data Tables. The
mid-year PHR report (MAUI-6780) is the first consumer for FSM + Tokelau.

## Grain

- **`clinical_events` / `clinical_events_legacy`:** `metric_id × period_start ×
  facility_id × sex`.
  - **`facility_id`** lets consumers roll up to country by **summing** (a count
    of events is additive; country is the aggregate over the deployment's
    facilities).
  - **`sex`** is carried as a disaggregation so the GEDSI / female-only cut
    (legacy IO1.3) is derivable without a second model — a disaggregation
    dimension, not part of the subject identity.
- **`active_users`:** `metric_id × period_start` (national). `facility_id` and
  `sex` are NULL. A distinct-user count is **non-additive**, so it is emitted
  pre-aggregated at the deployment level and must not be summed across facilities
  (BL-003). This is the grain the consumer wants (`total_users` is national).

## Output schema

D5 wide format — same shape as `metric__mental_health_sessions`. Each output row:

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | `clinical_events`, `clinical_events_legacy`, or `active_users` |
| `variant_id` | text | Always NULL (see below) |
| `subject_id` | uuid | NULL — pre-aggregated counts, not per-subject rows |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month |
| `period_granularity` | text | Constant `'month'` |
| `value_numeric` | numeric | Period count for the month (see BL-002 / BL-002c / BL-003) |
| `value_boolean` | boolean | NULL — not used by these indicators |
| `facility_id` | text | Facility attributed for `clinical_events*`; NULL = whole deployment for `active_users` (BL-006) |
| `sex` | text | Patient sex for `clinical_events*`; NULL for `active_users` (BL-007) |

The canonical and legacy-parity series are modelled as **distinct `metric_id`
values** (`clinical_events` and `clinical_events_legacy`), the latter registered
`variant_of` the former. This keeps them non-double-counting (a consumer
selecting `metric_id = 'clinical_events'` gets only the canonical series) and
consistent with the registry. `variant_id` is therefore always NULL here,
reserved for future same-`metric_id` variants (per the D5 contract, which the
column carries regardless).

## Business logic

Every count is a **period** count — activity dated **within** the reporting
month — not a cumulative-to-date snapshot. This is the deliberate divergence
from the legacy `bes__phr_mel_1_1`, which reports cumulative month-end running
totals (`ce.yearmonth <= d.yearmonth`, `u.date_key <= d.date_key`). MAUI-6780
asks for activity "between 01 Jan – 30 Jun 2026", i.e. the sum of the six
monthly period counts.

- **BL-001:** Every output row carries `metric_id` set to its registered
  identifier in `csv/metric_definitions.csv`. Joining a consumer to the registry
  on `metric_id` returns the definition.

- **BL-002 (`clinical_events`):** Count of clinical-event **records** whose event
  date falls in the reporting month, summed across the OMOP-lite event domains:
  `clinical__condition_occurrence`, `clinical__drug_exposure`,
  `clinical__measurement`, and `clinical__observation`. One event record = one
  unit counted (grain of the source domain: one diagnosis, one drug exposure,
  one measurement, one observation). `subject_grain = event`.

- **BL-002a (event date):** The month a record belongs to is determined by its
  clinical event datetime (the OMOP domain's event date — e.g.
  `condition_start_datetime`, `drug_exposure_start_datetime`,
  `measurement_datetime`, `observation_datetime`), converted to the deployment
  timezone, **not** the row's `created_at` (UTC ingest time). Records with a NULL
  event date are excluded.

- **BL-002b (OMOP-lite canonical scope — divergence from legacy is expected):**
  The canonical `clinical_events` count (`variant_id` NULL) is defined on the
  OMOP-lite domains as they exist today. It will **not** equal the legacy
  `bes__phr_mel_1_1.total_clinical_events`, for two structural reasons, both
  accepted for the canonical definition:
  1. **Grain differences.** OMOP-lite `clinical__measurement` is one row per
     lab **test result** and per vitals **answer**, whereas legacy counts one
     row per lab **request** and per vitals **response**; OMOP-lite
     `clinical__observation` is one row per survey **answer**, whereas legacy
     counts one per survey **response**. OMOP-lite therefore counts finer.
  2. **Domain coverage.** Event types the legacy model counts that have **no
     OMOP-lite domain yet**: procedures, imaging requests/results, clinical
     notes, patient-letter documents, birth and death registration events, and
     program-registry add / status-change events. These are out of the
     canonical count until modelled (tracked as future OMOP-lite domains).

- **BL-002c (legacy-parity — `metric_id = clinical_events_legacy`):**
  A separate registered metric (`variant_of clinical_events`) that reproduces the
  legacy `data-staging` `ds__clinical_events` total 1:1, so consumers keep a
  continuous series across the `data-staging` sunset (D7). It counts, per month
  and facility (and patient `sex`), one row per record across the same 16
  legacy event types at the legacy grain, sourced directly from `bases/`
  (not the OMOP-lite domains): notes recorded; procedures; lab requests
  received; lab requests resulted (published); imaging requests received;
  imaging requests resulted; medication documented; vaccination recorded
  (status in Given/Not given/Unknown); birth registration; form completed
  (survey_type in programs/obsolete); referrals submitted (survey_type
  referral); vitals recorded (survey_type vitals); deaths record; diagnoses
  recorded; patient letter creation; patients added to program registry;
  status changed on program registry (where clinical status actually changed).
  This variant is the migration bridge, not the north-star definition; when the
  missing OMOP-lite domains land, the canonical count (BL-002) converges toward
  it and the variant can be deprecated.

- **BL-003 (`active_users`):** Count of **distinct** Tamanu users who authored at
  least one clinical event in the reporting month — a user is "active" in a month
  if they are the recorded author/clinician (`provider_id`) on ≥1 event counted
  by the **canonical** BL-002 set in that month. `subject_grain = user`. This is
  a period activity count, deliberately different from the legacy `total_users`
  (which counts user accounts that exist, cumulatively). Only `provider_id`s that
  **resolve to a real Tamanu user** (`ref__provider`) are counted: the vaccination
  branches of `clinical__drug_exposure` / `clinical__observation` set
  `provider_id = coalesce(recorded_by_id, given_by)`, and `given_by` is free text
  that need not reference a user — counting it raw would invent phantom users and
  double-count a clinician recorded both ways. Events with a NULL or unresolvable
  `provider_id` contribute no user. **Emitted at national grain only** (one row
  per month, `facility_id` NULL = whole deployment): a distinct-user count is
  **non-additive** across facilities, so it must not be split by facility and
  then summed. It therefore carries **no `disaggregations`** in the registry.
  This also matches the consumer's ask (`total_users` is a national figure,
  MAUI-6780).

- **BL-004 (not yet implemented — see OQ-003):** System and machine users
  *will be* excluded — the all-zero `id` "system" user and machine/integration
  accounts identifiable by role. This is **not yet implemented** in the model
  (there is a `-- BL-004` marker at the point it belongs); until OQ-003 settles
  the canonical exclusion method, `active_users` may include such accounts. Test
  patients are already excluded transitively (every source is inner-joined
  through `encounters`/`patients`, which filter the test patient).

- **BL-005:** `period_start`/`period_end` bound a calendar month;
  `period_granularity` is constant `'month'`. A month with no activity emits no
  row (absent = no-data, consistent with `metric__mental_health_sessions`
  BL-007); consumers must not read absence as zero.

- **BL-006 (`facility_id`):** `clinical_events` / `clinical_events_legacy`
  attribute to the facility of the event's encounter (canonical: via
  `clinical__visit_occurrence` → `ref__care_site` → facility, where
  `care_site_id` is the encounter's `department_id`). Events with no resolvable
  facility are attributed to a NULL facility, not dropped. `active_users` carries
  `facility_id` NULL by design — it is a **national** distinct-user count
  (BL-003), not attributable to a single facility.

- **BL-007 (`sex`):** `clinical_events` carries the patient's `sex` (from
  `clinical__person`) so the female-only cut is derivable. `active_users` has no
  patient subject, so its `sex` is always NULL.

- **BL-008 (soft deletes):** Only non-deleted records are counted. The
  `clinical__` layer already sources from `bases/`, which strip soft-deleted rows
  (D10), so no additional `deleted_at` filter is applied here.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `metric_id` on every row is one of `clinical_events`, `clinical_events_legacy`, `active_users` | BL-001 | dbt `accepted_values` |
| AC-002 | `period_granularity = 'month'` on every row | BL-005 | dbt `accepted_values` |
| AC-003 | `value_numeric` is `not_null` and `> 0` on every row | BL-005 | singular test |
| AC-004 | Composite key (`metric_id`, `variant_id`, `period_start`, `facility_id`, `sex`) is unique | BL-001..BL-007 | `dbt_utils.unique_combination_of_columns` |
| AC-005 | `sex` **and** `facility_id` are NULL on every `active_users` row (national grain) | BL-003, BL-007 | singular test |
| AC-006 | Every `metric_id` resolves to a row in `metric_definitions` | BL-001 | `relationships` |
| AC-007 | Every month with an `active_users` row also has a canonical `clinical_events` row (no users without events) | BL-003 | singular test |

## Registry entries

3 new rows in `csv/metric_definitions.csv`, all `kind = metric`,
`data_source = tamanu`, `definition_source = BES`,
`unit = count`, `owner = bes-maui`, `status = approved`,
`spec_path = specs/dbt-model/metric__system_usage.md`:

| `metric_id` | `name` | `subject_grain` | `disaggregations` | `variant_of` |
|---|---|---|---|---|
| `clinical_events` | Clinical events recorded in Tamanu (OMOP-lite) | `event` | `sex,facility_id` | — |
| `clinical_events_legacy` | Clinical events recorded in Tamanu (legacy parity) | `event` | `sex,facility_id` | `clinical_events` |
| `active_users` | Active Tamanu users | `user` | — (national, non-additive: BL-003) | — |

The canonical row (`clinical_events`) is the north-star OMOP-lite definition;
`clinical_events_legacy` is its `variant_of` parity bridge (BL-002c).

## Tupaia consumption (D9)

Tupaia reads this model **directly from each deployment's replica `analytics` schema**
(D9 — no Sling copy to the Data Lake). The model carries the Data Table contract
in its `meta`: model-level `create_data_table: true`; column filters
`metric_id` (array), `period_start` (date), `facility_id` (array, `facilityIds`),
`sex` (array, `sexes`); and metric `value_numeric` (`sum`).

Because the model is **shared** (one definition, many deployments) while the
Tupaia connection and permission groups are **per deployment**, the deployment
bits are supplied at generation time, not baked into the model meta. Generate
one Data Table per deployment with the data-lake generator's new-arch flags:

```
# from data-lake/data_tables, after the deployment has built the model
python generate_data_tables.py <out-dir> -m metric__system_usage \
  --manifest <deployment repo>/target/manifest.json \
  --source-schema analytics \
  --external-connection <replica connection code> \
  --code-prefix <deployment>  \
  --permission-groups "<Tupaia permission group>"
```

This emits a Tupaia SQL Data Table that reads
`SELECT :groupByColumns:, sum(value_numeric) FROM analytics.metric__system_usage WHERE
metric_id = any(...) AND period_start between ... AND facility_id = any(...) AND
sex = any(...) GROUP BY :groupByColumns:`, against the replica connection. A
dashboard picks `metricIds = {clinical_events}` (or `{active_users}`) plus the
period window; roll `facility_id` up to country for `clinical_events`, and read
`active_users` at its single national (`facility_id` NULL) row.

**Prerequisites (gated, tracked separately):** the deployment must pin a
`tamanu-source-dbt` release containing this model, be onboarded to the
`tamanu_analytics` pipeline so the model materialises in its replica `analytics`
schema, and have a Tupaia External Database Connection to that replica.

## Lineage

```
bases/ ──► clinical__condition_occurrence ─┐
bases/ ──► clinical__drug_exposure         ─┤
bases/ ──► clinical__measurement           ─┼──► metric__system_usage ──► Tupaia Data Table
bases/ ──► clinical__observation           ─┤        (clinical_events,        (per country,
clinical__visit_occurrence ─► ref__care_site┘         active_users)            EOPO1 / PHR MEL)
clinical__person (sex) ─────────────────────┘
```

## Implementations

| Deployment | Repo | Wiring |
|---|---|---|
| FSM | `tamanu-dbt-fsm` | Data Table on `metric__system_usage`, filtered per PHR permission group |
| Tokelau | `tamanu-dbt-tokelau` | Data Table on `metric__system_usage`, filtered per PHR permission group |

The model itself is generic and ships in `tamanu-source-dbt`; deployments get it
by bumping their `tamanu-source-dbt` pin. Only the Tupaia Data Table wiring (and
any per-deployment test-user exclusion, BL-004) is deployment-specific. As more
deployments adopt it, add a row here rather than forking the definition.

## Resolved decisions

- **OQ-001 → resolved (2026-08-08):** Ship the OMOP-lite definition as the
  canonical `clinical_events` (BL-002) **and** a `clinical_events_legacy`
  parity variant (BL-002c) for continuity across the `data-staging` sunset.
- **OQ-002 → resolved (2026-08-08):** `active_users` counts distinct users who
  **authored a clinical event** in the month (active authors), per BL-003 — not
  user accounts and not logins.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-003 | Confirm the canonical way to identify system / test / machine users to exclude (BL-004) — is there a `users.role` value or a seed of excluded user ids shared across deployments? | @julianam-w | TBD |
| OQ-004 | Confirm the deployment timezone source used for BL-002a month bucketing (per-deployment `var('timezone')`, used by `to_user_selected_timezone`). | @julianam-w | TBD |
| OQ-005 | The `clinical_events_legacy` metric (BL-002c) was authored offline and validated only by `dbt parse` — its **numeric parity** with `data-staging` `ds__clinical_events` must be confirmed on a real deployment DB before it is relied on for reporting. Parity checkpoints to verify: (a) vaccination status allow-list (`GIVEN/NOT_GIVEN/UNKNOWN`) vs the legacy Given/Not given/Unknown mapping; (b) program-registry status-change detection now excludes the first log per registration — confirm the legacy `dim_patient_program_registrations` did the same; (c) diagnoses — the base `encounter_diagnoses` excludes `disproven`/`error`, confirm legacy `fct_diagnoses` matches; (d) notes — legacy may exclude system-generated notes (this branch counts all `record_type = 'Encounter'` notes); (e) patient-letter documents — legacy may filter `document_metadata.type` (this branch counts all encounter-linked documents). | @julianam-w | before FSM/Tokelau go-live |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-08 | @julianam-w | Initial draft (MAUI-6780). Canonical OMOP-lite definitions for `clinical_events` and `active_users`, period-counted; divergence from legacy `bes__phr_mel_1_1` captured in BL-002b + OQ-001. |
| 2026-08-08 | @julianam-w | Resolved OQ-001 (OMOP-lite canonical + `clinical_events_legacy` parity variant, BL-002c) and OQ-002 (`active_users` = active authors). Added variant to registry, output `variant_id`, and AC-008. |
| 2026-08-08 | @julianam-w | `definition_source` set to BES; status → `approved`. |
| 2026-08-08 | @julianam-w | Code-review fixes (PR #684): `active_users` re-grained to national (non-additive fix); legacy parity re-modelled as its own `metric_id` `clinical_events_legacy` (no double-count) so `variant_id` is always NULL; BL-004 marked not-yet-implemented; `published_datetime` bug; vaccination allow-list; program-registry first-log guard; diagnoses/notes/documents parity notes added to OQ-005; AC-005/007/008 revised; env-aware materialisation. |
| 2026-08-30 | @julianam-w | Code-review fixes: `active_users` now semi-joins `ref__provider` so free-text `given_by` values cannot be counted as phantom users (BL-003); registry `disaggregations` for `active_users` cleared to match the national grain it actually emits (was `facility_id`, always NULL per BL-003/BL-006/AC-005). |

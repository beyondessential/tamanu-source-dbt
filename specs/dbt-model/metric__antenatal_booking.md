# dbt Model Spec: `metric__antenatal_booking` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `antenatal_booking` (1 registered indicator) |
| **Type** | dbt model (canonical definition; implemented in deployment repos) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else, set by the deployment implementation |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (registry only — no model in this repo) |
| **Linear issue** | [MAUI-6838](https://linear.app/bes/issue/MAUI-6838) |
| **Created** | 2026-08-26 |
| **Last updated** | 2026-08-26 |

Canonical definition for `antenatal_booking`: one row per pregnancy's first antenatal
registration/booking assessment. Distinct from `antenatal_contact` — see § Why a separate metric.

## Purpose

Antenatal care initiation — how many pregnancies are formally booked into antenatal care, the
WHO ANC1 concept, where a deployment captures only the booking assessment and not a per-visit
contact log.

| `metric_id` | Unit | Measures |
|---|---|---|
| `antenatal_booking` | count | Antenatal booking assessments (always 1 per row) |

**Who reads it.** Tupaia "Maternity and newborn" dashboard cards, via a data table over a
deployment's implementation of this definition.

**Implemented where a deployment records a booking assessment but no per-visit contact log.**
Tamanu holds no deployment-neutral base for antenatal care — the reasoning is set out in
`metric__antenatal_contact.md` § Why the definition is canonical but the implementation is not,
and applies identically here.

## Why a separate metric, not a variant of `antenatal_contact`

`variant_of` in this registry records a deployment-specific *implementation* of the same
definition — same population, same grain, different columns. A booking assessment is not that.

A form completed once per pregnancy, with no per-contact date, cannot implement
`antenatal_contact`'s definition at all: counting its responses answers a different clinical
question — was this pregnancy booked into care — from counting per-visit charts, which answers
how many contacts the pregnancy received. Sharing one `metric_id` would either report bookings as
contacts or contacts as bookings, in a registry whose whole purpose is that a `metric_id` means
one thing everywhere. Two `metric_id`s keep both honest about what they count, and a deployment
recording both forms can implement both.

## Definition sources

| Element | `definition_source` | Concept |
|---|---|---|
| `antenatal_booking` | `WHO_CORE_100` | Antenatal care coverage (first visit) is a 100-core-list entry, following WHO recommendations on antenatal care for a positive pregnancy experience (2016) — the ANC1 concept, counted here as booking assessments rather than a population-based coverage percentage |

Pending alignment with the deploying country's national HMIS definition.

## Grain

**One row per `(metric_id, subject_id)`**, `subject_id` identifying the booking assessment.
`subject_grain: episode` in the registry — one booking per pregnancy episode, not per visit. A
patient with two pregnancies in the data has two bookings, which is correct.

## Output schema (canonical minimum)

An implementation may add columns; every implementation must emit at least:

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `antenatal_booking`. FK → `metric_definitions.metric_id` |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | The booking assessment's identifier. `not_null` |
| `period_start` | timestamp | Date of the booking assessment |
| `period_end` | timestamp | Equal to `period_start` — a booking is a point event |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` |
| `facility_id` | varchar(255) | Facility where the assessment was completed |

## Business logic

- **BL-001 (registration):** the `antenatal_booking` `metric_id` is registered in
  `documentations/metrics/maternity.yml` before any implementation's `relationships` test can
  pass at `error` severity. An implementation holds that test at `warn` until the registry row
  has shipped in a `tamanu-source-dbt` release the deployment has pinned, per the registry
  checklist.
- **BL-002 (no rate stored):** counts only, on the same basis as `antenatal_contact` BL-002.
- **BL-003 (reporting period):** `period_start` is the date of the booking assessment at `'day'`
  granularity, and `period_end` equals it — a booking is a point event. Pregnancy dates the form
  may carry (last menstrual period, estimated delivery date) are attributes of the pregnancy, not
  of the booking event, so they are never the reporting period.
- **BL-004 (the implementation owns the source):** which survey model, which question codes, and
  how booking date and facility resolve are implementation details of the deployment repo that
  builds this metric — not specified here, because they are not portable. Each implementation
  spec links here from its identity block.
- **BL-005 (classification):** every implementation classifies at least `classification:
  restricted`, on the same basis as `metric__birth` BL-012.

## Acceptance criteria

Asserted by each implementation, against its own model.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `antenatal_booking` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`warn` until the registry release is pinned, then `error`) |
| AC-004 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` |
| AC-005 | `period_end` equals `period_start` | BL-003 | `dbt_utils.expression_is_true` |

## Registry entry

One row in `documentations/metrics/maternity.yml` — `antenatal_booking`, `kind: metric`,
`subject_grain: episode`, `variant_of: null`, `spec_path` pointing here,
`disaggregations: facility_id`. `status: draft` until an implementation lands and this spec is
approved.

## Consumers

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Do not add bookings to contacts.** A booking is care initiation; a contact is care volume.
   Summing the two double-counts the pregnancies that have both.
3. **Form coverage downstream, against its own denominator.** Per BL-002.
4. **Respect `classification: restricted`.** Per BL-005.

## Related

| Artefact | Relationship |
|---|---|
| `metric__antenatal_contact` | Sibling definition for per-visit capture — different subject grain, not a variant of this metric |
| `metric__birth` | Same dashboard group; deployment-neutral, unlike this metric |
| MAUI-6838 | Tupaia maternity and newborn dashboard: standard metric and visuals |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-26 | Maui team | Initial draft |

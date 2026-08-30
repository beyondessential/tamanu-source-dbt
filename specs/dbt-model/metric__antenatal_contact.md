# dbt Model Spec: `metric__antenatal_contact` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `antenatal_contact` (1 registered indicator) |
| **Type** | dbt model (canonical definition; implemented in deployment repos) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else, set by the implementation |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (registry and definition only — no model in this repo) |
| **Linear issue** | [MAUI-6838](https://linear.app/bes/issue/MAUI-6838) |
| **Created** | 2026-08-26 |
| **Last updated** | 2026-08-27 |

Canonical definition for `antenatal_contact`: one row per antenatal care contact — a scheduled
or opportunistic visit during pregnancy at which a health worker assesses the mother and fetus.

## Purpose

Antenatal care activity — how many contacts a pregnancy receives, disaggregated by facility.

| `metric_id` | Unit | Measures |
|---|---|---|
| `antenatal_contact` | count | Antenatal care contacts (always 1 per row) |

**Who reads it.** Tupaia "Maternity and newborn" dashboard cards, via a data table over a
deployment's implementation of this definition.

**Coverage is not materialised.** Antenatal coverage needs a population or expected-pregnancies
denominator Tamanu does not hold — the same numerator-only pattern as
`metric__immunisation_dose`. This definition emits the contact count only; a coverage percentage
is formed downstream against an externally supplied population estimate.

## Why the definition is canonical but the implementation is not

Tamanu holds no deployment-neutral base for antenatal contacts. There is no antenatal or
pregnancy table; `map__omop_visit_type` carries no obstetric visit concept and no
`encounters.encounter_type` value could feed one; and there is no shared question-code convention
across deployments' antenatal forms, unlike WHO DAK, whose registered element ids are portable.
Antenatal care is captured as program-form survey responses whose codes are authored per
deployment.

So the definition lives here and each implementation lives in the deployment repo that holds the
data, sourced from that deployment's own survey models. Registering it centrally is what
`models/metric_definitions.yml` requires — a `metric_id` means one thing across every deployment
— and implementation differences are invisible at this level.

**A deployment can implement this definition only where it records antenatal care as a per-visit
form carrying its own contact date.** Two adjacent cases are *not* this metric:

- Recording a single booking assessment per pregnancy, with no per-contact date, measures care
  initiation rather than contact volume. That is `antenatal_booking` — a different subject grain,
  not a variant of this definition. See `metric__antenatal_booking.md` § Why a separate metric.
- Recording no antenatal data leaves neither metric available.

## Definition sources

The registry's `definition_source` field takes a controlled vocabulary
(`models/metric_definitions.yml`), so it carries the standard's registry name and this table
carries the specific document.

| Element | `definition_source` | Concept |
|---|---|---|
| `antenatal_contact` | `WHO_CORE_100` | Antenatal care coverage is a 100-core-list entry; the contact concept follows WHO recommendations on antenatal care for a positive pregnancy experience (2016) — the ANC contact schedule, a minimum of eight contacts across pregnancy. This definition counts raw contacts; it does not itself compute ANC4+/ANC8+ coverage status, which is a downstream aggregation (§ Consumers) |

Pending alignment with the deploying country's national HMIS definition, per every other metric
in this registry.

## Grain

**One row per `(metric_id, subject_id)`**, `subject_id` identifying the contact.
`subject_grain: visit` in the registry — a contact is a discrete, dated event, the closest
existing grain label even though it is survey-sourced rather than an OMOP visit.

## Output schema (canonical minimum)

An implementation may add columns; every implementation must emit at least:

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `antenatal_contact`. FK → `metric_definitions.metric_id` |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | The contact's identifier. `not_null` |
| `period_start` | timestamp | Date of the contact |
| `period_end` | timestamp | Equal to `period_start` — a contact is a point event |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` |
| `facility_id` | varchar(255) | Facility where the contact occurred |

## Business logic

- **BL-001 (registration):** the `antenatal_contact` `metric_id` is registered in
  `documentations/metrics/maternity.yml` before any implementation's `relationships` test can
  pass at `error` severity. An implementation holds that test at `warn` until the registry row
  has shipped in a `tamanu-source-dbt` release the deployment has pinned, per the registry
  checklist.
- **BL-002 (no rate stored):** counts only. Coverage — contacts against an expected-pregnancies
  denominator — is formed downstream, against a population estimate this registry does not
  supply. Per D5 "Rate scale" any rate that *is* stored is a 0–1 fraction.
- **BL-003 (a contact is dated by the contact, not the data entry):** `period_start` is the
  clinical contact date the form records, at `'day'` granularity, falling back to the survey
  response's own timestamp only where that field is blank. A response timestamp is a data-entry
  time and can differ from the contact date, so it is a fallback rather than the source.
  `period_end` equals `period_start` — a contact is a point event with no duration.
- **BL-004 (the implementation owns the source):** which survey model, which question codes, and
  how contact date and facility resolve are implementation details of the deployment repo that
  builds this metric — not specified here, because they are not portable. Each implementation
  spec links here from its identity block.
- **BL-005 (classification):** every implementation classifies at least `classification:
  restricted` — a contact record identifies a specific pregnant patient by date and facility, the
  same reasoning as `metric__birth` BL-012.

## Acceptance criteria

Asserted by each implementation, against its own model.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `antenatal_contact` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`warn` until the registry release is pinned, then `error`) |
| AC-004 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` |
| AC-005 | `period_end` equals `period_start` | BL-003 | `dbt_utils.expression_is_true` |

## Registry entry

One row in `documentations/metrics/maternity.yml` — `antenatal_contact`, `kind: metric`,
`subject_grain: visit`, `variant_of: null`, `spec_path` pointing here,
`disaggregations: facility_id`. `status: draft` until an implementation lands and this spec is
approved.

An implementation proposing an additional disaggregation adds it to this row and to the
`assert__metric_definitions__disaggregations` allowlist together — and only where the column is
portable enough to mean the same thing in another deployment's implementation.

## Consumers

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Form coverage downstream, against its own denominator.** Per BL-002.
3. **Do not read contact counts across deployments as like for like.** Two implementations count
   contacts from different forms; the definition is shared, capture practice is not.
4. **Respect `classification: restricted`.** Per BL-005.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a downstream ANC4+/ANC8+ coverage classification (count of contacts per pregnancy against the WHO 4/8-contact thresholds) belongs in the Tupaia visual layer or as a future `derived__` model | @maui-team | unscheduled |

## Related

| Artefact | Relationship |
|---|---|
| `metric__antenatal_booking` | Sibling definition for booking-only capture — different subject grain, not a variant of this metric |
| `metric__birth` | Same dashboard group; deployment-neutral, unlike this metric |
| `metric__immunisation_dose` | Precedent for the numerator-only coverage pattern |
| MAUI-6838 | Tupaia maternity and newborn dashboard: standard metric and visuals |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-26 | Maui team | Initial draft |

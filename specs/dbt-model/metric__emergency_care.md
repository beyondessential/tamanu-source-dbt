# dbt Model Spec: `metric__emergency_care` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__emergency_care` (suite of 3 `metric__` indicators) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format) |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.54`) |
| **Linear issue** | [MAUI-6694](https://linear.app/bes/issue/MAUI-6694) / [MAUI-6787](https://linear.app/bes/issue/MAUI-6787) |
| **Created** | 2026-08-11 |
| **Last updated** | 2026-08-11 |

Canonical definitions for the three emergency care indicators registered in
`csv/metric_definitions.csv`: `ed_attendance`, `ed_attendance_admitted` and
`ed_admission_rate`. Monthly, at facility grain, disaggregated by sex and age band.

**Supersedes `ds__emergency_visit`.** That dataset carried the same attendance definition
(intake segment with OMOP visit concept 9203, the 262 admission flag) as a standalone
wide-format dataset. Re-expressing it as registered metrics makes the definitions
discoverable in the registry, externally anchored, and reusable across deployments rather
than local to one dashboard's dataset — see § Why metrics rather than a dataset.

## Purpose

**What this artefact measures.** Emergency department activity at a Tamanu facility, per
calendar month:

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_attendance` | count | ED attendances |
| `ed_attendance_admitted` | count | Of those, the ones that became an inpatient admission |
| `ed_admission_rate` | percentage | The proportion admitted |

**Clinical context.** In Tamanu an ED arrival that is later admitted is a **single
encounter** whose type changes over time, recorded in `encounter_history`. Counting
attendances therefore means counting *encounters that started in the ED*, not encounters
currently typed as emergency — otherwise every admitted-via-ED patient disappears from the
attendance count the moment they are admitted.

**Who reads it.** The Tupaia "Hospital Administration → Emergency" dashboard for Queen of
Sheba Hospital (MAUI-6694), via a data table over this view. Any deployment needing ED
activity indicators can consume the same definitions.

## Why metrics rather than a dataset

`ds__emergency_visit` worked, but it was a bespoke dataset for one dashboard card. Three
reasons this belongs in the metric layer instead:

1. **MAUI-6694 is an indicator set, not a dataset.** The dashboard spec lists ~25
   indicators across 10 groups. Keyed on `metric_id`, one model carries many indicators and
   one data table serves many visuals, each filtering to its own metric. One `ds__` per
   indicator does not scale to that.
2. **The definition becomes discoverable.** A registry row carries the definition, its
   source, its rationale and its spec path. A dataset's definition lived only in its own
   spec.
3. **It can be externally anchored.** `definition_source` / `definition_source_code` let a
   metric cite the standard it implements — see § Definition sources.

## Definition sources

`ed_attendance` and `ed_attendance_admitted` cite **AIHW** (Australian Institute of Health
and Welfare, custodian of the METeOR metadata registry) for the *concepts* they build on:

| `metric_id` | Source | Code | Concept |
|---|---|---|---|
| `ed_attendance` | AIHW | [746091](https://meteor.aihw.gov.au/content/746091) | Emergency department stay — presentation date |
| `ed_attendance_admitted` | AIHW | [746706](https://meteor.aihw.gov.au/content/746706) | ED service episode — episode end status |
| `ed_admission_rate` | BES | — | A proportion of the two above |

**What is and isn't being claimed.** AIHW does publish aggregate indicators in METeOR, with
numerator/denominator/computation fields — e.g. National Healthcare Agreement
[PI 19](https://meteor.aihw.gov.au/content/740847). But its ED indicators are Australian
*policy performance* measures (PI 19 requires triage category 4–5 and non-ambulance
arrival), not plain activity counts. **No AIHW indicator matches a monthly ED attendance
count.** So these metrics cite the AIHW *data element concept* they rest on, while the
monthly aggregation is a BES composition. They are not implementations of AIHW indicators.

**Standards deliberately not used, and why:**

- **WHO / DHIS2** publish no emergency-department indicator set. The WHO Global Reference
  List of 100 Core Health Indicators is national-grain; the DHIS2 WHO metadata packages are
  programme-vertical (HIV, TB, malaria, immunisation, RMNCAH …) with no ED package. Note
  DHIS2's "Health Emergency Preparedness and Response" package concerns *public-health*
  emergencies — outbreaks and disasters — not emergency departments.
- **WHO Emergency Care System Framework / WHA72.16** are system-assessment and policy
  frameworks. WHA72.16 *calls for* indicators; it does not define them.
- **WHO EMT Minimum Data Set** is for disaster and public-health-emergency response.
- **AFEM** (African Federation for Emergency Medicine) has 76 consensus emergency care
  quality indicators, developed in support of WHO standardisation and designed for exactly
  this data environment. They are **condition-specific clinical quality** measures (e.g.
  "% of trauma patients who die within 24 hours of presentation"), not activity counts, so
  none matches these three. **AFEM is the correct anchor for any future ED *quality*
  metric** — it is African, WHO-aligned, and its authors explicitly excluded time-stamped
  metrics as impractical in low-resource settings, which is a standing caution against
  prioritising waiting-time indicators here.

**OQ-001 — Ghana DHIMS2 alignment.** Ghana has run DHIS2 nationally as DHIMS2 since 2012,
collecting monthly facility-level attendance. Queen of Sheba almost certainly already
reports into it. Aligning these definitions to DHIMS2's would make the dashboard agree with
the hospital's national returns — worth much more than agreeing with an Australian standard.
The DHIMS2 dataset definitions were not available at time of writing. The registry rows note
alignment as pending, but in country-neutral terms ("the deploying country's national HMIS
definition") — the registry lists the standard metrics the product works with, so naming one
deployment there would be wrong. Ghana is named here, in the spec for the work that raised
the question. If DHIMS2 defines attendance differently, that becomes a `variant_of` row
rather than a change here.

## Grain

**One row per**
`(metric_id, period_start, facility_id, sex, age_group__who_primary_classification)`.
Asserted by AC-001 at `error` severity — a grain violation would double-count a month in any consumer
that sums `value_numeric`.

`subject_id` is NULL throughout: these are pre-aggregated counts, not per-subject facts.

## Output schema

D5 wide format, plus this suite's three disaggregation columns.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the three registered ids. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — standard definitions, no variant |
| `subject_id` | uuid | NULL — pre-aggregated |
| `period_start` | date | First day of the reporting month, inclusive. `data_table_filter: date` |
| `period_end` | date | Last day of the reporting month, inclusive |
| `period_granularity` | text | Constant `'month'` |
| `value_numeric` | numeric | Count, or percentage for `ed_admission_rate`. `data_table_metric: sum` |
| `value_boolean` | boolean | NULL — unused |
| `facility_id` | uuid | Facility of the intake segment's location. `data_table_filter: array` |
| `sex` | text | `clinical__person.gender_source_value`. `data_table_filter: array` |
| `age_group__who_primary_classification` | text | Age band at the attendance date (BL-004). Named for the classification that produced it, not a generic `age_group`, because bands are not comparable across classifications. `data_table_filter: array` |

## Business logic

- **BL-001 (registration):** every emitted row's `metric_id` is registered in
  `csv/metric_definitions.csv`, asserted by AC-003 at `error` severity. The registry is the
  definition of record; this model is its implementation.
- **BL-002 (reporting period):** monthly, bucketed by `date_trunc('month', …)` on the
  attendance's presentation date. **The incomplete current month is never emitted** — a
  partial final month reads as a collapse on a trend chart. "Today" is plain `current_date`,
  matching every other model in this repo. That is the **DB session** date, which under a UTC
  session can lag a deployment east of UTC by up to a day: for a few hours after local
  midnight on the 1st, the just-completed month is still withheld. Accepted deliberately —
  the model is a view, so it self-heals within the day, and the alternative
  (`now() at time zone var('timezone')`) buys a sub-day edge at the cost of diverging from
  the repo's convention. No test-only variable is used to pin the boundary: unit tests date
  their fixtures in the past (always included) or the far future (always excluded), so the
  exclusion is deterministic without one. There is no month spine: a
  month with no ED attendance emits no row rather than a zero, since absence and a true zero
  are not distinguishable here and a fabricated zero is the more misleading of the two.
- **BL-003 (attendance inclusion + intake attribution):** an ED attendance is the **first**
  segment of an encounter (`clinical__visit_detail` where `preceding_visit_detail_id is
  null`) whose `visit_detail_concept_id = 9203` (OMOP 'Emergency Room Visit', via
  `map__omop_visit_type`). Filtering on the OMOP concept rather than the raw
  `visit_detail_source_value` ties inclusion to the standard mapping — today that covers
  `emergency`, `triage` **and `observation`**.

  **Intake-only, and why that is complete.** Anchoring on the first segment counts one row
  per arrival. Tamanu encounters never transition from `admission` back into an ED-type
  phase — admission is a terminal state reached *via* an ED phase, not before one — so any
  encounter that ever has an ED-type segment has one as its first segment. The intake filter
  therefore already captures every admitted-via-ED encounter; `ed_attendance_admitted` only
  *labels* those rows, it never admits new ones. Conversely an encounter that starts
  elsewhere (e.g. `clinic`) and passes through an ED-type segment later does not count —
  that is intra-hospital movement, not an arrival.
- **BL-004 (sex + age band):** `sex` is `clinical__person.gender_source_value`. Age in whole
  years at the attendance date is computed from `year_of_birth`/`month_of_birth`/
  `day_of_birth` and banded by `age_group__who_primary_classification` (see its docstring
  for boundaries and provenance). The join to `clinical__person` is an **inner** join —
  `bases/patients` excludes soft-deleted and merged-away patients, so an attendance whose
  patient was later deleted or merged is excluded entirely rather than counted with blank
  demographics.
- **BL-005 (admitted outcome):** `ed_attendance_admitted` counts attendances whose
  encounter's **visit-level** OMOP concept is **262** ('Emergency Room and Inpatient
  Visit'), read from `clinical__visit_occurrence`. Per that model's BL-002, 262 is assigned
  to an `admission` encounter whose history contains an `emergency`, `triage` or
  `observation` phase — precisely "arrived via the ED, ended up an inpatient".

  262 exists **only** at visit grain: `clinical__visit_detail` never carries it, because 262
  is reachable in `map__omop_visit_type` only through the synthetic
  `admission_from_emergency` local code, which no `encounter_type` equals. Hence the join to
  `clinical__visit_occurrence`.

  That join is **inner**, which is a real (if currently dormant) exclusion: a `vo` row exists
  only if the encounter's *current* `encounter_type` is covered by `map__omop_visit_type`,
  and that can differ from the intake segment's type. This is the same schema-drift risk as
  everywhere else the map is used, already guarded by `clinical__visit_occurrence`'s own
  completeness test and by `data_test__map__omop_visit_type_coverage` upstream of it.
- **BL-006 (`ed_admission_rate` is not additive):** the rate is
  `round(100.0 * admitted / attendances, 1)`, computed from the same grouping as the two
  counts so it is internally consistent with them. It is a **proportion**: summing it across
  `sex`, age band or facility is meaningless. A consumer aggregating to a coarser grain
  must re-derive it from `ed_attendance_admitted / ed_attendance`. It is registered anyway —
  rather than left to each visual — so the definition is stated once; the registry carries
  its numerator and denominator descriptions. Emitted only where the denominator is
  non-zero, which by construction it always is.
- **BL-007 (facility attribution):** `facility_id` is the facility of the intake segment's
  location, resolved by joining `bases/locations` on
  `clinical__visit_detail.care_site_id` (which is the segment's `location_id` — see that
  model's BL-006). The join is **inner**: an encounter whose location does not resolve is
  excluded rather than attributed to a NULL facility, since every consumer of these metrics
  aggregates by facility. In practice encounters always carry a location, so a miss means
  the location was soft-deleted.

  Area (`location_group`) is **not** a disaggregation here. It was one on
  `ds__emergency_visit`, but areas are sparse in Tamanu and ED-specific area reporting was
  not asked for; a consumer needing it joins `bases/locations` → `bases/location_groups`
  itself, as `ds__emergency_visit` BL-003 did.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, period_start, facility_id, sex, age_group__who_primary_classification)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and one of the three registered ids | BL-001 | dbt `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | dbt `relationships` (`error`) |
| AC-004 | `period_start` and `period_end` are `not_null` | BL-002 | dbt `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'month'` | BL-002 | dbt `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` | BL-006 | dbt `not_null` |
| AC-007 | `facility_id` is `not_null` | BL-007 | dbt `not_null` |

## Registry entry

Three rows in `csv/metric_definitions.csv` — `ed_attendance`,
`ed_attendance_admitted`, `ed_admission_rate` — all `kind: metric`,
`subject_grain: encounter`,
`disaggregations: facility_id,sex,age_group__who_primary_classification`,
`status: approved`, `spec_path` pointing here.

The disaggregation names the age classification, so
`assert__metric_definitions__disaggregations` admits
`age_group__who_primary_classification` alongside the generic `age_group` the pre-existing
rows use.

The registry is the list of **standard** metrics the product works with, so no rationale
there names a deployment. The national-alignment question is a deployment concern and lives
here as OQ-001, not in the registry — the rationales say "pending alignment with the
deploying country's national HMIS definition".

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment: ED inclusion, presentation date, location (BL-003, BL-007) |
| `clinical__visit_occurrence` | `clinical/` | Visit-level concept 262 for the admitted outcome (BL-005) |
| `clinical__person` | `clinical/` | Sex and birth date for age at attendance (BL-004) |
| `locations` | `bases/` | `facility_id` of the intake segment's location (BL-007) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |
| `age_group__who_primary_classification` | `macros/` | Age banding (BL-004) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table `tamanu_qos__emergency_care`, backing the Queen of Sheba Emergency → ED attendances card (MAUI-6694) |

Two things a consumer of this model has to get right, both of which follow from the D5
wide format rather than from anything ED-specific:

- **Always filter `metric_id`.** All three indicators share the single `value_numeric`
  column, so a query that does not pin `metric_id` sums unlike things.
- **`period_start` is a `date`, and a consumer may not be able to take it as one.** Over a
  JSON boundary a Postgres `date` is a hazard: node-postgres parses it into a JS `Date` at
  *local* midnight, so serialising to UTC moves the first of a month into the previous
  month. The Tupaia data table therefore renders it as `'YYYY-MM-DD'` text
  (`tupaia-data-product` `Dataset._from_clause`); that is a transport concern and is fixed
  at that boundary, not here — this model stays typed for the warehouse.

## Related

| Artefact | Relationship |
|---|---|
| `ds__emergency_visit` | **Superseded by this model.** Same attendance definition, previously as a standalone dataset |
| `models/datasets/standard/ds__encounters_emergency.sql` | Report-layer emergency dataset at triage grain, with PII. Carries `triages` detail (arrival/triage/closed times, score) that a future waiting-time or triage-category metric would build on |
| `metric__hivtb_standard_indicators`, `metric__mental_health_sessions` | Reference implementations of the D5 wide format (in deployment repos) |
| MAUI-6694 | Queen of Sheba Hospital, Ghana — Hospital Administration → Emergency → "ED attendances" |

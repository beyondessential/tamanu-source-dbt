# dbt Model Spec: `metric__encounter_diagnosis` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__encounter_diagnosis` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-009) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6836](https://linear.app/bes/issue/MAUI-6836/tupaia-morbidity-dashboard-metric-diagnosis-top-diagnoses-condition) |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `encounter_diagnosis`: one row per recorded encounter diagnosis, at day
resolution. The first `metric__` model over `clinical__condition_occurrence`.

## Purpose

Morbidity at a Tamanu facility -- what clinicians are diagnosing, and how that changes over
time.

| `metric_id` | Unit | Measures |
|---|---|---|
| `encounter_diagnosis` | count | Recorded encounter diagnoses (always 1 per row) |

**Clinical context.** `metric__emergency_visit` already carries a *principal* diagnosis per ED
attendance, which answers casemix for one department and counts each attendance once. This
metric is the general morbidity view: every diagnosis, in every department, including the
secondary and comorbid ones an encounter records alongside its principal.

It counts diagnosis events, not people. A patient seen twice for the same condition
contributes two rows -- the question it answers is how much of a condition is being
diagnosed, not how many people have it.

**Who reads it.** The Tupaia "Morbidity" dashboard, via a data table over this view.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | -- | Count of recorded encounter diagnoses |

No external body registers a plain count of recorded diagnoses. ICD-10 is a classification of
diagnoses rather than a definition of a morbidity count, and WHO's and AIHW's morbidity
reporting is built on cause-of-admission and cause-of-death groupings over a national coding
standard, not on what clinicians recorded. Deployments also differ in what they code
diagnoses with -- some real ICD-10, others a local reference-data list -- which is why the
metric emits the diagnosis as recorded and leaves grouping to the consumer (BL-006). Pending
alignment with the deploying country's national HMIS definition.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a diagnosis in any consumer that sums `value_numeric`.

`subject_id` is the OMOP condition occurrence id, matching the registry's `subject_grain:
diagnosis`, so `count(distinct subject_id)` and `sum(value_numeric)` agree.

## Output schema

D5 wide format, plus seven disaggregation columns and one measure attribute.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `encounter_diagnosis`. FK -> `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Condition occurrence id. `not_null` (AC-008) |
| `period_start` | date | Date the diagnosis was recorded (BL-002) |
| `period_end` | date | Always NULL -- a diagnosis is point-in-time (BL-002, AC-009) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | The encounter's facility (BL-005). `not_null` (AC-007) |
| `encounter_type` | varchar(255) | The encounter's type (BL-005). `not_null` (AC-011) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `diagnosis_code` | varchar(255) | Reference-data code as recorded, never NULL (BL-007, AC-010) |
| `diagnosis` | varchar(255) | Readable name as recorded, never NULL (BL-007, AC-010) |
| `diagnosis_certainty` | varchar(255) | Certainty as recorded, never NULL (BL-007, AC-010) |
| `is_primary` | boolean | Principal-diagnosis flag. Nullable -- not every encounter ranks its diagnoses |
| `age_years` | integer | Age in whole years at the diagnosis, unbanded (BL-008). A measure, not a dimension |

## Data tables

The Tupaia data tables over this view are configured in `tupaia-data-product`, at
`tamanu/data_tables/` -- the filter types, the aggregation and any bands are the consumer's
vocabulary, not dbt's. `validate_data_tables.py` there checks each file against this
project's dbt manifest, so a column renamed here fails there at generate time rather than
emptying a dashboard.

The Tamanu-to-Tupaia facility crosswalk and any age banding are both left to that layer, and
so is any grouping of the diagnosis itself (BL-006). This model therefore carries no
`data_table_*` meta.

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (reporting period):** `period_start` is the date the diagnosis was recorded
  (`clinical__condition_occurrence.condition_start_date`) at `'day'` granularity, and
  `period_end` is NULL.

  A diagnosis is point-in-time. Tamanu records when a diagnosis was made, not when the
  condition resolved, so there is no period to close. AC-009 asserts the NULL as an invariant
  rather than as an end-after-start comparison, so a change that ever populates it flags for a
  deliberate revisit instead of passing on an empty row set.

  Every diagnosis is emitted as it happens; the model reads no clock, and a consumer needing
  whole periods applies its own date filter. A period with no diagnosis emits no row.
- **BL-003 (inclusion):** a row is an encounter diagnosis --
  `condition_type_source_value = 'encounter diagnosis'`.

  Diagnoses whose certainty is `disproven` or `error` are already excluded upstream by
  `bases/encounter_diagnoses`, so this model inherits that rule rather than restating it; a
  restatement here would drift the day the base changes.

  The program-registry branch of `clinical__condition_occurrence` is excluded. A condition
  tracked alongside an enrolment has no encounter behind it (that model's BL-008), so it
  carries neither a facility nor an encounter type, and counting it here would mix comorbidity
  tracking into a morbidity count. A consumer wanting those reads
  `clinical__condition_occurrence` directly.
- **BL-004 (one row per diagnosis):** `value_numeric` is always 1, so summing it counts
  diagnoses at every grain. An encounter with several diagnoses contributes one row each, and
  a patient diagnosed repeatedly contributes one row each time -- this counts diagnosis
  events, not distinct patients.
- **BL-005 (facility and encounter attribution):** both are resolved through the diagnosis's
  visit -- `visit_occurrence_id` to `clinical__visit_occurrence`, whose `care_site_id` joins
  `bases/locations` for `facility_id`, and whose `visit_source_value` is `encounter_type`.

  The joins are **inner**. A diagnosis whose location does not resolve is excluded rather than
  attributed to a NULL facility, and the join to the visit is what enforces BL-003's
  encounter-branch restriction, since the registry branch's `visit_occurrence_id` is NULL. The
  join to `clinical__person` is inner for the same reason as elsewhere: a diagnosis whose
  patient `bases/patients` excludes as soft-deleted or merged away is excluded rather than
  counted with blank demographics.

  Attribution is at **encounter** grain, not segment grain. `encounter_type` is the encounter's
  type as it now stands, which Tamanu updates in place as the encounter progresses -- so a
  diagnosis recorded during the emergency phase of an encounter later admitted is attributed to
  `admission`. A card filtering `encounter_type` therefore reads "diagnoses on encounters that
  ended as X", not "diagnoses recorded while the patient was in X". Segment-grain attribution
  off `clinical__visit_detail` would answer the latter (OQ-003).
- **BL-006 (grouping is the consumer's to apply):** `diagnosis_code` and `diagnosis`
  are emitted raw and ungrouped.

  Classifying either into an ICD-10 chapter, a block or a national grouping is a presentation
  choice a deployment may set differently -- and deployments differ in whether the code is
  ICD-10 at all, so a grouping applied here would be meaningless for the ones it is not. A
  deployment wanting a grouping applies `macros/diagnosis__icd10_chapter.sql` (or its own)
  over `diagnosis_code` in its own model, the same division as `metric__emergency_visit`
  BL-013.
- **BL-007 (the recorded-diagnosis columns are never NULL):** `diagnosis_code`,
  `diagnosis` and `diagnosis_certainty` coalesce to `'Not recorded'`;
  `diagnosis` falls back to the code before that label.

  Tupaia exposes all three as array filters, and an array filter drops a NULL row -- a
  diagnosis with no code, name or certainty would silently disappear from a chart rather than
  show as unknown. Asserted by AC-010.

  The certainty coalesce is defensive rather than reachable: `bases/encounter_diagnoses`
  filters `certainty not in ('disproven', 'error')`, and `NULL not in (...)` is NULL, so a
  diagnosis with no certainty is already excluded from the population (OQ-001). AC-010b
  therefore passes trivially today and exists to catch that filter changing.

  `is_primary` is exempt. It is a boolean, so `'Not recorded'` is not available to it, and
  NULL there means the encounter did not rank its diagnoses -- a row an array filter set to
  the principal diagnosis *should* drop, because an unranked diagnosis is not a principal
  one. Losing it from that filter is the intended reading, not a silent disappearance.
- **BL-008 (age is the consumer's to band):** `age_years` is age in whole years at the
  diagnosis date, emitted raw and unbanded. An age classification -- WHO primary bands,
  five-year bands, a national HMIS grouping -- is a presentation choice a deployment may set
  differently, so `age_years` is a **measure, not a dimension**: absent from the registry's
  disaggregations, banded (if at all) by the data table declaring it, in `tupaia-data-product`
  (same convention as `metric__outpatient_visit` BL-004).
- **BL-009 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml` (shared with
  every model under `models/metrics/`).

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `encounter_diagnosis` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-004 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-005 | `not_null` |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | `period_end` is always NULL | BL-002 | `dbt_expectations.expect_column_values_to_be_null` |
| AC-010 | `diagnosis_code`, `diagnosis` and `diagnosis_certainty` are `not_null` | BL-007 | `not_null` |
| AC-011 | `encounter_type` is `not_null` | BL-005 | `not_null` |

## Registry entry

One active row -- `encounter_diagnosis`, `kind: metric`, `subject_grain: diagnosis`, `status: approved`,
`spec_path` pointing here, with disaggregations `facility_id`, `encounter_type`, `sex`,
`diagnosis_code`, `diagnosis`, `diagnosis_certainty`, `is_primary`.

Every disaggregation is in the allowlist in `assert__metric_definitions__disaggregations`,
which keeps the registry and the model from drifting.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__condition_occurrence` | `clinical/` | The diagnosis itself: inclusion, date, code, name, certainty, primary flag (BL-003, BL-006, BL-007) |
| `clinical__visit_occurrence` | `clinical/` | The encounter behind the diagnosis: location and encounter type (BL-005) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-008) |
| `locations` | `bases/` | Facility id of the encounter's location (BL-005) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table over this view, backing the morbidity card set |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   day-resolution dates, so a monthly card applies its own month bucketing and filters the
   current month itself.
3. **Band `age_years` itself.** No band set is emitted here.
4. **Translate `facility_id`.** It is the Tamanu id, not a consumer-specific one -- for
   Tupaia, the crosswalk to a Tupaia entity code is joined at the data table.
5. **Group the diagnosis itself, if it wants a grouping.** The code and name are as recorded.
   Check what the deployment actually codes diagnoses with before applying an ICD-10 grouping
   -- more than one deployment uses a local code list.
6. **Decide whether to filter `is_primary`.** Unfiltered, an encounter with several diagnoses
   contributes several rows; filtered to primary, each encounter counts once.

## Related

| Artefact | Relationship |
|---|---|
| `clinical__condition_occurrence` | The upstream this metric aggregates; also holds the program-registry conditions BL-003 excludes |
| `metric__emergency_visit` | Carries the ED principal diagnosis for casemix on one department; this metric is the general morbidity view. Shares BL-013's "grouping is the deployment's" rule |
| `metric__outpatient_visit` | Same registry pattern and conventions -- the reference this model was built from |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | `bases/encounter_diagnoses` filters `certainty not in ('disproven', 'error')`, and `NULL not in (...)` is NULL, so a diagnosis with no certainty recorded is excluded from the morbidity count entirely. Should the base admit it with `or ed.certainty is null`? | Maui team | - |
| OQ-002 | `clinical__visit_occurrence` inner-joins `map__omop_visit_type`, so a diagnosis on an encounter whose type is not in that map is absent from this metric. The map covers all eight current Tamanu types; nothing in CI would catch a ninth. Worth a singular test reconciling this model against the encounter branch of `clinical__condition_occurrence`? | Maui team | - |
| OQ-003 | Should `encounter_type` and `facility_id` be attributed at segment grain off `clinical__visit_detail` (the `metric__outpatient_visit` BL-006 pattern) rather than at encounter grain, so an emergency-phase diagnosis on an admitted encounter reads as `emergency`? | Maui team | - |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-25 | Maui team | Initial spec and implementation |

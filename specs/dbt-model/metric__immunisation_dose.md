# dbt Model Spec: `metric__immunisation_dose` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__immunisation_dose` (2 registered indicators) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.57`, forward-ported) |
| **Linear issue** | [MAUI-6808](https://linear.app/bes/issue/MAUI-6808) (initial), [MAUI-7034](https://linear.app/bes/issue/MAUI-7034) (BL-009 to BL-016) |
| **Created** | 2026-10-20 (the model shipped in MAUI-6808 without this file; its clauses are recorded here as implemented) |
| **Last updated** | 2026-10-20 |

Canonical definition for `immunisation_dose` — one row per vaccine dose given, recorded in Tamanu —
and `immunisation_recipient` — the people who received each dose, as each person's first record
of it (BL-014).

## Purpose

Deployment-neutral count of vaccine doses given — the numerator of an immunisation coverage
indicator, disaggregated by antigen, dose position, age, sex, facility, the patient's village, the
scheduled vaccine and the location group it was given in.

**Who reads it.** Tupaia immunisation dashboard cards through a data table over this view —
the standard immunisation product (Tokelau, Queen of Sheba), and Tuvalu's typhoid, routine and
COVID-19 dashboards (MAUI-7034), which need the patient, vaccine, location group and raw ages
BL-009 to BL-012 add.

| `metric_id` | Counts | Use for |
|---|---|---|
| `immunisation_dose` | Every dose record | Activity: doses given by facility, month, antigen |
| `immunisation_recipient` | Each person once per scheduled dose, at their first record of it | Coverage: people who received a dose over a target population |

**Why a second `metric_id`.** WHO's coverage numerators (SMART Immunizations DAK Annex C,
WUENIC) count immunization *events*, which equals "people who received the dose" only when each
dose is recorded once. Tamanu data carries repeat and duplicate records — Tuvalu's typhoid campaign
has 6,381 dose records for 6,310 people, including the same dose entered at two sites on one day —
so `immunisation_recipient` removes them. It is a `where` subset of the same rows, the same pattern
as `metric__birth`'s subset `metric_id`s, so it shares this model.

**Sibling.** `metric__immunisation_refusal` counts attempts recorded as not given, with the same
disaggregation shape — see Open questions for why it is a separate metric.

## Definition sources

| Element | `definition_source` | Concept |
|---|---|---|
| `immunisation_dose` | `WHO_UNICEF_WUENIC` | WHO/UNICEF administrative coverage method: doses administered per antigen, by age cohort, as the numerator of a coverage ratio |
| `immunisation_recipient` | `BES` | The same numerator with each person counted once per scheduled dose — a BES composition over the WHO event count, not a WHO-defined measure |

Numerator-only. No population or catchment estimate exists in Tamanu, so a coverage percentage is
formed downstream against an externally supplied population.

## Grain

**One row per `(metric_id, subject_id)`**, asserted by AC-001 at `error` severity. `subject_id` is
the dose's `clinical__drug_exposure.drug_exposure_id` — the underlying `vaccine_administrations`
id — so a patient given two vaccines in one encounter yields two rows. An `immunisation_recipient`
row reuses the `subject_id` of the dose it keeps, and is also one row per person per scheduled dose
(AC-017).

## Output schema

D5 wide format, plus disaggregations and measures.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | `immunisation_dose` or `immunisation_recipient` (BL-014). FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — the standard definition |
| `subject_id` | varchar(255) | The dose id (grain). `not_null` (AC-008) |
| `period_start` | date | Dose date (BL-002) |
| `period_end` | date | Equal to `period_start` (BL-002) |
| `period_granularity` | text | Constant `'day'` (AC-005) |
| `value_numeric` | numeric | Always `1` (BL-003, AC-006) |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar(255) | Facility of the dose's own location, else its encounter's (BL-004). `not_null` (AC-007) |
| `sex` | varchar(255) | Patient's `clinical__person.gender_source_value` |
| `disease` | text | Antigen, `'Not recorded'` when blank (BL-005) |
| `age_group__who_epi_schedule` | text | EPI cohort banded in months (BL-006) |
| `dose_label` | varchar(255) | Schedule dose position, `'Not recorded'` when blank (BL-007) |
| `patient_location_id` | varchar(255) | Patient's home village, nullable (BL-008) |
| `person_id` | varchar(255) | Patient's Tamanu id (BL-009). `not_null` (AC-014) |
| `vaccine_id` | varchar(255) | Scheduled vaccine's drug id, nullable (BL-010) |
| `vaccine_label` | varchar(255) | Scheduled vaccine's label, `'Not recorded'` when no schedule (BL-010, AC-015) |
| `vaccine_category` | varchar(255) | Schedule category, `'Not recorded'` when no schedule (BL-010, AC-016) |
| `location_group_id` | varchar(255) | Location group of the dose's location, nullable (BL-011) |
| `age_days` | integer | Age at the dose in whole days, a measure (BL-012) |
| `age_years` | integer | Age at the dose in whole completed years, a measure (BL-012) |
| `facility_source` | text | `'dose location'` or `'encounter location'` (BL-016, AC-019) |
| `is_given_elsewhere` | boolean | Recorded as given elsewhere; counted, flagged (BL-016, AC-020) |

## Data tables

Tupaia data tables over this view are configured in `tupaia-data-product` at
`tamanu/data_tables/` (e.g. `immunisation_dose__standard.yml`), so this model carries no
`data_table_*` meta. A data table counting people uses `aggregation: count_distinct` on
`person_id` and never exposes it as a column (BL-013).

## Business logic

- **BL-001 (inclusion):** one row per `clinical__drug_exposure` row of type `vaccination` (already
  `status = 'GIVEN'`) whose patient resolves in `int__vaccine_administration_attributes`; a dose
  whose patient is excluded there (deleted, merged, test) is excluded.
- **BL-002 (reporting period):** `period_start` and `period_end` are both the dose date, at
  `'day'` granularity.
- **BL-003 (count):** `value_numeric` is `1` per row, so a sum is a dose count at every grain.
- **BL-004 (facility):** `facility_id` and `location_group_id` come from the dose's own location,
  else its encounter's location, and no dose is excluded for having no location of its own or for
  being given elsewhere.
- **BL-005 (antigen):** `disease` is `vaccine_administrations.disease`, `'Not recorded'` when
  blank.
- **BL-006 (EPI age cohort):** `age_group__who_epi_schedule` bands age in months at the dose date
  with `age_group__who_epi_schedule()`, `'Unknown age'` with no date of birth.
- **BL-007 (dose position):** `dose_label` is the schedule's dose label, `'Not recorded'` for an
  ad hoc dose with no schedule.
- **BL-008 (patient village):** `patient_location_id` is the patient's own
  `clinical__person.location_id`, passed through and left NULL when the record carries none.
- **BL-009 (patient):** `person_id` is the patient of the dose's encounter, never NULL, so a
  consumer can count people with a distinct count rather than doses.
- **BL-010 (scheduled vaccine):** `vaccine_id`, `vaccine_label` and `vaccine_category` are the
  schedule's drug id, label and category; `vaccine_id` stays NULL and the label and category read
  `'Not recorded'` for an ad hoc dose with no schedule.
- **BL-011 (location group):** `location_group_id` is the location group of the dose's recorded
  location as a Tamanu id, NULL when the location belongs to no group.
- **BL-012 (raw age):** `age_days` and `age_years` are the patient's age at the dose date in whole
  days and whole completed years, unbanded and NULL with no date of birth.
- **BL-013 (classification):** the model is `classification: restricted` and `pii: false`, like
  `metric__birth` and `metric__death`, because `person_id` beside the event date, age and village
  can identify a patient in a small deployment.
- **BL-014 (recipients):** `immunisation_recipient` rows are the subset of the dose rows that is
  each person's first record of each scheduled dose — `vaccine_id` with `dose_label`, or `disease`
  for a dose with no `vaccine_id` — with every column unchanged.
- **BL-015 (first record):** the earliest `period_start` wins, and on a same-day tie the lowest
  `subject_id`, so the record kept is stable from one build to the next.
- **BL-016 (source flags):** `facility_source` is `'dose location'` or `'encounter location'` by
  where BL-004 took the location, and `is_given_elsewhere` is the dose's given-elsewhere flag
  (false when unset), so a consumer can exclude or label those doses.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and one of `immunisation_dose`, `immunisation_recipient` | registry | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions` | registry | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and `1` | BL-003 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | The projection resolves as specified: inclusion, period, every fallback and every pass-through, including the BL-009 to BL-012 fields | BL-001, BL-002, BL-005–BL-012 | unit test `ac_009_metric__immunisation_dose_projection`, plus `period_end >= period_start` |
| AC-010 | `disease` is `not_null` | BL-005 | `not_null` |
| AC-011 | `period_end` is `not_null` | BL-002 | `not_null` |
| AC-012 | `age_group__who_epi_schedule` is `not_null` | BL-006 | `not_null` |
| AC-013 | `dose_label` is `not_null` | BL-007 | `not_null` |
| AC-014 | `person_id` is `not_null` | BL-009 | `not_null` |
| AC-015 | `vaccine_label` is `not_null` | BL-010 | `not_null` |
| AC-016 | `vaccine_category` is `not_null` | BL-010 | `not_null` |
| AC-017 | `immunisation_recipient` is one row per `(person_id, coalesce(vaccine_id, disease), dose_label)` | BL-014 | `dbt_utils.unique_combination_of_columns` (`error`, `where metric_id = 'immunisation_recipient'`) |
| AC-018 | Recipients keep the first record and drop a later one, keep each dose of a multi-dose vaccine, keep ad hoc doses per antigen, and break a same-day tie on the lowest `subject_id` | BL-014, BL-015 | unit test `ac_018_metric__immunisation_dose_recipient` |
| AC-019 | `facility_source` is `not_null` and one of `'dose location'`, `'encounter location'` | BL-016 | `not_null` + `accepted_values` |
| AC-020 | `is_given_elsewhere` is `not_null` | BL-016 | `not_null` |
| AC-021 | Every given vaccination whose patient is included is an `immunisation_dose` row, whatever its location and whether given elsewhere | BL-001, BL-004 | singular test `data_test__metric__immunisation_dose` (`error`) |

## Registry entry

`immunisation_dose` and `immunisation_recipient` in `documentations/metrics/immunisation.yml`:
`kind: metric`, `subject_grain` `dose` and `patient_dose` respectively, `spec_path` pointing here,
the same disaggregations. `disaggregations: facility_id, sex, disease,
age_group__who_epi_schedule, dose_label, patient_location_id, vaccine_id, vaccine_label,
vaccine_category, location_group_id, facility_source, is_given_elsewhere`. `person_id`,
`age_days` and `age_years` are not disaggregations — an aggregation key and two measures. Every disaggregation is on the allowlist in
`data_tests/source/assert__metric_definitions__disaggregations.sql`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__drug_exposure` | `clinical/` | Dose identity and date (BL-001, BL-002) |
| `int__vaccine_administration_attributes` | `intermediate/` | Every attribute (BL-004–BL-012, BL-016), shared with `metric__immunisation_refusal` |
| `vaccine_administrations`, `vaccine_schedules`, `locations`, `encounters`, `reference_data` | `bases/` | Read by the intermediate model |
| `clinical__person` | `clinical/` | Sex, village and date of birth (BL-006, BL-008, BL-012) |
| `metric_definitions` | root | Registry (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Immunisation data tables and cards |

A consumer filters to one `metric_id` and sums `value_numeric` — `immunisation_dose` for doses,
`immunisation_recipient` for people; summing both counts a dose twice. A recipient row sits at
the person's first record, so a card's rows by facility, village or month add up to its total.
It bands `age_days` / `age_years` itself, maps `facility_id`, `patient_location_id` and
`location_group_id` to its own entities, and respects `classification: restricted`.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Why refusals are a separate metric: a `status` disaggregation here would put doses and refused attempts into one `value_numeric` with two meanings, so `metric__immunisation_refusal` is its own `metric_id` with the same shape. Resolved — recorded for the refusal model's reference | @maui-team | resolved |

## Related

| Artefact | Relationship |
|---|---|
| `metric__immunisation_refusal` | Sibling: not-given attempts, same disaggregations plus reason |
| `int__vaccine_administration_attributes` | Shared attribute model |
| MAUI-7034 | Tuvalu immunisation dashboards need BL-009 to BL-012 |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-20 | Maui team | Spec written for the model shipped in MAUI-6808, recording BL-001 to BL-008 as implemented. Added BL-009 to BL-013 (MAUI-7034): `person_id`, `vaccine_id` / `vaccine_label` / `vaccine_category`, `location_group_id`, `age_days` / `age_years`, and the move to `classification: restricted`; AC-014 to AC-016 and AC-009 extended |
| 2026-10-21 | Maui team | BL-014, BL-015: `immunisation_recipient`, each person's first record of each scheduled dose, emitted from this model as a second `metric_id` (MAUI-7034) — the WHO event-count numerator with repeat and duplicate records removed. AC-002 extended, AC-017 and AC-018 added |
| 2026-10-21 | Maui team | BL-004 rewritten (MAUI-7034): the location falls back to the encounter's, and doses with no location of their own or given elsewhere are kept. The old inner join on the dose's own location dropped ~34,600 of Tuvalu's ~70,700 given doses — older and migrated records held the location only on the encounter — where the legacy pipeline counted them. BL-016: `facility_source` and `is_given_elsewhere`. BL-001 restated (only the patient now excludes). AC-019 to AC-021 added |

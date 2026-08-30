# dbt Model Spec: `metric__birth` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__birth` (4 registered indicators) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else (BL-011) |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (branch line `2.60`) |
| **Linear issue** | [MAUI-6838](https://linear.app/bes/issue/MAUI-6838) |
| **Created** | 2026-08-26 |
| **Last updated** | 2026-08-26 |

Canonical definition for `birth`, `low_birth_weight`, `preterm_birth` and `low_apgar_5min`: one
row per live birth registered in Tamanu, at the newborn's `patient_id`.

## Purpose

Deployment-neutral delivery and newborn-outcome activity — deliveries by type, weight, attendant
and place, and the newborn outcome flags that make up "neonatal outcomes" from data Tamanu
captures as structured fields.

| `metric_id` | Unit | Measures |
|---|---|---|
| `birth` | count | Every registered live birth (always 1 per row; the denominator for the three subsets below) |
| `low_birth_weight` | count | Births with `birth_weight < 2.5` kg |
| `preterm_birth` | count | Births with `gestational_age_estimate < 37` completed weeks |
| `low_apgar_5min` | count | Births with `apgar_score_five_minutes < 7` |

**Who reads it.** Tupaia "Maternity and newborn" dashboard cards, via a data table over this
view. Deployment-neutral — every deployment holds `patient_birth_data`, so any deployment
materialising this model gets those cards from configuration alone. Which deployments have
adopted it is tracked on each deployment's own issue, not here.

**Why one model, four `metric_id`s.** All four share the newborn-registration grain and the same
base — `low_birth_weight`, `preterm_birth` and `low_apgar_5min` are each a `where` subset of
`birth`. Splitting them into separate models would triplicate the join to
`patients`/`clinical__person` for no benefit.

**Why subsets are `metric_id`s, not boolean disaggregations.** `ed_visit` splits its admitted
subset with an `is_admitted` boolean column instead. That works there because admission status is
always known; here each subset depends on a measure (`birth_weight`, `gestational_age_estimate`,
`apgar_score_five_minutes`) that is frequently unrecorded, and a boolean would have to collapse
"not low birth weight" and "weight not recorded" into one `false` — silently inflating the
denominator of any rate a consumer formed from it.

**What this model does not cover.** Antenatal care. Tamanu holds no deployment-neutral base for
it, so `metric__antenatal_contact` and `metric__antenatal_booking` are defined canonically but
implemented per deployment, against whichever antenatal form that deployment records. A
deployment that records no antenatal data has neither metric available.

## Definition sources

The registry's `definition_source` field takes a controlled vocabulary
(`models/metric_definitions.yml`), so it carries the standard's registry name and this table
carries the specific document.

| Element | `definition_source` | Concept |
|---|---|---|
| `birth` (population, disaggregations) | `WHO_CORE_100` | Skilled-birth-attendance family of indicators (SDG 3.1.2) for the population; delivery-mode, attendant and place vocabulary aligned to the AIHW National Perinatal Data Collection |
| `low_birth_weight` | `WHO_CORE_100` | Low birth weight prevalence is a 100-core-list entry; the threshold follows the WHO/UNICEF joint low-birthweight estimates — born weighing less than 2,500 g (2.5 kg) |
| `preterm_birth` | `BES` | Threshold follows the WHO preterm definition — born before 37 completed weeks — but preterm birth *rate* is not itself a 100-core-list entry, so this is a BES composition over a WHO threshold rather than an implementation of a registered indicator |
| `low_apgar_5min` | `BES` | Threshold follows WHO Newborn Health guidance's low Apgar score at 5 minutes, a marker of neonatal distress. No METeOR-style registered code exists for it, unlike the AIHW-anchored `ed_visit` concepts, and it is not a 100-core-list entry — a BES composition over a clinical convention |

None of these publish a routine facility-activity *count* BES can implement directly; each is a
BES composition over the named population/threshold, the same relationship `ed_visit` has to
AIHW's METeOR object classes. Pending alignment with the deploying country's national HMIS
definition, per every other metric in this registry.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity.

`subject_id` is the newborn's Tamanu `patient_id`, matching the registry's `subject_grain:
patient` — `patient_birth_data` is a patient-level table with no encounter concept, one row per
birth registration. A twin birth is two `patient_birth_data` rows (one per baby), so grain
uniqueness holds without a fan-out guard; AC-001 is the backstop if that assumption ever breaks.

## Output schema

D5 wide format, plus six disaggregation columns and four measure attributes.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of `birth`, `low_birth_weight`, `preterm_birth`, `low_apgar_5min`. FK → `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL — this is the standard definition |
| `subject_id` | varchar(255) | Newborn's `patient_id` (BL-013). `not_null` (AC-008) |
| `period_start` | timestamp | Birth date/time, falling back to registration date (BL-003) |
| `period_end` | timestamp | Equal to `period_start` — a birth is a point event, not a stay (BL-003) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (AC-006) |
| `value_boolean` | boolean | NULL — this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Birth facility, as recorded (BL-010). Nullable — a home or other-place birth has none |
| `sex` | varchar(255) | Newborn's `clinical__person.gender_source_value` (BL-004) |
| `birth_delivery_type` | text | Raw source value — `normal_vaginal_delivery`, `breech`, `emergency_c_section`, `elective_c_section`, `vacuum_extraction`, `forceps`, `other` (BL-009). Ungrouped. Never NULL — unrecorded reads `'Not recorded'` (AC-015) |
| `attendant_at_birth` | text | Raw source value — `doctor`, `midwife`, `nurse`, `traditional_birth_attentdant` [sic, matches the source data], `other` (BL-009). Ungrouped. Never NULL — unrecorded reads `'Not recorded'` (AC-015) |
| `registered_birth_place` | text | Raw source value — `health_facility`, `home`, `other` (BL-009). Ungrouped. Never NULL — unrecorded reads `'Not recorded'` (AC-015) |
| `birth_type` | text | `single` or `plural` (BL-009). Never NULL — unrecorded reads `'Not recorded'` (AC-015) |
| `birth_weight` | numeric | Kilograms, 1 dp as recorded. A measure, not a dimension (BL-014) |
| `gestational_age_estimate` | numeric | Completed weeks as recorded. A measure, not a dimension (BL-014) |
| `apgar_score_five_minutes` | integer | As recorded. A measure, not a dimension (BL-014) |

## Data tables

The Tupaia data table over this view is configured in `tupaia-data-product`, at
`tamanu/data_tables/`, per the standard division of labour (filter types, aggregation and bands
are the consumer's vocabulary; only the model name points at dbt). `tupaia-data-product`'s
`validate_data_tables.py` checks the file against this project's dbt manifest, so this model
carries no `data_table_*` meta.

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/maternity.yml`, asserted by AC-003 at `error` severity — the registry
  ships in the same repo and release as the model, so there is no version-skew reason to hold the
  test at `warn`.
- **BL-002 (inclusion):** every non-deleted, non-test-patient row of `bases/patient_birth_data`,
  inner-joined to `bases/patients` (which drops soft-deleted, merged and test patients) and to
  `clinical__person` for sex. No visit or encounter concept applies — `patient_birth_data` is a
  standalone birth-registration table, not visit-scoped, so this model has no OMOP visit
  dependency at all.
- **BL-003 (reporting period):** `period_start` is
  `date_trunc('day', coalesce(date_of_birth::timestamp, registration_date::timestamp))`.
  `period_granularity` is the constant `'day'`: Tamanu does not reliably capture time of birth,
  so day resolution is what the data actually supports.

  `birth_time` is deliberately **not** in that fallback chain, unlike
  `int__patient_birth_measurements`'s otherwise-identical chain, which needs minute resolution
  for the OMOP MEASUREMENT domain. At day granularity `date_of_birth + birth_time` truncates to
  the same day as `date_of_birth` alone, so including it would be dead code.

  `period_end` equals `period_start` — a birth is a point event with no duration, so there is no
  "open" state to signal with a NULL the way an encounter has one.
- **BL-004 (sex):** `sex` is the newborn's `clinical__person.gender_source_value`. The join is
  **inner**, so a birth whose patient record `bases/patients` excludes is excluded rather than
  counted with blank demographics — the same rule as `ed_visit` BL-004.
- **BL-005 (low birth weight, numerator only):** `low_birth_weight` is emitted only for rows where
  `birth_weight is not null and birth_weight < 2.5`. Per the WHO/UNICEF threshold. Rows with no
  recorded weight emit no `low_birth_weight` row and are **not** subtracted from `birth`'s count —
  a consumer computing a rate as `low_birth_weight / birth` therefore assumes birth weight is
  recorded uniformly; see § Consumers.
- **BL-006 (preterm birth, numerator only):** `preterm_birth` is emitted only for rows where
  `gestational_age_estimate is not null and gestational_age_estimate < 37`. Per the WHO preterm
  threshold, same numerator-only caveat as BL-005.
- **BL-007 (low Apgar, numerator only):** `low_apgar_5min` is emitted only for rows where
  `apgar_score_five_minutes is not null and apgar_score_five_minutes < 7`, per WHO Newborn Health
  guidance's threshold for a low Apgar score. Same numerator-only caveat as BL-005.
- **BL-008 (rates are the consumer's):** the model emits counts only; low-birth-weight rate,
  preterm-birth rate and low-Apgar rate are each `sum(value_numeric) filter (where metric_id =
  '<subset>') / sum(value_numeric) filter (where metric_id = 'birth')` at the consumer's grain.
  Per D5 "Rate scale" a rate is a 0–1 fraction, unrounded.
- **BL-009 (delivery/attendant/place disaggregations, ungrouped, never NULL):**
  `birth_delivery_type`, `attendant_at_birth`, `registered_birth_place` and `birth_type` pass
  through as the raw source value. Relabelling to a human-readable form (as `ds__births` does for
  a line list) is a presentation choice left to the consumer's data table, the same division of
  labour as `principal_diagnosis_code` in `ed_visit` BL-013.

  All four are nullable in `patient_birth_data` and all four are coalesced to `'Not recorded'`,
  asserted by AC-015 — the sibling metrics' convention (`ed_visit`'s `triage_score`,
  `metric__procedure`'s `procedure_code`, `inpatient_admission`'s
  `principal_diagnosis__icd10_chapter`). Tupaia's array filter drops NULL rows, so a raw NULL
  would silently remove the birth from a "by delivery type" or "by attendant" split, and the
  split would stop reconciling with the `birth` total — a card that quietly under-reports rather
  than one that visibly has a gap.

  **This is the opposite call to BL-010's `facility_id`, deliberately.** A NULL `facility_id`
  states something true about the birth — it did not happen at a Tamanu facility. A NULL delivery
  type states nothing about the birth, only about the record: the field was not filled in. The
  model fills what is merely unrecorded and preserves what is meaningful.
- **BL-010 (facility attribution, nullable, carried as recorded):** `facility_id` is
  `patient_birth_data.birth_facility_id` **as recorded**, and left **nullable** — unlike
  `ed_visit`'s inner-joined facility, a home or other-place birth genuinely has none, and dropping
  those rows would bias "deliveries by place" toward facility births, defeating the point of the
  disaggregation.

  The id is deliberately **not** resolved against `bases/facilities`. That base filters
  `deleted_at is null`, so a birth at a facility since retired would come back NULL from the join
  and fall into the home/other-place bucket — a data gap wearing the costume of a real home birth,
  which is exactly what the clause below promises a NULL here never is. The join bought nothing
  (it was a left join, so it filtered no rows) and cost the one guarantee this column makes. No placeholder is coalesced here; a NULL is presentation's to label (the same
  `unmatched_label` pattern the Tupaia facility crosswalk already uses in the consumer layer).
- **BL-011 (materialisation is env-aware):** `table` when `target.name` starts with `analytics`,
  `view` otherwise, on the `metrics:` block in `dbt_project.yml` — the existing repo-wide rule,
  unchanged by this model.
- **BL-012 (classification):** `pii: false` — no *direct* identifier is emitted: no name, no
  patient display id, no address or village, none of what `ds__births` carries and is flagged
  `pii: true` for. The newborn's date of birth **is** present, as `period_start`; `pii: false` is
  the repo's flag for direct identifiers, and a date of birth is a quasi-identifier (as
  `bases/patients` tags it), not a direct one.

  That quasi-identifier is precisely why the classification is `restricted`, inherited from
  `patient_birth_data`'s own `restricted` classification rather than downgraded to `internal`. A
  row carries a specific newborn's `subject_id`, birth date and facility; in a small deployment,
  or any facility with a low birth count, that combination can identify a specific mother and
  baby, which an anonymous encounter id in `ed_visit` cannot. The `pii` flag and the
  classification are doing different jobs here, and only the second one is load-bearing. **The line this sets.** Any consumer of this model inherits `restricted`
  handling; loosening it requires revisiting this clause, not just the consumer's own
  classification.
- **BL-013 (per-birth grain):** one row per birth, `subject_id` = the newborn's `patient_id`,
  `value_numeric` = literal `1` because the row *is* the birth.
- **BL-014 (measures are the consumer's to band):** `birth_weight`, `gestational_age_estimate`
  and `apgar_score_five_minutes` are continuous measures, absent from the registry's
  disaggregations. Banding them (a low-birth-weight severity split, a gestational-age band, an
  Apgar band) is a deployment concern set in the data table, the same division of labour as
  `age_years` in `ed_visit` BL-019.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-013 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and one of the four registered values | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-003 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'day'` | BL-003 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-008, BL-013 | `not_null` + `accepted_values` |
| AC-007 | `period_end` equals `period_start` | BL-003 | `dbt_utils.expression_is_true` |
| AC-008 | `subject_id` is `not_null` | BL-013 | `not_null` |
| AC-009 | `sex` is `not_null` | BL-004 | `not_null` |
| AC-010 | Every `low_birth_weight` row has `birth_weight < 2.5` | BL-005 | `dbt_utils.expression_is_true` |
| AC-011 | Every `preterm_birth` row has `gestational_age_estimate < 37` | BL-006 | `dbt_utils.expression_is_true` |
| AC-012 | Every `low_apgar_5min` row has `apgar_score_five_minutes < 7` | BL-007 | `dbt_utils.expression_is_true` |
| AC-013 | Subset membership matches the source predicate over the included population, both directions: every qualifying `birth` has its subset row, and every subset row has a `birth` row whose source measure meets the threshold | BL-002, BL-005–BL-007, grain | singular test |
| AC-014 | The D5 projection resolves as specified: both `period_start` fallbacks, `birth_time` ignored at day granularity, each threshold's boundary excluded, a NULL measure emitting no subset row, a facility-less birth keeping its row, a facility absent from `bases/facilities` keeping its id, and unrecorded disaggregations reading `'Not recorded'` | BL-003, BL-005–BL-007, BL-009, BL-010, BL-013 | unit test `ac_014_metric__birth_projection` |
| AC-015 | `birth_delivery_type`, `attendant_at_birth`, `registered_birth_place` and `birth_type` are each `not_null` | BL-009 | `not_null` × 4 |

AC-010 through AC-012 assert the thresholds against whatever rows a deployment holds; AC-014
asserts them against controlled rows at each boundary, since no deployment database guarantees a
birth at 2.5 kg, 37 weeks and Apgar 7.

**On AC-013's shape.** The three subsets are `where` filters over one shared CTE, so a test that
joins the model to itself is structurally incapable of failing and gives the criterion no
regression cover. The singular test therefore re-derives subset membership from
`patient_birth_data`'s measures over the model's own `birth` population, and compares both
directions. It bites if a subset is ever rebuilt on its own base, or if a threshold drifts from
BL-005–BL-007 — which is the change the criterion exists to catch.

## Registry entry

Four active rows in `documentations/metrics/maternity.yml` — `birth`, `low_birth_weight`,
`preterm_birth`, `low_apgar_5min` — each `kind: metric`, `subject_grain: patient`, `status:
approved`, `spec_path` pointing here, `variant_of: null`.
`disaggregations: facility_id,sex,birth_delivery_type,attendant_at_birth,registered_birth_place,
birth_type` on every row (identical across the four, since they share a base).

Every disaggregation must be added to the allowlist in
`data_tests/source/assert__metric_definitions__disaggregations.sql`.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `patient_birth_data` | `bases/` | Birth record: delivery type, attendant, place, weight, gestational age, Apgar (BL-002–BL-010) |
| `patients` | `bases/` | Inclusion filter and date of birth for the reporting-period fallback (BL-002, BL-003) |
| `clinical__person` | `clinical/` | Sex (BL-004) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table(s) backing the "Maternity and newborn" dashboard cards. The templates are metric-agnostic, so a deployment adopting this model configures the cards rather than authoring them |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric` per `metric_id`; `count(distinct subject_id)` is equally
   valid.
2. **Form a rate as `subset / birth`, never store it.** Per BL-008.
3. **Know the numerator-only caveat on `low_birth_weight`, `preterm_birth` and `low_apgar_5min`.**
   Each is a fraction of *recorded* values, not of every birth — a deployment with patchy weight
   or Apgar capture will understate its true rate if `birth`'s full count is used unadjusted as
   the denominator. A consumer wanting a stricter denominator emits its own count of births with
   the relevant measure recorded.
4. **Handle nullable `facility_id`.** Unlike `ed_visit`, a NULL here is a real "not at a Tamanu
   facility" case, not a data gap — an array filter dropping it will silently exclude home births
   from a "by place" split unless the consumer labels the NULL bucket explicitly.
5. **Respect `classification: restricted`.** Per BL-012.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether a "deliveries by maternal age" disaggregation is in scope for a later revision. This branch line carries `age_group__aihw_maternal_age`, so the banding is available; what is missing is the link to the mother — `patient_birth_data` is keyed on the newborn and reaches her only through nullable `patient_additional_data.mother_id`. Resolving that join is the prerequisite, not the macro | @maui-team | unscheduled |

## Related

| Artefact | Relationship |
|---|---|
| `metric__antenatal_contact` | Antenatal contact definition — no shared base, different subject grain, implemented per deployment |
| `metric__antenatal_booking` | Antenatal booking definition — no shared base, different subject grain, implemented per deployment |
| `int__patient_birth_measurements` | Same base (`patient_birth_data`), projects the OMOP MEASUREMENT domain instead of the D5 metric shape |
| `ds__births` | Report-layer birth line list at the same grain, with PII (mother/father, village) |
| `age_group__aihw_maternal_age`, `diagnosis__icd10_obstetric_block` | Maternity macros carried on this branch line. Neither is called by this model; both are available to a consumer's data table — to band maternal age once the mother link is resolved (OQ-001), or to group obstetric diagnoses |
| MAUI-6838 | Tupaia maternity and newborn dashboard: standard metric and visuals |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-26 | Maui team | Initial draft |
| 2026-08-30 | Maui team | BL-009: the four disaggregations coalesce to `'Not recorded'` (new AC-015) — a raw NULL was droppable by Tupaia's array filter. BL-010: `facility_id` carried as recorded rather than left-joined to `bases/facilities`, which turned a soft-deleted facility into an apparent home birth. BL-012: corrected the `pii: false` justification — the newborn's date of birth *is* emitted as `period_start`. AC-013 restated as a source-anchored, falsifiable check. Registry `subject_grain` corrected to `patient` |

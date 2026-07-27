# dbt Model Spec: MSF OCA HIV / TB / PMTCT Standard Indicators (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | MSF OCA HIV/TB/PMTCT Standard Indicators (suite of 24 `metric__` indicators) |
| **Type** | dbt model suite (canonical definitions) |
| **Layer** | `metric` (D5 wide format) |
| **Materialisation** | view |
| **Status** | `approved` (one interpretation pending MSF confirmation — see § Residual definitional cautions) |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | [MAUI-6626](https://linear.app/bes/issue/MAUI-6626/msf-kule-dhis2-standard-indicators-hivandtb-report) |
| **Created** | 2026-07-27 |
| **Last updated** | 2026-07-27 |

Canonical definitions for the 24 MSF OCA "Standard Indicators" (PMTCT / HIV-AIDS /
Tuberculosis) registered in `csv/metric_definitions.csv`. Implementations are
deployment-specific (see § Implementations). This spec governs the *definitions* —
what each indicator measures, output shape, semantic invariants. Implementation
details (which upstream models feed each, point-in-time reconstruction mechanics,
survey-column mappings, DHIS2 window/backfill vars, unit tests) live in the
deployment specs.

**BL numbering is shared with the MSF Kule implementation spec** (and with the
`-- BL-0xx` comments in `metric__hivtb_standard_indicators.sql`): BL-002 is
`pmtct_hiv_positive_delivering` in both, and so on. Keep them aligned so a code
comment resolves to the same clause in either spec.

## Purpose

**What this artefact measures.** 24 monthly PMTCT / HIV-AIDS / Tuberculosis
indicators from the MSF OCA "Standard Indicator Report", exported to DHIS2 in the
standard MSF datavalue format, at facility grain.

**Clinical context.** MSF HIV / PMTCT / TB programmes run within Tamanu (HIV
visit forms, PMTCT ANC / delivery / exposed-child forms, TB treatment and outcome
forms, and CD4 / viral-load / DNA-PCR lab results). 24 of the source sheet's 27
rows are in scope — 3 are excluded (2 sourced from a different DHIS2 dataset, 1
not relevant), see BL-000.

**Who reads it.** MSF OCA DHIS2 reporting, via the "MSF OCA Standard Indicator
Report" dataset, pushed monthly.

## Grain

`metric_id × period_start × facility_id`. No disaggregation dimensions — all 24
indicators emit at facility grain only, confirmed by MSF (no age/sex breakdown in
the DHIS2 dataset; the age-banded HIV/TB indicators are distinct `metric_id`s, not
a disaggregation of one).

## Output schema

D5 wide format — identical shape to `metric__mental_health_sessions`. Each
`metric__` view emits:

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | One of the 24 registered indicator slugs |
| `variant_id` | text | NULL on the standard definition |
| `subject_id` | uuid | NULL — pre-aggregated counts, not per-subject rows |
| `period_start` | date | First day of the reporting month |
| `period_end` | date | Last day of the reporting month |
| `period_granularity` | text | Constant `'month'` |
| `value_numeric` | numeric | Count for the month |
| `value_boolean` | boolean | NULL — not used by these indicators |
| `facility_id` | text | Facility associated with the metric — see BL-020 |

## Business logic

Definitional statements of what each indicator counts. Deployment mechanics (form
codes, upstream model choice, point-in-time reconstruction, DHIS2 window vars) are
out of scope here — see the deployment spec. Every count is of **distinct
subjects** at the indicator's registered `subject_grain` (patient, encounter, or
episode) unless stated otherwise.

- **BL-000 (scope):** 24 of the 27 source-sheet rows are in scope. Excluded: "HIV
  Total tested for HIV" and "HIV PLHIV newly tested HIV positive" (sourced from a
  separate DHIS2 laboratory dataset, not Tamanu) and "HIV New PLHIV referred to
  care" (out of scope for the deployment).
- **BL-001 (period window):** monthly reporting spine, always ending at the last
  *complete* calendar month; the current (incomplete) month is never emitted. Age,
  where relevant, is evaluated at the time of the qualifying visit/form/event (not
  current age). Every output row carries `metric_id` set to its registered
  identifier in `csv/metric_definitions.csv`.

### PMTCT (5 indicators)

- **BL-002 (`pmtct_hiv_positive_delivering`):** distinct women who delivered in an
  MSF facility during the reporting month, bucketed by delivery date; a woman with
  more than one delivery record in the month counts once. HIV-positive status is
  implied by enrolment in the PMTCT pathway (no separate HIV+ flag).
- **BL-003 (`pmtct_hiv_positive_delivering_on_art`):** the BL-002 cohort who were
  on ART — already on ART at ANC enrolment, or ART initiated at an ANC visit dated
  before the delivery.
- **BL-004 (`pmtct_hiv_exposed_babies_born_alive`):** distinct HIV-exposed infants
  with an initial exposed-child visit in the reporting month whose mother delivered
  in an MSF facility, where the initial visit is within 12 weeks of that delivery.
- **BL-005 (`pmtct_hiv_exposed_newborns_pep_72h`):** distinct HIV-exposed infants
  with an initial visit in the month recording PEP initiated within 72 hours, whose
  mother delivered in an MSF facility.
- **BL-006 (`pmtct_hiv_exposed_pcr_dna_done`):** distinct HIV-exposed infants with
  an initial DNA-PCR result finalised in the reporting month whose mother delivered
  in an MSF facility.

The three exposed-infant indicators (BL-004/005/006) share one denominator: the
mother delivered in an MSF facility.

### HIV / ART (12 indicators)

**Cohort gate.** The HIV-*visit* indicators (BL-007, BL-009, BL-012) and the
ever-started indicator (BL-008) are gated to HIV-cohort membership (patients ever
registered on the HIV registry) — they are "PLHIV …" indicators nesting under the
ever-started cohort. The **viral-load indicators (BL-010, BL-011) are *not*
cohort-gated** — they count any patient with a qualifying viral-load result. (In
practice VL testing is effectively HIV-only, so the gate is moot; the deployment
deliberately omits it, and the unit tests assert it with an empty cohort.) For the
age-banded indicators, age is evaluated at the qualifying visit and a visit with
unknown age is **excluded** (not silently bucketed as `15plus`).

- **BL-007 (ART line × age band — 6 indicators:
  `hiv_plhiv_{1st,2nd,3rd}_line_art_{0_14y,15plus}`):** distinct cohort **patients**
  with a qualifying HIV visit in the reporting month where the ART regimen is the
  matching line (first / second / third), with age at the visit ≤14 (`0_14y`) or
  ≥15 (`15plus`).
- **BL-008 (`hiv_plhiv_ever_started_art`):** distinct cohort patients with at least
  one HIV visit up to each month's end whose ART status is one of {Initiated ART,
  On ART, Transferred out, Refused (stopped) treatment}. Cumulative "ever started":
  once a patient qualifies in any month of the window they are counted in that
  month and every later month, and a **later reversion** to a non-qualifying status
  does not remove them — distinct from BL-009, which reads status *at* month end.
- **BL-009 (active care at period end × age band — 2 indicators:
  `hiv_plhiv_active_care_{0_14y,15plus}`):** distinct cohort patients whose HIV
  visit status **as of each month's end** is On ART, with age at that visit ≤14 or
  ≥15.
- **BL-010 (`hiv_plhiv_tested_viral_load`):** distinct patients with a viral-load
  result in the trailing 12 months as of each reporting month.
- **BL-011 (`hiv_plhiv_virologically_suppressed`):** the BL-010 cohort whose most
  recent viral-load result in that 12-month window is numeric and < 1000 copies/mL.
  Suppression must be proven by a **numeric** result; a non-numeric/text result
  (including a text "undetectable") does not count as suppressed.
- **BL-012 (`hiv_plhiv_advanced_hiv_active_care`):** distinct cohort patients with
  an HIV visit **in the reporting month** whose ART status at that visit is On ART
  or Refused (stopped) treatment, who were **ever** diagnosed with advanced HIV —
  any CD4 result ≤ 200 at any date up to month end, **or** WHO stage 3/4 at that
  visit, **or** age ≤ 5 at that visit. "Ever ≤ 200" is evaluated over all of the
  patient's CD4 results (not the latest, not restricted to before the visit); WHO
  stage and age are read from the reporting-month visit.

### Tuberculosis (7 indicators)

All TB indicators are gated on TB-cohort registry membership. An "episode" is one
TB treatment per (patient, treatment-initiation date). Resistance sets:
**DS** = {DS, Mono, Poly}; **MDR/RR** = {MDR, RR, Pre-XDR, XDR}.

- **BL-013 (`tb_ds_admissions`):** DS-resistance TB treatment episodes initiated in
  the reporting month.
- **BL-014 (`tb_ds_admissions_0_14y`):** BL-013 filtered to age ≤14 at treatment
  initiation.
- **BL-015 (`tb_mdr_rr_treatment_started`):** MDR/RR-resistance TB treatment
  episodes initiated in the reporting month.
- **BL-016 (`tb_ds_known_outcomes_12m`):** DS episodes initiated in the month 12
  months before the reporting month that have any treatment-outcome recorded within
  the 12-month episode window (any outcome value counts).
- **BL-017 (`tb_ds_treatment_success_12m`):** the BL-016 cohort whose recorded
  outcome is Cured or Treatment Completed.
- **BL-018 (`tb_mdr_rr_known_outcomes_24m`):** MDR/RR episodes initiated in the
  month 24 months before the reporting month with any treatment-outcome recorded
  within the 24-month episode window.
- **BL-019 (`tb_mdr_rr_treatment_success_24m`):** the BL-018 cohort whose recorded
  outcome is Cured or Treatment Completed.

### Cross-cutting

- **BL-020 (facility attribution):** every indicator attributes to the facility of
  its triggering encounter (form submission, lab request, or treatment) — there is
  no registry-vs-encounter attribution split, since none of the 24 indicators is a
  pure registry-membership count independent of an event.
- **BL-021 (test patients):** deployment-designated test patients are excluded.
- **BL-022 (zero suppression):** rows with `value_numeric = 0` are not emitted
  (DHIS2 treats an absent datavalue as no-data, not zero).

## Acceptance criteria

Definition-level invariants that every implementation must satisfy. Implementation
specs add their own deployment-specific unit/singular tests on top.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `metric_id` on every row is one of the 24 registered IDs | BL-001 | dbt `accepted_values` |
| AC-002 | `period_granularity = 'month'` on every row | BL-001 | dbt `accepted_values` |
| AC-003 | No row has `period_start` in the current (incomplete) month | BL-001 | singular test |
| AC-004 | Output grain (`metric_id`, `period_start`, `facility_id`) is unique | grain | `dbt_utils.unique_combination_of_columns` |
| AC-005 | No row has `value_numeric <= 0` | BL-022 | singular test |
| AC-006 | Every emitted `metric_id` is registered in `csv/metric_definitions.csv` | BL-001 | `relationships` |

## Registry entries

24 rows in `csv/metric_definitions.csv`, all `kind = metric`,
`definition_source = MSF`, `data_source = tamanu`, `spec_path` pointing at this
file:

- **PMTCT (5):** `pmtct_hiv_positive_delivering`,
  `pmtct_hiv_positive_delivering_on_art`, `pmtct_hiv_exposed_babies_born_alive`,
  `pmtct_hiv_exposed_newborns_pep_72h`, `pmtct_hiv_exposed_pcr_dna_done`
- **HIV / ART (12):** `hiv_plhiv_1st_line_art_0_14y`,
  `hiv_plhiv_2nd_line_art_0_14y`, `hiv_plhiv_3rd_line_art_0_14y`,
  `hiv_plhiv_1st_line_art_15plus`, `hiv_plhiv_2nd_line_art_15plus`,
  `hiv_plhiv_3rd_line_art_15plus`, `hiv_plhiv_ever_started_art`,
  `hiv_plhiv_active_care_0_14y`, `hiv_plhiv_active_care_15plus`,
  `hiv_plhiv_tested_viral_load`, `hiv_plhiv_virologically_suppressed`,
  `hiv_plhiv_advanced_hiv_active_care`
- **TB (7):** `tb_ds_admissions`, `tb_ds_admissions_0_14y`,
  `tb_mdr_rr_treatment_started`, `tb_ds_known_outcomes_12m`,
  `tb_ds_treatment_success_12m`, `tb_mdr_rr_known_outcomes_24m`,
  `tb_mdr_rr_treatment_success_24m`

The HIV/TB patient/episode-count indicators carry `subject_grain = patient` (or
`episode` for the TB episode counts) — the counts are of distinct subjects, not
form submissions. See the seed for each indicator's `description`,
`numerator_description`, `subject_grain`, and `unit`.

## Implementations

| Deployment | Repo | Implementation spec |
|---|---|---|
| MSF Kule | `tamanu-dbt-msf-kule` | [`specs/dbt-model/metric__hivtb_standard_indicators.md`](https://github.com/beyondessential/tamanu-dbt-msf-kule/blob/main/specs/dbt-model/metric__hivtb_standard_indicators.md) |

Currently the only implementation. When a second deployment adopts these
indicators, this section gains a row and any definition-level divergence gets
captured here (or as a `variant_of` registry row, per D5) rather than in either
deployment's own spec.

## Residual definitional cautions

- **PLHIV cohort-gate on the HIV-visit indicators (BL-007/009/012):** these nest
  under the "ever started ART" cohort (BL-008). This is a definitional reading of
  an ambiguous source cell ("Person_Registration: Age") and is the one open MSF
  confirmation behind the deployment spec's `review` status. If MSF reverses it,
  these indicators become visit-based (not cohort-gated) and the definitions above
  change.
- **Numeric-only VL suppression (BL-011):** suppression is inferred only from a
  numeric viral-load result. Deployments that record undetectable VLs as free text
  will undercount unless the value is entered numerically. This is a deliberate
  definitional choice (no token-guessing), not an implementation limitation.

## Open questions

One: MSF confirmation of the PLHIV cohort-gate (see § Residual definitional
cautions). All other source-sheet ambiguities were resolved 2026-07-19..27 and are
recorded in the deployment spec's change log.

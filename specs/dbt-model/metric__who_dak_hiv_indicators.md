# dbt Model Spec: `metric__who_dak_hiv_indicators` (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__who_dak_hiv_indicators` (16 registered indicators) |
| **Type** | dbt model (canonical definitions) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-24 |
| **Last updated** | 2026-08-24 |

## Purpose

Report WHO SMART guidelines HIV indicators from the DAK's own forms. The `who-dak-hiv` program
forms are generated from Web Annex A, so a question code *is* a DAK data element id — which
makes Web Annex C's indicator definitions, written in terms of those elements, computable
without a local interpretation layer.

Sixteen counts are implemented, covering nine Annex C indicators: those whose numerator and
denominator can both be read from the data elements those forms collect. Each count is registered
separately, so a rate is formed by the consumer from a numerator and its denominator. Annex C's
`Ref no.` is on every registry row, which is what the DAK's GAM 2023, Global Fund 2023 and
PEPFAR MER 2.6.1 crosswalk sheets key on — so an indicator here resolves to the line those
reports ask for.

| Ref | Annex C indicator | Numerator | Denominator |
|---|---|---|---|
| HTS.2 | Test volume and positivity | `who_dak_hiv_hts_test_positive` | `who_dak_hiv_hts_test` |
| HTS.3 | Individuals testing positive | `who_dak_hiv_hts_client_positive` | `who_dak_hiv_hts_client_tested` |
| ART.3 | Viral suppression | `who_dak_hiv_art_viral_suppression` | `who_dak_hiv_art_routine_viral_load` |
| ART.4 | New ART patients | `who_dak_hiv_art_initiated` | a count (Annex C gives 1) |
| ART.5 | Late ART initiation | `who_dak_hiv_art_late_initiation` | `who_dak_hiv_art_cd4_at_initiation` |
| DSD.3 | DSD ART coverage | `who_dak_hiv_dsd_enrolled` | `who_dak_hiv_dsd_eligible` |
| ART.1 | People living with HIV on ART | `who_dak_hiv_art_on_art` | a population estimate, not Tamanu's |
| ART.1 | …by key population | `who_dak_hiv_art_on_art_key_population` | — |
| ART.9 | ARV toxicity prevalence | `who_dak_hiv_art_toxicity` | `who_dak_hiv_art_on_art` |
| DSD.4 | Retention in DSD ART models | `who_dak_hiv_dsd_retained` | `who_dak_hiv_dsd_retention_eligible` |

## Scope: what is not implemented, and why

- **49 of the 140** declare no numerator computable from DAK data (`Not included in DAK` —
  survey-based, commodity stock, or another system). Nothing in Tamanu can supply them.
- **Population denominators** (`ART.1` treatment coverage over estimated PLHIV) are estimates
  from outside Tamanu, so the count is registered and the rate is not.
- **The other 77 covered indicators are not implemented yet, and that is a backlog rather than
  an obstacle.** `tupaia-data-product`'s `tamanu/who-dak/annex_c_coverage.py` reports which
  Annex C indicators the generated forms can compute — 86 of the 140 at the time of writing —
  so the remaining work is enumerable and each addition is a predicate over
  `int__who_dak_hiv_form_answers` or `int__who_dak_hiv_client_month_state`. Nothing structural
  is missing.

## Grain

`metric_id × subject × reporting month`. `subject_grain` names the unit: `patient` on every
client-count indicator, `test` on HTS.2, where Annex C counts tests rather than people.

## Output schema

D5 wide format, plus `subject_grain`, `facility_id`, `sex`, `age_years`, and
`months_on_dsd` / `key_population` for the two indicators that carry them. `period_start` is the
first day of the reporting month and `period_end` the last; `value_numeric` is always 1.

## Business logic

- **BL-001:** Each output row's `metric_id` is one of the sixteen registered in
  `documentations/metrics/who_dak_hiv.yml`; the registry row carries the definition and this
  model is its implementation.
- **BL-002:** The DAK data elements are read from `who-dak-hiv` form submissions, identified by
  the survey id prefix `program-whodakhiv-`. A question code is the DAK data element id, so
  `HIV.D.DE38` is `pde-whodakhiv-d-de38`. The code mapping lives in
  `int__who_dak_hiv_form_answers` and nowhere else.
- **BL-003:** A form asks each question at most once, so one answer per element per submission.
- **BL-004:** Answers are text whatever the question type, so each is cast to the type Annex A
  declares: a date to `date`, a quantity to `numeric`, a Binary's `Yes`/`No` to boolean. An
  answer that does not match reads NULL rather than failing the build — one client's mistyped
  date must not stop a deployment's reporting.
- **BL-005:** One row per qualifying subject per month, `value_numeric` 1, `period_start` the
  first of the month and `period_end` the last.
- **BL-006:** Every indicator emits a count. A rate is the consumer's, formed from a numerator
  and its denominator at whatever grain it groups to — so a facility figure and a national one
  are the same definition.
- **BL-007:** Annex C counts clients, so a client qualifying more than once in a month
  contributes one row. The earliest qualifying event in the month wins and carries the facility
  and the age, so a client is attributed to where they were first counted.
- **BL-008:** Annex C gates every ART and DSD indicator on `HIV status = 'HIV-positive'`. The
  DAK carries that element on the HTS form, not the care visit, so a client seen only in care
  would fail a literal reading. A care-visit submission is accepted as equivalent evidence: the
  DAK's care and treatment process is for people living with HIV, and a literal gate would
  report zero on deployments using the care form alone.
- **BL-009:** Which date places a subject in a reporting period is the Annex C element for that
  indicator — results-returned date for HTS.2, ART start date for ART.4, viral load sample date
  for ART.3, eligibility assessment date for DSD.3. A late submission therefore counts in the
  month the event happened.
- **BL-010:** HTS.2 counts tests: its subject is the submission, so a client tested twice in a
  month contributes two. HTS.3 counts the same clients once.
- **BL-011:** ART.4 counts an initiation in the month the ART start date falls in.
- **BL-012:** ART.3 counts a routine viral load only for a client whose ART start date is more
  than six months before the end of the reporting period — the month's last day less six months,
  not its first — and counts suppression below 1000 copies/mL. Both conditions are Annex C's: a
  targeted test, taken because treatment is suspected to be failing, would bias suppression
  downwards. The cutoff is written once and shared by the numerator and the denominator.
- **BL-013:** ART.5 pairs an ART start with a baseline CD4 count in the same month, and counts
  late initiation below 200 cells/mm³.
- **BL-014:** DSD.3's denominator is clients assessed eligible in the period — the electronic
  branch of the two Annex C offers. Its numerator has no date element in Annex C at all, and
  "currently enrolled in a DSD ART model" is a standing answer a care visit repeats every time,
  so dating it by the submission would put a client in the numerator in every month they were
  seen while the denominator counts them in one — a coverage figure that climbs past 100% and
  keeps going. The numerator is therefore anchored on the same eligibility assessment as the
  denominator: of the clients assessed eligible this month, those recorded as enrolled.
- **BL-015:** `facility_id` is the qualifying submission's facility, from the encounter's
  location, and is nullable: dropping a client with no location would understate a national
  count to protect a facility one.
- **BL-016:** `age_years` is age at the qualifying event, unbanded — Annex C disaggregates by
  age but GAM, MER, the DAK's own 0-14/15+ split and a national HMIS band differently, so the
  consumer's data table bands it. Sex is emitted as recorded. No `data_table_*` meta.
- **BL-017:** A row is patient-identifiable and HIV status is the sensitive fact itself:
  `pii: true`, `classification: restricted`, and a consumer's data table names its permission
  group explicitly. The shipping decision is the one recorded in
  `metric__program_registry_enrolment.md` BL-011.

- **BL-018:** The point-in-time indicators read `int__who_dak_hiv_client_month_state`, which
  carries each client's last known state to the end of every complete month. `ART.1` counts
  clients on ART *at* the reporting period end date, so a client not seen during the month is
  still counted: the record says they are on treatment until it says otherwise.
- **BL-019:** State is carried forward per element, not per submission. A later visit recording
  a viral load but silent on DSD enrolment must not blank the DSD state, so each attribute takes
  the most recent submission that carried a value for it.
- **BL-020:** Only complete months are emitted, so a partial current month cannot read as a fall
  in the caseload.
- **BL-021:** A client's facility in a month is the one that last recorded anything about them,
  so a transfer moves their counts to the receiving facility from the month it records them.
- **BL-022:** Key population is a MultiSelect: a client can belong to several. It is therefore a
  bridge (`int__who_dak_hiv_key_populations`) feeding a separate metric whose rows are
  client-population pairs, not a column on the counts of people — a column would force one value
  per client, and adding the pairs to a people count would double a client in two populations.
  Summing the key-population metric across populations double-counts such a client, which is
  what Annex C's own disaggregation does. The DAK collects the element twice, on the HTS visit
  and on the PMTCT pathway, and a client's populations are the union of both: reading one alone
  would drop a client seen only on the other from every disaggregated count. The membership is a
  standing attribute, so the latest answer per element wins.
- **BL-023:** `ART.9` counts a client whose treatment stopped for toxicity or whose regimen was
  substituted for toxicity on any line. Each line's substitution date is tested against the
  reporting period on its own: which line it was is not part of the indicator, but the *dates*
  are, so collapsing them to one would lose a client's later substitution entirely. A client with
  more than one qualifying event in a month counts once.
- **BL-024:** `ART.1` emits the count only. Annex C's denominators are the estimated number of
  people living with HIV, or the estimate of those who know their status; both are external, so
  a coverage rate is formed outside this model.
- **BL-026:** A recorded ART stop ends the on-ART state from the month the stop is dated,
  whether or not the form that recorded it also answered "On ART" — otherwise a client whose
  treatment stopped stays in ART.1 for ever and the cascade's headline number only grows. A
  later ART start date supersedes an earlier stop: that client is on a second course, and the
  old stop says nothing about it. The state is read from the dated stop rather than from the
  recording form's submission, so a stop entered late still takes effect in the month treatment
  ended — the same rule `ART.4` uses for an initiation.
- **BL-027:** The spine's horizon is the last complete month, overridable through the
  `who_dak_hiv_spine_end` var so a backfill can be reproduced and a test can assert a fixed set
  of months.
- **BL-025:** `DSD.4` is reported at 12, 24, 36, 48 and 60 months. `months_on_dsd` is emitted
  from twelve months upwards and the consumer selects the cohort, rather than the model carrying
  five near-identical metrics that would say the same thing five times and drift apart the first
  time one changed.

- **BL-028:** An indicator's numerator counts a subset of its denominator's population, on the
  same date element. Annex C's HTS.2 and HTS.3 numerators admit a positive placed by its HIV
  diagnosis date where the denominators require the results-returned date, which lets a positive
  count in a period its own denominator does not — a positivity rate above 100%. Both numerators
  therefore use the denominator's predicate and date.
- **BL-029:** Where the latest answer wins, the ordering puts NULLs last. A response that was
  never completed carries no submission datetime, and Postgres sorts NULLs first under `desc`,
  so an abandoned submission would outrank every real one and discard every later correction.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `(metric_id, subject_id, period_start)` is unique | BL-007 | `dbt_utils.unique_combination_of_columns`, severity error |
| AC-002 | `period_end > period_start` | BL-005 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-003 | `period_start` is a month start and `period_end` its month end | BL-005 | `dbt_utils.expression_is_true` |
| AC-004 | `period_start <= period_end` on every row | BL-005 | `dbt_utils.expression_is_true` |
| AC-005 | `metric_id` is not null and is one of the eleven | BL-001 | `not_null`, `accepted_values` |
| AC-006 | `metric_id` appears in `metric_definitions` | BL-001 | `relationships`, severity error |
| AC-007 | `subject_id` is not null | BL-005 | `not_null` |
| AC-008 | `subject_grain` is `patient` or `test` | BL-010 | `not_null`, `accepted_values` |
| AC-009 | `period_start` and `period_end` are not null | BL-005 | `not_null` |
| AC-010 | `period_granularity` is `month` | BL-005 | `accepted_values` |
| AC-011 | `value_numeric` is not null and always 1 | BL-005 | `not_null`, `accepted_values` |
| AC-012 | A client tested twice in a month is two tests and one client, attributed to the earlier test's facility | BL-007, BL-010 | unit test `..._hts_grain` |
| AC-013 | ART.3 excludes a client on ART under six months, a targeted test, and a result of exactly 1000 | BL-012 | unit test `..._art3_viral_suppression` |
| AC-014 | ART.5 counts a CD4 under 200 in the numerator and 350 in the denominator only; a client with no HIV-positive evidence is in neither | BL-008, BL-013 | unit test `..._art5_and_plhiv_gate` |
| AC-015 | ART.1 counts a client on ART at the month end without an event in the month; DSD.4 counts only clients twelve or more months in, and retention among them only those still enrolled | BL-018, BL-025 | unit test `..._point_in_time` |
| AC-016 | `months_on_dsd` is 12 or more on the DSD.4 metrics and null on every other | BL-025 | `dbt_utils.expression_is_true`, both directions |
| AC-017 | `key_population` is set on the key-population metric and null on every other | BL-022 | `dbt_utils.expression_is_true`, both directions |
| AC-018 | A client substituted on first line in one month and third line in another is counted in both; a stop for toxicity counts in the month it is dated | BL-023 | unit test `..._art9_toxicity` |
| AC-019 | ART.3's six-month cutoff is the sample month's last day less six months: a client who started 2025-12-29 qualifies for a June sample and one who started 2025-12-31 does not | BL-012 | unit test `..._art3_six_month_boundary` |
| AC-020 | A recorded ART stop ends the on-ART state from its own month, and a later ART start supersedes it | BL-026 | unit test `test_int__who_dak_hiv_client_month_state_art_stop` |
| AC-021 | Every numerator's rows are a subset of its denominator's, per period and subject | BL-028 | singular test over each registered pair |
| AC-022 | A positive result with no results-returned date is in neither HTS numerator nor its denominator | BL-028 | unit test `..._hts_grain` |
| AC-023 | A DSD.3 numerator row exists only where the same client has a denominator row in the same month | BL-014 | unit test `..._dsd_coverage` |

The eight unit tests carry the definitional weight. No deployment has captured these forms yet,
so the data tests assert shape on an empty relation — a fixture is the only way to prove a
definition holds before there is data, and each of AC-012 to AC-014 pins a boundary a reader
would otherwise have to take on trust.

## Dependencies

`int__who_dak_hiv_form_answers` (over `survey_responses`, `survey_response_answers`, `surveys`,
`encounters`, `locations`, `clinical__person`), `int__who_dak_hiv_client_month_state`,
`int__who_dak_hiv_key_populations`, `metric_definitions`.

## Consumers

Tupaia dashboards, through a data table in `tupaia-data-product`. A deployment reporting to GAM,
the Global Fund or PEPFAR reads the same counts via Annex C's crosswalk.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Which of the remaining covered Annex C indicators to implement, and in what order — the DAK's own reporting priorities, or a deployment's GAM / Global Fund / MER obligations. | Data Lead | per deployment |

## Related

- `documentations/metrics/who_dak_hiv.yml` — the registered definitions
- `specs/dbt-model/metric__program_registry_enrolment.md` — the same programme seen through the
  program registry rather than the forms
- `tupaia-data-product`, `tamanu/who-dak/hiv/` — the forms these indicators read, and
  `dak-conformance.md` for what the forms do and do not carry

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-24 | Maui team | Initial spec. Sixteen counts over nine Annex C indicators from the generated DAK forms, as counts with the rate left to the consumer. `int__who_dak_hiv_client_month_state` carries each client's last known state to a month end, which is what `ART.1` and `DSD.4` need; key population is a bridge feeding a separate metric of client-population pairs, because a column would make a count of people wrong. |

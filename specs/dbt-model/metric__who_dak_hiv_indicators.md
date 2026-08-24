# dbt Model Spec: `metric__who_dak_hiv_indicators` (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__who_dak_hiv_indicators` (11 registered indicators) |
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

Eleven of Annex C's 140 are implemented: the counts whose numerator and denominator can both be
read from the data elements those forms collect. Each is registered separately and emits a
count, so a rate is formed by the consumer from a numerator and its denominator. Annex C's
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

## Scope: what is not implemented, and why

- **49 of the 140** declare no numerator computable from DAK data (`Not included in DAK` —
  survey-based, commodity stock, or another system). Nothing in Tamanu can supply them.
- **Point-in-time indicators** need a monthly spine carrying each client's last known state
  forward: `ART.1` (people on ART *at* the reporting date), `DSD.4` (retention at 12/24/36/48/60
  months). That is a different model shape; see OQ-001.
- **`ART.9` ARV toxicity** needs a first-line regimen substitution date. The generated form
  carries second- and third-line substitution dates but not first, so the numerator would
  undercount silently.
- **Population denominators** (`ART.1` treatment coverage over estimated PLHIV) are estimates
  from outside Tamanu and are not registered.
- **Key population disaggregation**, which Annex C asks for on most indicators, is a
  MultiSelect answer: one client can hold several values, so it cannot be a column on a
  one-row-per-client count without changing what a sum means. Not emitted; see OQ-002.

## Grain

`metric_id × subject × reporting month`. `subject_grain` names the unit: `patient` on every
client-count indicator, `test` on HTS.2, where Annex C counts tests rather than people.

## Output schema

D5 wide format, plus `subject_grain`, `facility_id`, `sex` and `age_years`. `period_start` is the
first day of the reporting month and `period_end` the last; `value_numeric` is always 1.

## Business logic

- **BL-001:** Each output row's `metric_id` is one of the eleven registered in
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
  than six months before the end of the reporting period, and counts suppression below 1000
  copies/mL. Both conditions are Annex C's: a targeted test, taken because treatment is
  suspected to be failing, would bias suppression downwards.
- **BL-013:** ART.5 pairs an ART start with a baseline CD4 count in the same month, and counts
  late initiation below 200 cells/mm³.
- **BL-014:** DSD.3's denominator is clients assessed eligible in the period — the electronic
  branch of the two Annex C offers. Its numerator has no date element in Annex C, so the
  submission recording the enrolment places it.
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

The three unit tests carry the definitional weight. No deployment has captured these forms yet,
so the data tests assert shape on an empty relation — a fixture is the only way to prove a
definition holds before there is data, and each of AC-012 to AC-014 pins a boundary a reader
would otherwise have to take on trust.

## Dependencies

`int__who_dak_hiv_form_answers` (over `survey_responses`, `survey_response_answers`, `surveys`,
`encounters`, `locations`, `clinical__person`), `metric_definitions`.

## Consumers

Tupaia dashboards, through a data table in `tupaia-data-product`. A deployment reporting to GAM,
the Global Fund or PEPFAR reads the same counts via Annex C's crosswalk.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether to build the monthly last-known-state spine that `ART.1` and `DSD.4` need, and whether it belongs here or in `derived__`. | Data Lead | next phase |
| OQ-002 | How to disaggregate by key population, which Annex C asks for on most indicators and which is a MultiSelect answer — a bridge table, or one metric per population. | Data Lead | next phase |

## Related

- `documentations/metrics/who_dak_hiv.yml` — the registered definitions
- `specs/dbt-model/metric__program_registry_enrolment.md` — the same programme seen through the
  program registry rather than the forms
- `tupaia-data-product`, `tamanu/who-dak/hiv/` — the forms these indicators read, and
  `dak-conformance.md` for what the forms do and do not carry

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-24 | Maui team | Initial spec. Eleven Annex C indicators over the generated DAK forms, as counts with the rate left to the consumer; point-in-time and key-population indicators deferred to OQ-001 and OQ-002. |

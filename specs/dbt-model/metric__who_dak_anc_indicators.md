# dbt Model Spec: `metric__who_dak_anc_indicators` (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__who_dak_anc_indicators` (2 registered indicators: the DAK definition and the Samoa variant) |
| **Type** | dbt model (canonical definitions) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | [MAUI-6838](https://linear.app/bes/issue/MAUI-6838), [MAUI-7179](https://linear.app/bes/issue/MAUI-7179) |
| **Created** | 2026-10-21 |
| **Last updated** | 2026-11-16 |

## Purpose

Report antenatal care activity in the vocabulary of the WHO SMART guidelines Digital Adaptation
Kit for antenatal care (2021). The DAK's Web Annex A gives every data element a portable id
(`ANC.A7.DE4` *Contact date*), and Web Annex C defines the ANC indicators in terms of those
elements, so an indicator computed here means the same thing on every deployment.

A deployment reaches the DAK definition by either of two routes, and the metric reads both:

- **Native:** it captures antenatal care on the `who-dak-anc` program forms that
  `tupaia-data-product` generates from Annex A, whose question codes *are* the DAK element ids.
- **Mapped:** it keeps its own antenatal forms and maps their questions to DAK element ids in its
  own `dbt_project.yml`.

A deployment that does not follow the DAK registers its own definition as a variant, with its own
`metric_id` and a `variant_id` on its rows, so the DAK definition stays as the DAK states it. One
variant is implemented here: Samoa Ministry of Health's (`samoa_moh_2026`), for a deployment that
records antenatal care on its own forms and at antenatal clinic visits (§ Samoa variant).

| `metric_id` | `variant_id` | Definition source | Measures | Annex C use |
|---|---|---|---|---|
| `who_dak_anc_contact` | NULL | `WHO_SMART_ANC` | Antenatal care contacts (always 1 per row) | The contacts `ANC.IND.4` and `ANC.IND.5` count per pregnancy |
| `who_dak_anc_contact_samoa` | `samoa_moh_2026` | `SAMOA_MOH` | Antenatal care contacts under Samoa's definition (always 1 per row) | None — a variant of `who_dak_anc_contact` |

**Who reads it.** Tupaia "Maternity and newborn" dashboard cards, via a data table in
`tupaia-data-product`.

A pregnancy's first contact is its booking assessment — the WHO ANC1 concept — so booking
counts have no separate `metric_id`.

## Grain

**One row per `(metric_id, subject_id)`**, `subject_id` identifying the contact as the patient and
the contact day. `subject_grain: visit` in the registry.

## Inputs

### Upstream models

The metric reads `int__who_dak_anc_contacts` and `clinical__person`. The contacts and their
elements are built in two intermediate models it shares with `derived__episode_pregnancy_samoa`:
`int__who_dak_anc_submissions` reads the forms (BL-002–BL-004, BL-006, BL-009), and
`int__who_dak_anc_contacts` assembles the contacts (BL-005, BL-007, BL-008, BL-010, BL-014–BL-020).
Between them they read:

| Reference | Why |
|---|---|
| `survey_responses` | Form submissions — survey, encounter, submission times |
| `survey_response_answers` | The answers, as text |
| `program_data_elements` | Resolves an answer's data element to its code |
| `encounters` | The submission's patient and location, and Samoa variant contact encounters |
| `encounter_history` | Every location a contact encounter occupied |
| `locations` | The location's facility and location group |
| `location_groups` | Location group names, matched against the contact location groups |
| `clinical__person` | Date of birth, for age at contact, and sex |
| `metric_definitions` | Registry FK target |

### Configuration

Two project vars, both unset by default, so a deployment that sets neither reads the native forms
only, under the DAK definition:

- `who_dak_anc_local_surveys`, keyed by survey id, maps local forms to DAK elements.
- `who_dak_anc_samoa_moh_2026` turns on the Samoa variant. Its `contact_location_groups` lists
  location group name patterns, matched in any letter case with `%` as a wildcard, whose encounters
  are Samoa variant contacts.

```yaml
vars:
  who_dak_anc_local_surveys:
    program-maternityregistry-antenatalchart:
      is_contact: true
      data_elements:
        ANC.A7.DE4: PatientChartingDate
  who_dak_anc_samoa_moh_2026:
    contact_location_groups:
      - '%antenatal%'
```

## Output schema

| Column | Type | Description |
|---|---|---|
| `metric_id` | text | `who_dak_anc_contact`, or `who_dak_anc_contact_samoa` for the Samoa variant |
| `variant_id` | text | NULL, or `samoa_moh_2026` for the Samoa variant |
| `subject_id` | varchar | The contact: patient id and contact day |
| `period_start` | date | The contact day |
| `period_end` | date | Equal to `period_start` |
| `period_granularity` | text | `'day'` |
| `value_numeric` | numeric | Always `1` |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar | Facility of the contact form's encounter, or of the contact location group. Nullable |
| `person_id` | varchar | The pregnant woman |
| `age_years` | integer | Her age in whole years at the contact. A measure, unbanded |
| `contact_number` | integer | `ANC.A7.DE12` *ANC contact number*, as recorded |
| `gestational_age_weeks` | numeric | `ANC.B6.DE17` *Gestational age*, as recorded that day; worked out under the Samoa variant (BL-017) |
| `lmp_date` | date | `ANC.B6.DE14` *Last menstrual period (LMP) date* |
| `edd_date` | date | `ANC.B6.DE22` *Expected date of delivery (EDD)* |
| `gravida` | integer | `ANC.B6.DE24` *Number of pregnancies (gravida)*, as recorded; worked out under the Samoa variant (BL-018) |
| `miscarriages_abortions` | integer | `ANC.B6.DE25` *Number of miscarriages and/or abortions* |
| `parity` | integer | `ANC.B6.DE32` *Parity* |
| `tt_dose_1_date` … `tt_dose_5_date` | date | `ANC.B10.DE166`, `DE168`, `DE170`, `DE172`, `DE174` *Date tetanus toxoid 1–5 immunization was received* |

Every element column is the value recorded on a native or mapped form for the woman on the contact
day (BL-007), so a contact with no form that day has none.

## Business logic

### DAK definition (`WHO_SMART_ANC`)

- **BL-001:** Each output row's `metric_id` is registered in `documentations/metrics/who_dak_anc.yml`.
- **BL-002:** Native answers are read from submissions whose survey id starts
  `program-whodakanc-`, and a DAK element id maps to its question code by lower-casing the part
  after `ANC.` and replacing `.` with `-`: `ANC.A7.DE4` is `whodakanc-a7-de4`.
- **BL-003:** Mapped answers are read from the surveys named in `who_dak_anc_local_surveys`, each
  `data_elements` entry mapping a DAK element id to the local question's data element code, and a
  mapped answer is read exactly as a native answer to that element.
- **BL-004:** A contact form is the native ANC Registration form
  (`program-whodakanc-registration`) or a mapped survey with `is_contact: true`.
- **BL-005:** A contact is a patient with at least one contact source on a day under a definition,
  so two for the same patient on the same day are one contact.
- **BL-006:** A contact's day is its contact form's `ANC.A7.DE4` *Contact date*, falling back to the
  submission's start date where that answer is blank or malformed.
- **BL-007:** Elements attach to a contact from every native or mapped submission for the same
  patient on the contact day, whether or not it shares the contact form's encounter.
- **BL-008:** Where several submissions carry the same element for a contact, the latest
  submitted wins, with an unsubmitted response ordered last.
- **BL-009:** Answers are cast to the type Annex A declares — date, integer, numeric — and an
  answer that does not match, names a date that does not exist or falls before the year 1000, or is
  too large for an integer reads NULL rather than failing the build.
- **BL-010:** `facility_id` is the facility of the earliest contact source that day, and is
  nullable.
- **BL-011:** `age_years` is the woman's age in whole years on the contact day, unbanded; the
  consumer bands it.
- **BL-012:** Every row is a count of 1, and coverage is formed downstream against an externally
  supplied expected-pregnancies estimate.
- **BL-013:** The model is `pii: true`, `classification: restricted` — a row identifies a
  pregnant woman by date and facility.
- **BL-016:** A contact with no native or mapped submission that day is still a contact, with no
  element values.

### Samoa variant (`samoa_moh_2026`, `SAMOA_MOH`)

- **BL-020:** Where `who_dak_anc_samoa_moh_2026` is set, every contact form is also a contact under
  the Samoa variant, whose rows carry `metric_id` `who_dak_anc_contact_samoa` and `variant_id`
  `samoa_moh_2026`, and the DAK definition's rows are unchanged.
- **BL-014:** An encounter is a Samoa variant contact source when its location, or any location in
  its history, belongs to a location group matching a `contact_location_groups` pattern.
- **BL-015:** A contact encounter's day is its start date, and form-only (`surveyResponse`)
  encounters and patients recorded as male are not contact encounters.
- **BL-017:** Where no gestational age is recorded, it is the whole weeks from the LMP to the contact
  day, or from 280 days before the EDD when there is no LMP, kept only between 0 and 45 weeks.
- **BL-018:** Where no gravida is recorded, it is parity plus miscarriages and/or abortions plus 1,
  following Annex A's definitions of parity (`ANC.B6.DE32`) and previous pregnancies (`ANC.B6.DE23`).
- **BL-019:** A patient younger than 10 on the day is not a contact, and one with no recorded date
  of birth is.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `(metric_id, subject_id)` is unique | BL-005 | `dbt_utils.unique_combination_of_columns`, severity error |
| AC-002 | `metric_id` is not null and one of the two registered ids, and `variant_id` is NULL or `samoa_moh_2026` | BL-001, BL-020 | `not_null`, `accepted_values`; unit test `test_metric__who_dak_anc_indicators_framing` |
| AC-003 | Every `metric_id` is in `metric_definitions` | BL-001 | `relationships`, severity error |
| AC-004 | `value_numeric` is not null and always 1, and `age_years` is her age in whole years on the contact day | BL-011, BL-012 | `not_null`, `accepted_values`; unit test `test_metric__who_dak_anc_indicators_framing` |
| AC-005 | `period_end` equals `period_start` | BL-006 | `dbt_utils.expression_is_true`; unit test `test_metric__who_dak_anc_indicators_framing` |
| AC-006 | A native Registration submission is a contact form on its recorded contact date, carrying the contact number, and a contact takes gestational age from a Profile form submitted the same day | BL-002, BL-005, BL-007 | unit tests `test_int__who_dak_anc_submissions_native`, `test_int__who_dak_anc_contacts_elements` |
| AC-007 | Two contact forms for one patient on one day are one contact, the later submission's elements win, and the facility is the earlier form's | BL-005, BL-008, BL-010 | unit test `test_int__who_dak_anc_contacts_elements` |
| AC-008 | A blank, malformed or non-existent contact date falls back to the submission's start date, and a contact number too large for an integer reads NULL | BL-006, BL-009 | unit test `test_int__who_dak_anc_submissions_native` |
| AC-009 | A mapped contact survey is a contact form on its mapped contact date; a mapped survey without `is_contact` is not, a native non-contact form alone yields no contact, and an unmapped survey is not read | BL-003, BL-004 | unit tests `test_int__who_dak_anc_submissions_local_mapping`, `test_int__who_dak_anc_contacts_elements` |
| AC-010 | Under the Samoa variant, an encounter at a matching location group is a contact, whether the group is its current location or only in its history, with elements from a form that day and none without one; two encounters and a form on one day are one contact at the earliest source's facility; a form-only encounter, a man's encounter and an encounter at a non-matching group yield none; with the variant unset, no encounter is a contact | BL-014–BL-016, BL-020 | unit tests `test_int__who_dak_anc_contacts_samoa`, `test_int__who_dak_anc_contacts_samoa_unset` |
| AC-011 | A whole number stored as `2.0` reads as 2. Under the DAK definition gestational age and gravida are as recorded; under the Samoa variant gestational age is the recorded value, else from the LMP, else from the EDD, and blank outside 0 to 45 weeks, and gravida is the recorded value, else parity + miscarriages/abortions + 1, and blank without both | BL-009, BL-017, BL-018 | unit tests `test_int__who_dak_anc_submissions_local_mapping`, `test_int__who_dak_anc_contacts_elements`, `test_int__who_dak_anc_contacts_samoa` |
| AC-012 | Under the Samoa variant, a patient aged 9 on the contact day is not a contact while one aged 10, and one with no date of birth, are; under the DAK definition all three are | BL-019, BL-020 | unit tests `test_int__who_dak_anc_contacts_samoa`, `test_int__who_dak_anc_contacts_elements` |
| AC-013 | With the Samoa variant set, a contact form is a contact under both definitions, and the Samoa row is `who_dak_anc_contact_samoa` with `variant_id` `samoa_moh_2026` | BL-020 | unit tests `test_int__who_dak_anc_contacts_samoa`, `test_metric__who_dak_anc_indicators_framing` |

## Consumers

1. **Aggregate.** Sum `value_numeric`.
2. **Form coverage downstream**, against the consumer's own expected-pregnancies estimate (BL-012).
3. **Band age in the data table** (BL-011).
4. **Respect `classification: restricted`** (BL-013).

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Implementing `ANC.IND.1`, `ANC.IND.4` and `ANC.IND.5`, which count pregnancies rather than contacts, over `derived__episode_pregnancy_samoa` | @maui-team | unscheduled |

## Related

| Artefact | Relationship |
|---|---|
| `documentations/metrics/who_dak_anc.yml` | The registered definitions |
| `derived__episode_pregnancy_samoa` | The pregnancies assembled from these contacts |
| `metric__who_dak_hiv_indicators` | The same pattern over the HIV DAK |
| `metric__birth` | Same dashboard group |
| `tupaia-data-product` `tamanu/who-dak/anc/` | The forms, and `dak-conformance.md` for what they carry |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-16 | Maui team | Reads the profile elements LMP, EDD, gravida, miscarriages/abortions and parity, and the tetanus toxoid dose dates, as recorded. Adds Samoa Ministry of Health's definition as the variant `who_dak_anc_contact_samoa` (`samoa_moh_2026`): encounters at named antenatal clinic location groups are contacts, gestational age and gravida are worked out where not recorded, and patients younger than 10 are left out. The forms and contacts are built in `int__who_dak_anc_submissions` and `int__who_dak_anc_contacts`, shared with `derived__episode_pregnancy_samoa` (MAUI-7179). |
| 2026-10-21 | Maui team | Initial spec, approved. The antenatal contact count, read from the WHO DAK ANC forms or from a deployment's own forms mapped to DAK element ids. Replaces the `antenatal_contact` and `antenatal_booking` definitions — a booking is a pregnancy's first contact, not a separate metric_id (MAUI-6838). |

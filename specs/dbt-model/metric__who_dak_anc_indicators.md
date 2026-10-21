# dbt Model Spec: `metric__who_dak_anc_indicators` (canonical definitions)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__who_dak_anc_indicators` (1 registered indicator) |
| **Type** | dbt model (canonical definitions) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `review` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | [MAUI-6838](https://linear.app/bes/issue/MAUI-6838) |
| **Created** | 2026-10-21 |
| **Last updated** | 2026-10-21 |

## Purpose

Report antenatal care activity in the vocabulary of the WHO SMART guidelines Digital Adaptation
Kit for antenatal care (2021). The DAK's Web Annex A gives every data element a portable id
(`ANC.A7.DE4` *Contact date*), and Web Annex C defines the ANC indicators in terms of those
elements, so an indicator computed here means the same thing on every deployment.

A deployment reaches these definitions by either of two routes, and the metric reads both:

- **Native:** it captures antenatal care on the `who-dak-anc` program forms that
  `tupaia-data-product` generates from Annex A, whose question codes *are* the DAK element ids.
- **Mapped:** it keeps its own antenatal forms and maps their questions to DAK element ids in its
  own `dbt_project.yml`.

| `metric_id` | Unit | Measures | Annex C use |
|---|---|---|---|
| `who_dak_anc_contact` | count | Antenatal care contacts (always 1 per row) | The contacts `ANC.IND.4` and `ANC.IND.5` count per pregnancy |

**Who reads it.** Tupaia "Maternity and newborn" dashboard cards, via a data table in
`tupaia-data-product`.

## Grain

**One row per `(metric_id, subject_id)`**, `subject_id` identifying the contact as the patient and
the contact day. `subject_grain: visit` in the registry.

## Inputs

### Upstream models

| Reference | Why |
|---|---|
| `survey_responses` | Form submissions — survey, encounter, submission times |
| `survey_response_answers` | The answers, as text |
| `program_data_elements` | Resolves an answer's data element to its code |
| `encounters` | The submission's patient and location |
| `locations` | The location's facility |
| `clinical__person` | Date of birth, for age at contact |
| `metric_definitions` | Registry FK target |

### Configuration

`who_dak_anc_local_surveys`, a project var keyed by survey id. Defaults to empty, so a deployment
that sets nothing reads the native forms only.

```yaml
vars:
  who_dak_anc_local_surveys:
    program-maternityregistry-antenatalchart:
      is_contact: true
      data_elements:
        ANC.A7.DE4: PatientChartingDate
```

## Output schema

| Column | Type | Description |
|---|---|---|
| `metric_id` | text | Always `who_dak_anc_contact` |
| `variant_id` | text | NULL |
| `subject_id` | varchar | The contact: patient id and contact day |
| `period_start` | date | The contact day |
| `period_end` | date | Equal to `period_start` |
| `period_granularity` | text | `'day'` |
| `value_numeric` | numeric | Always `1` |
| `value_boolean` | boolean | NULL |
| `facility_id` | varchar | Facility of the contact form's encounter. Nullable |
| `person_id` | varchar | The pregnant woman |
| `age_years` | integer | Her age in whole years at the contact. A measure, unbanded |
| `contact_number` | integer | `ANC.A7.DE12` *ANC contact number*, as recorded |
| `gestational_age_weeks` | numeric | `ANC.B6.DE17` *Gestational age*, as recorded that day |

## Business logic

- **BL-001:** Each output row's `metric_id` is registered in `documentations/metrics/who_dak_anc.yml`.
- **BL-002:** Native answers are read from submissions whose survey id starts
  `program-whodakanc-`, and a DAK element id maps to its question code by lower-casing the part
  after `ANC.` and replacing `.` with `-`: `ANC.A7.DE4` is `whodakanc-a7-de4`.
- **BL-003:** Mapped answers are read from the surveys named in `who_dak_anc_local_surveys`, each
  `data_elements` entry mapping a DAK element id to the local question's data element code, and a
  mapped answer is read exactly as a native answer to that element.
- **BL-004:** A contact form is the native ANC Registration form
  (`program-whodakanc-registration`) or a mapped survey with `is_contact: true`. A pregnancy's
  first contact is its booking assessment — the WHO ANC1 concept — recorded on whichever form the
  deployment flags as a contact form first in the pregnancy, so there is no separate booking
  metric_id.
- **BL-005:** A contact is a patient with at least one contact-form submission on a day, so two
  contact forms for the same patient on the same day are one contact.
- **BL-006:** A contact's day is its contact form's `ANC.A7.DE4` *Contact date*, falling back to the
  submission's start date where that answer is blank or malformed.
- **BL-007:** Elements attach to a contact from every native or mapped submission for the same
  patient on the contact day, whether or not it shares the contact form's encounter.
- **BL-008:** Where several submissions carry the same element for a contact, the latest
  submitted wins, with an unsubmitted response ordered last.
- **BL-009:** Answers are cast to the type Annex A declares — date, integer, numeric — and an
  answer that does not match reads NULL rather than failing the build.
- **BL-010:** `facility_id` is the facility of the earliest contact-form submission's encounter
  location that day, and is nullable.
- **BL-011:** `age_years` is the woman's age in whole years on the contact day, unbanded; the
  consumer bands it.
- **BL-012:** Every row is a count of 1, and coverage is formed downstream against an externally
  supplied expected-pregnancies estimate.
- **BL-013:** The model is `pii: true`, `classification: restricted` — a row identifies a
  pregnant woman by date and facility.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `(metric_id, subject_id)` is unique | BL-005 | `dbt_utils.unique_combination_of_columns`, severity error |
| AC-002 | `metric_id` is not null and always `who_dak_anc_contact` | BL-001 | `not_null`, `accepted_values` |
| AC-003 | Every `metric_id` is in `metric_definitions` | BL-001 | `relationships`, severity error |
| AC-004 | `value_numeric` is not null and always 1 | BL-012 | `not_null`, `accepted_values` |
| AC-005 | `period_end` equals `period_start` | BL-006 | `dbt_utils.expression_is_true` |
| AC-006 | A native Registration submission is one contact on its recorded contact date, carrying the contact number, and gestational age from a Profile form submitted the same day on another encounter | BL-002, BL-005, BL-007 | unit test `..._native_contact` |
| AC-007 | Two contact forms for one patient on one day are one contact, the later submission's elements win, and the facility is the earlier form's | BL-005, BL-008, BL-010 | unit test `..._native_contact` |
| AC-008 | A blank or malformed contact date falls back to the submission's start date | BL-006, BL-009 | unit test `..._contact_date_fallback` |
| AC-009 | A mapped contact survey yields a contact on its mapped contact date; a mapped survey without `is_contact`, a native non-contact form alone, and an unmapped survey yield none | BL-003, BL-004 | unit test `..._local_mapping` |

## Consumers

1. **Aggregate.** Sum `value_numeric`.
2. **Form coverage downstream**, against the consumer's own expected-pregnancies estimate (BL-012).
3. **Band age in the data table** (BL-011).
4. **Respect `classification: restricted`** (BL-013).

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Implementing `ANC.IND.1`, `ANC.IND.4` and `ANC.IND.5`, which count pregnancies rather than contacts and so need a pregnancy-episode grain | @maui-team | unscheduled |

## Related

| Artefact | Relationship |
|---|---|
| `documentations/metrics/who_dak_anc.yml` | The registered definitions |
| `metric__who_dak_hiv_indicators` | The same pattern over the HIV DAK |
| `metric__birth` | Same dashboard group |
| `tupaia-data-product` `tamanu/who-dak/anc/` | The forms, and `dak-conformance.md` for what they carry |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-21 | Maui team | Initial spec. The antenatal contact count, read from the WHO DAK ANC forms or from a deployment's own forms mapped to DAK element ids. Replaces the `antenatal_contact` and `antenatal_booking` definitions — a booking is a pregnancy's first contact, not a separate metric_id (MAUI-6838). |

# Definition Spec: `episode_pregnancy_samoa` (Samoa Ministry of Health definition)

## Purpose

The WHO SMART guidelines antenatal care DAK counts women by pregnancy: most of its indicators
`ANC.IND.1` to `ANC.IND.13` take their denominator from the ANC records closed in a period, and a
log book or line list numbers each visit within its pregnancy. This model assembles each pregnancy
from a woman's antenatal care contacts and closes it at its outcome, standing in for the DAK's ANC
record where a deployment records antenatal care on its own forms and at clinic visits rather than
on the DAK registration and end forms.

The definition is Samoa Ministry of Health's (`SAMOA_MOH` in the registry), drawn up for its
Antenatal Care Log Book over its own forms mapped to DAK data elements. The DAK supplies the data
elements and the closure reasons; the rules that assemble and close a pregnancy (BL-002, BL-005,
BL-006, BL-010) are Samoa's.

## Identity

| Field | Value |
|---|---|
| **Name** | `derived__episode_pregnancy_samoa` + `derived__episode_pregnancy_samoa_contacts` |
| **Type** | Canonical definition (Samoa Ministry of Health) |
| **Layer** | `derived` (OMOP-lite episode) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` (definition), implemented in `tamanu-dbt-samoa` |
| **Linear issue** | [MAUI-7179](https://linear.app/bes/issue/MAUI-7179) |
| **Registry** | `episode_pregnancy_samoa` (`kind: episode`) in `documentations/metrics/who_dak_anc.yml` |
| **Definition source** | Samoa Ministry of Health (`SAMOA_MOH`) |
| **Created** | 2026-11-16 |

## Grain

- `derived__episode_pregnancy_samoa`: **one row per pregnancy**, `episode_id` identifying it as the woman
  and the day of her first contact.
- `derived__episode_pregnancy_samoa_contacts`: **one row per antenatal contact**, a contact in
  `int__who_dak_anc_contacts` other than a postnatal one (BL-010), with its pregnancy.

## Output schema

### `derived__episode_pregnancy_samoa`

| Column | Type | Description |
|---|---|---|
| `metric_id` | text | Always `episode_pregnancy_samoa` |
| `variant_id` | text | Always NULL (BL-011) |
| `episode_id` | varchar | The woman and the day of her first contact |
| `subject_id` | varchar | The woman |
| `episode_concept_id` | integer | NULL — deferred to the future `vocab__` layer |
| `episode_start_date` | date | Her first contact in the pregnancy |
| `episode_end_date` | date | The pregnancy's end (BL-006), NULL while open |
| `closure_reason` | text | `ANC.End.1` as recorded, `Live birth`, `Woman died` or `Lost to follow-up`. NULL while open, or when an end form gives a date without a reason |
| `closure_source` | text | `end_form`, `birth_record`, `death` or `no_contact`. NULL while open |
| `first_contact_facility_id` | varchar | Facility of her first contact |
| `last_contact_date` | date | Her latest contact in the pregnancy |
| `contact_count` | integer | Contacts in the pregnancy |
| `contact_days` | date[] | The pregnancy's contact days, in order |
| `lmp_date`, `edd_date`, `gravida`, `miscarriages_abortions`, `parity`, `tt_dose_1_date` … `tt_dose_5_date` | | The DAK element as most recently recorded at one of the pregnancy's contacts |

### `derived__episode_pregnancy_samoa_contacts`

| Column | Type | Description |
|---|---|---|
| `episode_id` | varchar | The pregnancy |
| `variant_id` | text | Always NULL (BL-011) |
| `subject_id` | varchar | The woman |
| `contact_day` | date | The day of the contact |
| `facility_id` | varchar | Facility of the contact |
| `episode_contact_number` | integer | The contact's position in its pregnancy, from 1 |
| `gestational_age_weeks` | numeric | Gestational age at the contact (BL-009) |

## Business logic

- **BL-001:** Each row's `metric_id` is `episode_pregnancy_samoa`, registered in
  `documentations/metrics/who_dak_anc.yml`.
- **BL-002:** A contact starts a new pregnancy when it is the woman's first, when more than 140 days
  have passed since her previous contact, or when an outcome event (BL-005) falls on or after her
  previous contact and before this one.
- **BL-003:** A pregnancy runs from its first contact and takes in each later contact until the next
  one starts, so every contact other than a postnatal one (BL-010) belongs to exactly one pregnancy.
- **BL-004:** Each DAK element on the pregnancy is the value most recently recorded at one of its
  contacts.
- **BL-005:** An outcome event is an end-of-pregnancy form (`ANC.End.1`, `.12`, `.38` or `.39`
  answered) dated by its delivery, miscarriage or abortion, or death date, else by its own day; a
  child whose record names the woman as mother, dated by the child's birth; or the woman's death.
- **BL-006:** A pregnancy ends at its highest-ranked outcome event — end form, then child's birth,
  then death, the earliest winning a tie and one that records a closure reason winning a further tie —
  dated from its first contact to 140 days after its last and before the next pregnancy starts, else
  at its last contact as lost to follow-up once more than 140 days have passed, by the deployment's
  local date, without another contact.
- **BL-007:** A pregnancy with no outcome event whose last contact was 140 days ago or less, by the
  deployment's local date, is open, with no end date.
- **BL-008:** A contact's number in its pregnancy is its position by day, counting from 1.
- **BL-009:** A contact's gestational age is the one recorded or worked out that day, else the whole
  weeks from the pregnancy's LMP, or from 280 days before its EDD, kept only between 0 and 45 weeks.
- **BL-010:** A contact in the 42 days after an end-of-pregnancy form's outcome or a child's birth
  is postnatal, and neither starts nor joins a pregnancy.
- **BL-011:** The pregnancy is assembled from the contacts in `int__who_dak_anc_contacts` other than
  postnatal ones (BL-010), and its rows carry a NULL `variant_id`, as a definition of its own rather than a variant of another.
- **BL-012:** Outcome events are read only for women with an antenatal care contact.

## Acceptance criteria

The tests for these criteria live with the implementation in `tamanu-dbt-samoa`.

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `episode_id` is unique and not null | Grain | `unique`, `not_null` |
| AC-002 | `metric_id` is always `episode_pregnancy_samoa` and in `metric_definitions`, and `variant_id` is always NULL | BL-001, BL-011 | `accepted_values`, `relationships`, `dbt_utils.expression_is_true` |
| AC-003 | `(subject_id, contact_day)` is unique in the contacts model | BL-003 | `dbt_utils.unique_combination_of_columns` |
| AC-004 | A 140-day gap continues a pregnancy and a 141-day gap starts one; an outcome event between contacts starts one; elements carry from the latest contact recording them; contacts are numbered within their pregnancy; gestational age comes from the pregnancy's LMP or EDD on a contact with none of its own | BL-002–BL-004, BL-008, BL-009 | unit tests `test_derived__episode_pregnancy_samoa_assembly`, `test_derived__episode_pregnancy_samoa_contacts` |
| AC-005 | An end form outranks a child's birth, which outranks death; an event before the first contact, more than 140 days after the last, or in the next pregnancy does not close it; of two events on the same day, the one with a closure reason closes it; with no event a pregnancy is lost to follow-up after a 140-day gap or once more than 140 days have passed, and open otherwise | BL-005–BL-007 | unit test `test_derived__episode_pregnancy_samoa_closure` |
| AC-006 | A contact 19 days after a child's birth belongs to no pregnancy, and the next contact, 92 days after the birth, starts one, and the contacts model has no row for the postnatal contact | BL-010 | unit tests `test_derived__episode_pregnancy_samoa_closure`, `test_derived__episode_pregnancy_samoa_contacts` |

## Consumers

1. **Indicators by pregnancy** (`ANC.IND.1` to `ANC.IND.13`): denominator from pregnancies closed in
   the period, by `episode_end_date`.
2. **Line lists and log books:** `derived__episode_pregnancy_samoa_contacts` for the visit number and
   gestational age at each contact, joined to `derived__episode_pregnancy_samoa` for the pregnancy's
   elements.
3. **Respect `classification: restricted`**: a row identifies a pregnant woman.

## Related

| Artefact | Relationship |
|---|---|
| `metric__who_dak_anc_indicators` | Counts the same contacts, from the shared `int__who_dak_anc_contacts` |
| `tupaia-data-product` `tamanu/who-dak/anc/` | The DAK registration and end forms |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-20 | Maui team | The implementation, its tests and its inputs moved to `tamanu-dbt-samoa`, as the definition is Samoa Ministry of Health's. A same-day tie between outcome events goes to the one with a closure reason, the 140-day cut-offs count from the deployment's local date, and the contacts grain excludes postnatal contacts (MAUI-7179). |
| 2026-11-16 | Maui team | Initial spec: pregnancies assembled from DAK ANC contacts and closed by their outcome (MAUI-7179). |

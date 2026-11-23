# dbt Model Spec: `derived__episode_art`

## Purpose

A person living with HIV is on ART while they hold ART supply, and lost to follow-up once it has
run out for more than 90 days. This model assembles each continuous period on ART from the ART a
client was supplied, dispensed in Tamanu or recorded on a form, and closes it when the supply
lapses. A later supply after a lapse opens a new, numbered period, which is how a re-initiation is
recorded.

The WHO HIV indicators read their on-ART state, loss to follow-up and re-initiation from these
periods (`metric__who_dak_hiv_indicators` BL-047 to BL-057).

## Identity

| Field | Value |
|---|---|
| **Name** | `derived__episode_art`, with `int__art_supply` and `map__art_medications` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `derived` (OMOP-lite episode), over an `int__` ephemeral and a `map__` view |
| **Materialisation** | env-aware: `table` on `analytics*`, `view` everywhere else. `int__art_supply` is ephemeral and `map__art_medications` a view |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-7225](https://linear.app/bes/issue/MAUI-7225) |
| **Repo** | `tamanu-source-dbt` |
| **Registry** | `episode_art` (`kind: episode`) in `documentations/metrics/who_dak_hiv.yml` |
| **Created** | 2026-11-23 |
| **Last updated** | 2026-11-23 |

## Grain

- `int__art_supply`: **one row per client per supply day**, the ART supplied to them that day.
- `derived__episode_art`: **one row per continuous period on ART per client.**

## Inputs

| Reference | Why we need it |
|---|---|
| `clinical__drug_exposure` | ART prescribed or dispensed in Tamanu, with its quantity |
| `map__art_medications` | Which medications are ART. Empty in the package; each deployment overrides it |
| `int__who_dak_hiv_form_answers` | ART supply recorded on a form (`art_days_dispensed`, HIV.D.DE462), and who the indicators treat as living with HIV |
| `clinical__episode` | The client's HIV registry enrolment, each period's parent |

`map__art_medications` columns: `medication_code` (the medication's reference data code, which
drug exposures carry as `drug_source_value`) and `medication_name`.

## Output schema

### `int__art_supply`

| Column | Type | Description |
|---|---|---|
| `subject_id` | varchar | The client |
| `supply_date` | date | The day ART was supplied |
| `supply_days` | integer | Days of supply (BL-003 to BL-006) |
| `facility_id` | varchar | Facility of the supply's encounter or submission |
| `has_drug_exposure` | boolean | True when a drug exposure supplied ART that day, as opposed to only a form |

### `derived__episode_art`

| Column | Type | Description |
|---|---|---|
| `metric_id` | text | Always `episode_art` |
| `variant_id` | text | Always NULL |
| `episode_id` | varchar | The client and the day the period started |
| `subject_id` | varchar | The client |
| `episode_concept_id` | integer | NULL, deferred to the future `vocab__` layer |
| `episode_parent_id` | varchar | The client's HIV registry enrolment in `clinical__episode`, NULL when they have none |
| `episode_number` | integer | The period's position among the client's periods, from 1 |
| `episode_start_date` | date | The first supply day of the period |
| `supply_end_date` | date | The day the period's supply runs out |
| `last_day_on_art` | date | The last day the client counts as on ART in the period, `supply_end_date` plus the allowance, whether or not that day has passed |
| `episode_end_date` | date | `last_day_on_art` once it has passed. NULL while open |
| `closure_reason` | text | `Lost to follow-up` once closed, NULL while open |
| `is_reinitiation` | boolean | True when `episode_number` is 2 or more |
| `first_supply_facility_id` | varchar | Facility of the period's first supply |
| `last_supply_facility_id` | varchar | Facility of the period's latest supply |
| `supply_count` | integer | Supply days in the period |

## Business logic

### Supply (`int__art_supply`)

- **BL-001:** A supply record is an ART medication in `map__art_medications` on a
  `clinical__drug_exposure` row whose type is listed in the `art_supply_exposure_types` var, or an
  `art_days_dispensed` answer on a WHO HIV form.
- **BL-002:** `art_supply_exposure_types` defaults to `['dispense']`, and a deployment that
  records ART supply as prescriptions sets it to `['prescription']`.
- **BL-003:** A drug exposure supplies its quantity in days, at one unit a day, dated on its start
  date.
- **BL-004:** A form answer supplies `art_days_dispensed` days, dated on its submission's date.
- **BL-005:** A supply of fewer than 1 day or more than 366 days is not a supply record.
- **BL-006:** A client's supply records on the same day are one supply day covering the largest of their
  days, at the facility of the largest drug exposure record that has one, else of the largest form record.
- **BL-007:** Supply is read only for clients the WHO HIV indicators treat as living with HIV
  (`metric__who_dak_hiv_indicators` BL-008).

### Periods on ART (`derived__episode_art`)

- **BL-008:** A supply day's supply runs out on its date plus its days.
- **BL-009:** A period's supply end is the latest run-out date among its supply days.
- **BL-010:** A supply day starts a new period when it is the client's first, or when it falls more
  than 90 days after the latest run-out date of the client's earlier supply days.
- **BL-011:** A period's last day on ART is its supply end plus 90 days, and the client is lost to
  follow-up from the day after.
- **BL-012:** A period whose last day on ART has not passed, by the deployment's local date
  (`get_current_date()`), is open, with no end date or closure reason.
- **BL-013:** A period's number is its position by start date among the client's periods, from 1.
- **BL-014:** A period numbered 2 or more is a re-initiation, dated at its start, and a client's
  first period never is.
- **BL-015:** The 90 days in BL-010 and BL-011 are the `art_ltfu_days` var.
- **BL-016:** A period's parent is the client's earliest enrolment in `clinical__episode` in the
  registry the `art_episode_registry_id` var names, which defaults to the DAK HIV registry
  (`programRegistry-who-dak-hiv`).

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `episode_id` is unique and not null, and `(subject_id, episode_number)` is unique | Grain, BL-013 | `unique`, `not_null`, `dbt_utils.unique_combination_of_columns` |
| AC-002 | `metric_id` is always `episode_art` and in `metric_definitions`, and `variant_id` is always NULL | Registry | `accepted_values`, `relationships`, `dbt_utils.expression_is_true` |
| AC-003 | A dispense of a mapped medication is supply and an unmapped one is not; a prescription is supply only when `art_supply_exposure_types` lists it; a form's days dispensed is supply on its submission's date | BL-001–BL-004 | unit test `test_int__art_supply_sources` |
| AC-004 | Two records on one day are one supply day of the larger days; a quantity of 0 or of 400 is ignored; a client the indicators do not treat as living with HIV has no supply | BL-005–BL-007 | unit test `test_int__art_supply_sources` |
| AC-005 | A 90-day supply followed by one 180 days later continues the period, and one 181 days later starts period 2, a re-initiation; a short supply inside a long one does not shorten the period | BL-008–BL-010, BL-013, BL-014 | unit test `test_derived__episode_art_assembly` |
| AC-006 | A period whose supply ended 90 days before the local date is open, and one that ended 91 days before is closed as `Lost to follow-up` with its end date the supply end plus 90 days | BL-011, BL-012 | unit test `test_derived__episode_art_closure` |
| AC-007 | `episode_end_date` is NULL exactly when `closure_reason` is, and is never before `episode_start_date` | BL-011, BL-012 | `dbt_utils.expression_is_true` |
| AC-008 | `is_reinitiation` is true exactly when `episode_number` is 2 or more | BL-014 | `dbt_utils.expression_is_true` |
| AC-009 | Every non-null `episode_parent_id` is an `episode_id` in `clinical__episode`; a client enrolled in the configured registry has it as every period's parent, and one enrolled only in another registry has none | BL-016 | `relationships`, unit test `test_derived__episode_art_assembly` |

## Lineage

```
clinical__drug_exposure ──┐
map__art_medications ─────┼──► int__art_supply ──► derived__episode_art ──► int__who_dak_hiv_client_month_state
int__who_dak_hiv_form_answers ┘                          ▲                └─► metric__who_dak_hiv_indicators
clinical__episode ───────────────────────────────────────┘
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-23 | Maui team | Initial spec: periods on ART assembled from ART supply, closed 90 days after the supply runs out (MAUI-7225) |

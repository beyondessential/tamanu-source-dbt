# dbt Model Spec: `metric__billing` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__billing` (8 registered indicators) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else (BL-015) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6911](https://linear.app/bes/issue/MAUI-6911/fsm-6-billing-dashboard) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-10-01 |
| **Last updated** | 2026-10-02 |

Canonical definition for patient billing: what each invoice charged, how that charge splits
between insurance, discount and the patient, what the patient has paid against it, and every
patient payment on the day it was received.

## Purpose

Billing activity at a Tamanu facility, for finance dashboards.

| `metric_id` | Unit | Subject | Measures |
|---|---|---|---|
| `invoice` | count | invoice | Invoices (always 1 per row) |
| `invoice_total` | currency | invoice | Invoice total: the sum of discounted item totals |
| `invoice_insurance_coverage` | currency | invoice | The insurer's share of the invoice total |
| `invoice_discount` | currency | invoice | The invoice-level discount |
| `invoice_patient_total` | currency | invoice | The patient's share: total less insurance coverage and discount |
| `invoice_patient_paid` | currency | invoice | Net patient payments made against the invoice to date |
| `invoice_patient_balance` | currency | invoice | Patient share still owed on the invoice |
| `invoice_patient_payment` | currency | payment | One patient payment or refund, on the day it was made |

**Definition source.** `BES`. The amounts follow Tamanu's own invoice arithmetic, as resolved
by `ds__encounter_invoices`, so every figure matches what the invoice screen shows. Care setting
follows the OMOP visit concepts in `clinical__visit_occurrence`.

**Two time bases.** The seven invoice-subject metrics are dated to the invoice, so a month's
figures describe what was billed that month and how much of it has been collected so far. A
payment made later is counted against its invoice's month. `invoice_patient_payment` is dated to
the payment, so a month's figure is the cash received that month. The two reconcile: the
outstanding patient balance at the end of any month is the running sum of
`invoice_patient_total` less the running sum of `invoice_patient_payment`, both up to that month.

**Clinical / operational context.** Tamanu raises one invoice per encounter when the encounter
starts, except for survey-response and vaccination encounters. Payments are made against the whole
invoice, not against its items. A patient admitted from the emergency department stays on one
encounter, so the ED fee, the items ordered before admission and the bed-fee nights all sit on
one invoice.

**Who reads it.** `tupaia-data-product`, via a billing data table over this model, feeding the
FSM billing dashboards (MAUI-6911): monthly billing matrices by care setting, a stacked column
of where each month's billing went, running outstanding and cumulative billed-vs-collected
lines, and headline tiles. Deployment-specific grouping is applied in that data table, not here
(BL-011). FSM uses four categories: IPD (`inpatient`), OPD Dental (any other care setting in a
Dental department), ER (`emergency`) and OPD (everything else). It also excludes
pre-Tamanu-invoicing charges on survey-response encounters.

## Grain

**One row per:** `metric_id` × subject. For the seven invoice metrics the subject is one
non-cancelled invoice. For `invoice_patient_payment` the subject is one patient payment or
refund on a non-cancelled invoice. `(metric_id, subject_id)` is unique (AC-001).

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('ds__encounter_invoices') }}` | Per-invoice resolved billing figures |
| `{{ ref('invoice_payments') }}` | Individual payments and refunds, with dates, read through the shared `invoice_payment_amounts('patient')` macro |
| `{{ ref('invoice_patient_payments') }}` | Marks a payment as a patient payment, read through the same macro |
| `{{ ref('clinical__visit_occurrence') }}` | Visit concept (care setting, ED admission), department, encounter type, location |
| `{{ ref('locations') }}` | Location → facility |

### Required input columns

| Upstream | Columns used |
|---|---|
| `ds__encounter_invoices` | `invoice_id`, `encounter_id`, `status`, `invoice_datetime`, `invoice_total`, `insurance_coverage`, `invoice_discount`, `patient_subtotal`, `patient_payment` |
| `invoice_payments` | `id`, `invoice_id`, `date`, `amount`, `original_payment_id` |
| `invoice_patient_payments` | `invoice_payment_id` |
| `clinical__visit_occurrence` | `visit_occurrence_id`, `visit_concept_id`, `care_site_id`, `department_id`, `visit_source_value` |
| `locations` | `id`, `facility_id` |

### Freshness expectations

Bases refreshed within 24 hours. The current month's figures are month to date.

## Output schema

| Column | Type | Description | Tests |
|---|---|---|---|
| `metric_id` | text | Indicator identifier | `not_null`, `accepted_values`, `relationships` to `metric_definitions` |
| `variant_id` | text | Deployment variant; always NULL here | |
| `subject_id` | varchar | Invoice id, or payment id for `invoice_patient_payment` | `not_null` |
| `period_start` | timestamp | Invoice date and time, or payment date | `not_null` |
| `period_end` | timestamp | Always NULL | |
| `period_granularity` | text | `minute` for invoice metrics, `day` for payments | `not_null`, `accepted_values` |
| `value_numeric` | numeric | The count or amount | `not_null` |
| `value_boolean` | boolean | Always NULL | |
| `invoice_id` | varchar | The invoice the row belongs to | `not_null` |
| `invoice_status` | text | `in_progress` or `finalised` | `not_null`, `accepted_values` |
| `facility_id` | varchar | Facility of the encounter | `not_null` |
| `care_setting` | text | `outpatient`, `emergency`, `inpatient` or `none` | `not_null`, `accepted_values` |
| `visit_concept_id` | integer | The encounter's OMOP Visit concept: 9201, 9202, 9203, 262 or 0 (BL-019) |
| `visit_concept_name` | text | Its OMOP name, e.g. Emergency Room and Inpatient Visit (BL-019) |
| `is_admitted_via_emergency` | boolean | Inpatient encounter with an earlier emergency phase | `not_null` |
| `department_id` | varchar | Department of the encounter | |
| `encounter_type` | text | Tamanu encounter type of the encounter | `not_null` |

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/billing.yml`, and `currency` is an accepted `unit` in the registry,
  meaning an amount in the deployment's billing currency.
- **BL-002 (invoice inclusion):** an invoice is included when its status is `in_progress` or
  `finalised`, and a `cancelled` invoice is excluded along with its payments.
- **BL-003 (invoice dating):** invoice-subject rows take `period_start` from the invoice's
  date and time in deployment-local time, at `minute` granularity.
- **BL-004 (invoice amounts):** `invoice_total`, `invoice_insurance_coverage`,
  `invoice_discount`, `invoice_patient_total` and `invoice_patient_paid` carry
  `ds__encounter_invoices`' `invoice_total`, `insurance_coverage`, `invoice_discount`,
  `patient_subtotal` and `patient_payment` unchanged, with NULL emitted as 0.
- **BL-005 (patient balance):** `invoice_patient_balance` is `invoice_patient_total` less
  `invoice_patient_paid`, and is negative when the invoice is overpaid.
- **BL-006 (invoice count):** `invoice` has `value_numeric` 1 on every row.
- **BL-007 (patient payments):** `invoice_patient_payment` has one row per `invoice_payments`
  row that carries an `invoice_patient_payments` row, dated to the payment's `date` at `day`
  granularity, with a refund's amount negated.
- **BL-008 (payments reconcile):** for every invoice, the `invoice_patient_payment` rows sum to
  its `invoice_patient_paid`.
- **BL-009 (care setting):** `care_setting` maps the encounter's `visit_concept_id`: 9201 and
  262 to `inpatient`, 9203 to `emergency`, 9202 to `outpatient`, and 0 to `none`.
- **BL-010 (admitted via emergency):** `is_admitted_via_emergency` is true when the encounter's
  `visit_concept_id` is 262, and false otherwise.
- **BL-011 (grouping is the consumer's):** `department_id` and `encounter_type` are the
  encounter's current values as Tamanu ids and codes, unresolved and ungrouped.
- **BL-012 (facility):** `facility_id` is the facility of the encounter's location.
- **BL-013 (one setting per invoice):** every row of an invoice, including its payments,
  carries the same `care_setting`, `visit_concept_id`, `visit_concept_name`, `is_admitted_via_emergency`, `department_id`,
  `encounter_type`, `facility_id` and `invoice_status`.
- **BL-014 (rates and running totals are the consumer's):** the model emits counts and
  amounts only, and ratios such as coverage % or payment %, and running totals, are formed by
  the consumer.
- **BL-015 (materialisation):** `table` on targets whose name starts with `analytics`, `view`
  on every other target.
- **BL-016 (unrestricted):** the model carries no patient identifier or patient attribute.
- **BL-017 (current figures):** invoice-subject amounts are the invoice's current figures, so a
  change to an invoice after its month has passed restates that month.
- **BL-018 (one invoice per encounter):** each encounter is expected to have at most one
  non-cancelled invoice, and an encounter with more has each invoice counted as its own subject.
- **BL-019 (visit concept):** `visit_concept_id` and `visit_concept_name` are the encounter's OMOP Visit concept and its name, as `clinical__visit_occurrence` carries them.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `(metric_id, subject_id)` is unique | Grain | `dbt_utils.unique_combination_of_columns` |
| AC-002 | `metric_id` is `not_null` and one of the eight ids | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-003, BL-007 | `not_null` |
| AC-005 | `period_granularity` is `minute` for invoice metrics and `day` for `invoice_patient_payment` | BL-003, BL-007 | singular test |
| AC-006 | `value_numeric` is `not_null`, and is 1 for every `invoice` row | BL-004, BL-006 | `not_null` + singular test |
| AC-007 | `invoice_status` is `not_null` and never `cancelled` | BL-002 | `not_null` + `accepted_values` |
| AC-008 | `invoice_total` = coverage + discount + patient total, per invoice, within 0.01 | BL-004 | singular test |
| AC-009 | `invoice_patient_balance` = `invoice_patient_total` − `invoice_patient_paid`, per invoice | BL-005 | singular test |
| AC-010 | Payment rows sum to `invoice_patient_paid`, per invoice, within 0.01 | BL-007, BL-008 | singular test |
| AC-011 | `care_setting` is `not_null` and one of the four values | BL-009 | `not_null` + `accepted_values` |
| AC-012 | `is_admitted_via_emergency` is `not_null`, and true only where `care_setting` is `inpatient` | BL-010 | `not_null` + singular test |
| AC-013 | `facility_id` and `encounter_type` are `not_null` | BL-011, BL-012 | `not_null` |
| AC-014 | The derivations resolve as specified: a cancelled invoice and its payments are excluded, a refunded payment pair nets to 0, an overpaid invoice has a negative balance, a no-items invoice emits zeros, an ED-then-admitted encounter is `inpatient` with the flag set, a survey-response encounter is `none` | BL-002, BL-004–BL-010 | unit test `ac_014_metric__billing_derivations` |
| AC-015 | No encounter has more than one non-cancelled invoice | BL-018 | singular test (`warn`) |
| AC-016 | `metric_definitions.unit` accepts `currency` | BL-001 | `accepted_values` on the registry |

Singular tests live in one file, `data_test__metric__billing.sql`, one `union all` branch per
AC, tagged with `failed_ac`.

## Lineage

```
upstream                          this model             downstream
ds__encounter_invoices    ──┐
invoice_payments          ──┤
invoice_patient_payments  ──┼──►  metric__billing  ──►  tupaia-data-product: billing data table
clinical__visit_occurrence──┤                                 └►  Tupaia: FSM billing dashboards (MAUI-6911)
locations                 ──┘
```

## Open questions

None.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-01 | Maui team | Initial draft |
| 2026-10-02 | Maui team | BL-018 states the one-invoice-per-encounter expectation AC-015 asserts. Payment rows come from the shared `invoice_payment_amounts()` macro (`specs/dbt-model/invoice_payment_amounts.md`) |

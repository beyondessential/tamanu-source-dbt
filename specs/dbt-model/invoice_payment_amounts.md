# dbt Macro Spec: `invoice_payment_amounts(payer)` (shared)

## Identity

| Field | Value |
|---|---|
| **Name** | `invoice_payment_amounts(payer)` |
| **Type** | dbt macro (shared, embedded by its consumers) |
| **Layer** | intermediate logic, emitted as a subquery |
| **Materialisation** | none — inlined into each consumer |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6911](https://linear.app/bes/issue/MAUI-6911/fsm-6-billing-dashboard) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-10-02 |
| **Last updated** | 2026-10-02 |

## Purpose

One definition of an invoice payment, so that every surface that totals payments reads the same
rows and the same refund flags. Each consumer totals them its own way:

| Consumer | Totals | Rule |
|---|---|---|
| `int__encounter_invoice_amounts` | paid to date per invoice, patient and insurer | `amount` where neither `is_refund` nor `is_reversed` |
| `metric__billing` (`invoice_patient_payment`) | one row per patient payment | `signed_amount`, dated `payment_date` |
| Deployment cash reports (FSM's Daily Cash Collection Summary) | cash per day | `sum(signed_amount)` by `payment_date` |

Both totals agree per invoice because Tamanu has no partial refund: a refund reverses the whole
of its original payment, so a refunded pair is 0 whether both sides are dropped or both are
summed with signs.

**Who consumes it.** The three models above. The macro is embedded rather than exposed as a
model, like `invoice_item_amounts()`, so each consumer keeps `invoice_payments` and the payer's
link table as direct refs and its unit tests mock them directly.

## App parity

| Field | Value |
|---|---|
| **App calculation** | `getInvoiceSummary` in `@tamanu/utils/invoice` (paid to date: payments neither refunding nor refunded) |
| **Branches mirrored** | payer by link table (BL-001), refund by `original_payment_id` (BL-004), reversed by a refund pointing at it (BL-005) |
| **Stored app fields** | `invoices.patient_payment_status`, `invoices.insurer_payment_status` — reconciliation only, not read |
| **Reconciliation** | AC-002, AC-003 |
| **Other surfaces** | Encounter invoice audit report, `clinical__cost`, Tupaia billing, FSM Daily Cash Collection Summary |

## Grain

**One row per:** `invoice_payments` row carried by the chosen payer's link table.

## Inputs

| Reference | Why we need it |
|---|---|
| `{{ ref('invoice_payments') }}` | The payments, their dates, amounts and refund links |
| `{{ ref('invoice_patient_payments') }}` | Marks a patient payment (`payer='patient'`) |
| `{{ ref('invoice_insurer_payments') }}` | Marks an insurer payment (`payer='insurer'`) |

## Output schema

| Column | Type | Description |
|---|---|---|
| `payment_id` | varchar | The payment |
| `invoice_id` | varchar | The invoice it was made against |
| `payment_date` | date | The date recorded on the payment |
| `amount` | numeric | The stored amount, positive for a payment and a refund alike |
| `is_refund` | boolean | The row refunds another payment |
| `is_reversed` | boolean | A refund points at this payment |
| `signed_amount` | numeric | `amount`, negated for a refund |

## Business logic

- **BL-001 (payer):** a row is a payment of `payer` when that payer's link table
  (`invoice_patient_payments` or `invoice_insurer_payments`) carries it, and any other `payer`
  is a compile error.
- **BL-002 (date):** `payment_date` is the payment's own `date`.
- **BL-003 (amount):** `amount` is the stored amount, unchanged.
- **BL-004 (refund):** `is_refund` is true when the payment has an `original_payment_id`.
- **BL-005 (reversed):** `is_reversed` is true when another payment's `original_payment_id`
  points at this one.
- **BL-006 (signed amount):** `signed_amount` is `amount` negated for a refund.
- **BL-007 (no scope filter):** the macro applies no invoice-status, encounter or facility
  filter, and each consumer applies its own.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | Paid to date nets a refunded pair to 0 and counts insurer payments separately | BL-001, BL-004, BL-005 | unit tests `test_int__encounter_invoice_amounts_refund_netting`, `_payment_totals`, `_insurer_payment` |
| AC-002 | An invoice's `invoice_patient_payment` rows sum to its `invoice_patient_paid` | BL-003–BL-006 | `metric__billing` AC-010 (singular test) |
| AC-003 | A refund is a negative payment on its own date | BL-002, BL-006 | unit test `ac_014_metric__billing_derivations` |

## Lineage

```
invoice_payments ─────────┐
invoice_patient_payments ─┼──► invoice_payment_amounts(payer) ──┬──► int__encounter_invoice_amounts ──► ds__encounter_invoices, clinical__cost
invoice_insurer_payments ─┘                                     ├──► metric__billing ──► Tupaia billing
                                                                └──► deployment cash reports
```

## Open questions

None.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-10-02 | Maui team | Initial spec |

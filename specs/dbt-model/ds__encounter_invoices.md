# Dataset Spec: `ds__encounter_invoices`

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__encounter_invoices` |
| **Type** | Consumer-shaped dataset (`ds__`) |
| **Layer** | `ds__` |
| **Materialisation** | env-aware (view in the production bundle) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | _none_ |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-18 |
| **Last updated** | 2026-06-19 |
| **Consumed by** | `audit-encounter-invoice` report (`specs/reports/audit-encounter-invoice.md`) |

## Purpose

Resolve Tamanu's in-app invoice calculations — price-list selection, item discounts, insurance coverage, invoice-level discount, and net patient payments — once, per invoice, so any consumer (the encounter invoice audit report today, billing dashboards tomorrow) reads a single definition rather than re-deriving it. Health-economics has no canonical OMOP layer in the current architecture (decisions.md D2), so this sits as a `ds__` over `bases/`, mirroring `ds__invoice_products`.

## Grain

One row per invoice (every non-deleted invoice, any status). Facility-agnostic: the consumer applies facility or sensitivity scoping. The `status` column lets consumers filter (e.g. exclude cancelled) and aggregate.

## Inputs

`ref('invoices')`, `ref('invoice_items')`, `ref('invoice_products')`, `ref('invoice_price_lists')`, `ref('invoice_price_list_items')`, `ref('invoice_item_discounts')`, `ref('invoice_discounts')`, `ref('invoices_change_logs')`, `ref('invoice_item_finalised_insurances')`, `ref('invoices_invoice_insurance_plans')`, `ref('invoice_insurance_plans')`, `ref('invoice_insurance_plan_items')`, `ref('invoice_payments')`, `ref('invoice_patient_payments')`, and `ref('encounters')` / `ref('locations')` / `ref('facilities')` / `ref('patients')` / `ref('patient_additional_data')` for price-list resolution context.

## Output schema

| Column | Type | Description |
|---|---|---|
| `invoice_id` | text | Primary key |
| `encounter_id` | text | Encounter the invoice belongs to |
| `status` | text | `in_progress` / `finalised` / `cancelled` |
| `invoice_datetime` | timestamp | When the invoice was raised |
| `invoice_finalised_datetime` | timestamp | Most recent transition into finalised, deployment-local; null until finalised |
| `invoice_total` | numeric | Sum of discounted item totals; null when the invoice has no items |
| `insurance_coverage` | numeric | Total insurance coverage on insurable items |
| `invoice_discount` | numeric | Invoice-level discount amount |
| `patient_payment` | numeric | Net patient payment (payments less refunds) |
| `patient_subtotal` | numeric | `invoice_total − insurance_coverage − invoice_discount`, before payments are netted off |
| `products_no_category` | text | No-category products, ordered by item date |

## Business logic

(Clause numbers are shared with the consuming report spec, which this was split from. The invoice-level aggregation lives in `models/intermediate/standard/int__encounter_invoice_amounts.sql` — the ephemeral both this dataset and `clinical__cost` consume; `models/datasets/standard/ds__encounter_invoices.sql` is a thin projection over it. The **per-item** arithmetic below (BL-006/007/008 and the per-item part of BL-010) is implemented once in the shared `invoice_item_amounts()` macro, anchored `BL-002/003/004` in `ds__encounter_invoice_items.md`; this spec describes the same logic from the invoice perspective. The `test_int__encounter_invoice_amounts_*` unit tests target the ephemeral.)

- **BL-006:** Resolve exactly one price list per invoice, mirroring Tamanu's `getIdForPatientEncounter`: match on facility (direct match, or no facility rule and no other current price list claims this facility), patient billing type (the encounter's, falling back to the patient's additional-data billing type), and patient age in completed years at the invoice date (exact value, or min/max range). When several price lists match, the lowest `evaluation_order` wins, then earliest `created_at`, then `code` (price lists with no `evaluation_order` sort last, matching the application).
- **BL-007:** Item unit price falls back through `invoice_items.price_final` → `invoice_items.manual_entry_price` → `invoice_price_list_items.price` → `0`. The price-list item must be non-hidden and bound to the encounter's resolved price list and the item's product.
- **BL-008:** Item discount is applied to `unit_price × quantity`: `percentage` discounts multiply by `(1 − amount)`; `amount` discounts subtract `amount` with no floor (an over-large flat discount yields a negative line total, mirroring the application). With no discount, the result is `unit_price × quantity`.
- **BL-009:** `invoice_total` is the sum of BL-008 across the invoice's items (null when the invoice has no items).
- **BL-010:** Insurance coverage is resolved per insurance plan currently linked to the invoice (mirroring the app's per-plan `insurancePlanItems`). For each plan, the coverage percentage is the finalised snapshot for that (item, plan) when present, otherwise the live per-product coverage, falling back to the plan default, then 0. Percentages are summed across the item's plans, the applied coverage is `min(discounted_total × total_pct / 100, discounted_total)`, summed across insurable items per invoice, rounded to 2 dp.
- **BL-011:** `invoice_discount` is the invoice's discount percentage applied to its patient subtotal (`invoice_total − insurance_coverage`), rounded to 2 dp. Mirrors `getInvoiceLevelDiscountAmount`. Duplicate discounts (no DB uniqueness) resolve to the most recently applied.
- **BL-012:** `patient_payment` is the net patient payment: the sum of payments carrying an `invoice_patient_payments` row that are neither a reversal (`original_payment_id` set) nor themselves reversed (a reversal points at them). A refund reverses the *entire* original (Tamanu has no partial refund), so excluding both sides of a refunded pair yields the net — mirroring the app's `getInvoiceSummary`.
- **BL-013:** `insurer_payment` is the net insurer payment, computed the same way over payments carrying an `invoice_insurer_payments` row. Unlike a patient refund, an insurer payment reversal does **not** get its own `invoice_insurer_payments` row (Tamanu has no insurer-refund endpoint), so the reversal is netted by *excluding the reversed original*, not by a negative-reversal lookup. No `status` filter — `invoice_payments.amount` is the amount actually paid and the insurer status is derived from it, so rejected rows contribute 0 and partial rows their real value. Computed here in the shared ephemeral and consumed by `clinical__cost.paid_by_payer`; `ds__encounter_invoices` does not project it.
- **BL-015:** `invoice_finalised_datetime` is the most recent `logged_at` from `logs.changes` where `status = 'finalised'` and the previous status was not `'finalised'`, presented in the deployment timezone (`var('timezone')`).
- **BL-016:** `products_no_category` concatenates the item name — the finalised `product_name_final`, falling back to the live `invoice_products.name` for in-progress invoices — of the invoice's items whose product has no category, ordered by item `date`.
- **BL-020:** `patient_subtotal` is `invoice_total − coalesce(insurance_coverage, 0) − coalesce(invoice_discount, 0)`, resolved in this dataset's own projection (not the shared `int__encounter_invoice_amounts` ephemeral, since it is not needed by `clinical__cost`) so a consumer needing it — `audit-encounter-invoice`'s BL-013, and `tamanu-dbt-fsm`'s `daily-cash-collection-summary` — reads one definition instead of re-deriving it. NULL when `invoice_total` is NULL (BL-009).

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | `invoice_id` is unique and not null. | grain |
| AC-002 | Each invoice resolves to at most one price list (no item is priced from two price lists); when several match, evaluation_order then created_at then code decides. | BL-006 |
| AC-003 | `invoice_total` equals the sum of per-item discounted totals. | BL-007, BL-008, BL-009 |
| AC-004 | `insurance_coverage <= invoice_total` for every insurable-bearing invoice. | BL-010 |
| AC-005 | Finalised coverage overrides live coverage per plan; a plan with no finalised snapshot still contributes its live coverage to the same item. | BL-010 |
| AC-006 | `patient_payment` nets refunds against their linked payments. | BL-012 |
| AC-007 | `invoice_finalised_datetime` is null until an invoice transitions to finalised, and a re-finalisation does not change it. | BL-015 |
| AC-008 | Price-list `patientType` matching uses the patient's additional-data billing type when the encounter has none. | BL-006 |
| AC-009 | An `amount` (flat) item discount larger than the line total yields a negative discounted total (no floor). | BL-008 |
| AC-010 | `products_no_category` falls back to the live `invoice_products.name` when `product_name_final` is null (in-progress invoices). | BL-016 |
| AC-011 | Combined per-item coverage above 100% is capped at the item's discounted total. | BL-010 |
| AC-012 | A negatively discounted insurable item is included in coverage, capped at the (negative) discounted total. | BL-008, BL-010 |
| AC-013 | `patient_subtotal = invoice_total - coalesce(insurance_coverage, 0) - coalesce(invoice_discount, 0)`, NULL when `invoice_total` is NULL. | BL-020 |

ACs are covered by the `test_int__encounter_invoice_amounts_*` unit tests, except
AC-013 which is covered by `test_ds__encounter_invoices_projection` (the
dataset's own thin-projection contract test), since `patient_subtotal` is
derived in this dataset's projection rather than the shared ephemeral.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-06-18 | Maui team | Initial spec — per-invoice invoice financials extracted from the encounter invoice audit report into a reusable dataset: price-list resolution, item pricing and discount, per-plan insurance coverage, invoice-level discount, payment netting, and finalisation, all mirroring the v2.54 application. |
| 2026-09-04 | Maui team | Added `patient_subtotal` (BL-020), promoting `audit-encounter-invoice`'s own BL-013 formula into this dataset so `tamanu-dbt-fsm`'s new `daily-cash-collection-summary` report does not have to re-derive it independently; `encounter_invoice_audit_report` refactored to sum the column directly instead of re-deriving it from the aggregated components. |

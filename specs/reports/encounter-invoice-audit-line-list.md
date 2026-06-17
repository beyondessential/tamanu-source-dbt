# Report Spec: `encounter-invoice-audit-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `encounter-invoice-audit-line-list` |
| **Type** | Tamanu report (shared macro in `macros/reports/`, standard + sensitive wrappers in `models/reports/`) |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Linear issue** | _none_ |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-17 |
| **Last updated** | 2026-06-17 |

## Purpose

Audit invoices against encounters. Each row reconciles an encounter with its invoice activity (totals, insurance, discounts, payments, outstanding balance) so finance can spot mis-pricing, missing payments, or stranded products without a category.

**Consumer:** Tamanu reporting UI (all deployments running the invoicing module).

**Business context:** Finance needs a per-encounter view that mirrors the in-app calculations — price list selection, item discounts, insurance coverage, and patient payments — to verify what was charged matches what should have been charged.

## Grain

One row per encounter that matches the parameter filters. An encounter without any invoices still appears (invoice columns null). An encounter with multiple invoices is aggregated into one row.

## Inputs

### Parameters

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | (UI default 7 days) | Lower bound on `encounter.start_datetime` (viewer-timezone aware) |
| `toDate` | date | (UI default 7 days) | Upper bound on `encounter.start_datetime` (viewer-timezone aware) |
| `facilityId` | uuid | null | Optional restriction to a single facility |
| `departmentId` | uuid | null | Optional restriction to a single discharging department |
| `patientBillingTypeId` | uuid | null | Optional restriction to a single billing type |
| `supervisingClinicianId` | uuid | null | Optional restriction to a single supervising clinician |
| `includeOpenEncounters` | text (`yes` / `no`) | `yes` | Whether non-discharged encounters are in scope |

### Macro argument

| Argument | Values | Purpose |
|---|---|---|
| `is_sensitive` | `false` (standard) / `true` (sensitive) | Selects the facility partition. The standard wrapper covers non-sensitive facilities; the sensitive wrapper covers sensitive facilities. |

### Upstream models

| Reference | Why we need it |
|---|---|
| `ref('encounters')` | Encounter dimension |
| `ref('locations')`, `ref('facilities')` | Facility for each encounter |
| `ref('patients')` | Patient demographics + DOB for age |
| `ref('departments')`, `ref('users')`, `ref('reference_data')` | Discharging department, supervising clinician, billing type labels |
| `ref('invoices')`, `ref('invoice_items')`, `ref('invoice_products')` | Invoice line items |
| `ref('invoice_price_lists')`, `ref('invoice_price_list_items')` | Price-list resolution and unit prices |
| `ref('invoice_item_discounts')`, `ref('invoice_discounts')` | Item-level and invoice-level discounts |
| `ref('invoices_change_logs')` | Status-change history for finalisation timestamp |
| `ref('invoice_item_finalised_insurances')`, `ref('invoices_invoice_insurance_plans')`, `ref('invoice_insurance_plans')`, `ref('invoice_insurance_plan_items')` | Insurance coverage (snapshotted + live) |
| `ref('invoice_payments')`, `ref('invoice_patient_payments')` | Patient payments and refunds |

## Output schema

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId` | text | Patient display ID |
| `patientFirstName` | text | Patient given name |
| `patientLastName` | text | Patient family name |
| `patientDateOfBirth` | text | Date of birth, formatted |
| `patientAge` | integer | Age in completed years at encounter start |
| `patientSex` | text | Patient sex |
| `patientBillingType` | text | Patient billing type label |
| `encounterStartDateTime` | text | Encounter start, formatted in the viewer's timezone |
| `encounterEndDateTime` | text | Encounter end, formatted in the viewer's timezone (empty for in-progress encounters) |
| `encounterLengthOfStay` | integer | Length of stay in days (minimum 1; for in-progress encounters, days since start) |
| `facility` | text | Facility of the encounter's current location (i.e. final location for discharged encounters) — not necessarily the admission facility if the patient transferred mid-encounter |
| `dischargeDepartment` | text | Department recorded on the encounter |
| `encounterSupervisingClinician` | text | Supervising clinician display name |
| `invoiceFinalisedDateTime` | text | Most recent transition into `finalised` status, in deployment timezone |
| `invoiceTotal` | numeric | Sum of discounted item totals across non-cancelled invoices |
| `insuranceCoverage` | numeric | Sum of per-item insurance coverage across non-cancelled invoices |
| `invoicePatientSubtotal` | numeric | `invoiceTotal − insuranceCoverage − invoiceDiscount` |
| `invoicePatientPayment` | numeric | Net patient payment (payments minus refunds) on non-cancelled invoices |
| `invoicePatientTotal` | numeric | `invoicePatientSubtotal − invoicePatientPayment` (outstanding balance) |
| `invoiceProductsNoCategory` | text | Comma-separated list of products without a category on non-cancelled invoices |

## Business logic

- **BL-001:** Exclude the test patient (`patient_id != var('test_patient')`).
- **BL-002:** Restrict to encounters whose `start_datetime` (in the viewer's selected timezone) falls within `[fromDate, toDate]`. A null bound disables that side of the range.
- **BL-003:** Include non-discharged encounters (those with null `end_datetime`) when `includeOpenEncounters = 'yes'`; exclude them when `'no'`. Default is `'yes'`.
- **BL-004:** Apply optional restrictions on facility, department, patient billing type, and supervising clinician. A null parameter disables that filter.
- **BL-005:** Length of stay is `end_datetime::date − start_datetime::date`, with a minimum of 1 day. For in-progress encounters, use `current_date − start_datetime::date` with the same minimum.
- **BL-006:** Resolve exactly one price list per encounter, mirroring Tamanu's `getIdForPatientEncounter`: match on facility (direct match, or no facility rule and no other current price list claims this facility), patient billing type, and patient age in completed years at encounter start (exact value, or min/max range). Tie-break by `code` ascending then `id`.
- **BL-007:** Item unit price falls back through `invoice_items.price_final` → `invoice_items.manual_entry_price` → `invoice_price_list_items.price` → `0`. The price-list item must be non-hidden and bound to the encounter's resolved price list and the item's product.
- **BL-008:** Item discount is applied to `unit_price × quantity`: `percentage` discounts multiply by `(1 − amount)`; `amount` discounts subtract `amount` with a floor of 0. With no discount, the result is `unit_price × quantity`.
- **BL-009:** Invoice total per encounter sums BL-008 across all non-cancelled invoices.
- **BL-010:** Insurance coverage per insurable item uses snapshotted finalised coverage when present, otherwise the live plan coverage (per-product override, falling back to plan default coverage, falling back to 0). The applied coverage is `min(discounted_total × total_pct / 100, discounted_total)` — capped at the discounted total to handle combined percentages above 100. Sum across insurable items on non-cancelled invoices per encounter, rounded to 2 decimal places.
- **BL-011:** Invoice-level discount applies `invoice_discount_percentage` to each invoice's patient subtotal (`item_total − insurance_coverage`), summed across non-cancelled invoices per encounter, rounded to 2 decimal places. Mirrors Tamanu's `getInvoiceLevelDiscountAmount`, which discounts the post-insurance subtotal, not the gross item total.
- **BL-012:** Patient payment is `sum(payments) − sum(refunds)` on non-cancelled invoices, restricted to payments linked to an `invoice_patient_payments` row. Refunds are identified by `original_payment_id is not null` and subtracted.
- **BL-013:** Patient subtotal is `invoiceTotal − insuranceCoverage − invoiceDiscount`.
- **BL-014:** Patient total is `patientSubtotal − patientPayment`.
- **BL-015:** Invoice finalised datetime per invoice is the most recent `logged_at` from `logs.changes` where `status = 'finalised'` and the previous status was not `'finalised'`, presented in the deployment timezone (`var('timezone')`). When an encounter has multiple invoices, the column shows the maximum across them.
- **BL-016:** `invoiceProductsNoCategory` concatenates the `product_name_final` of items on non-cancelled invoices whose product has no category, ordered by item `date` then invoice `datetime, id`.
- **BL-017:** Facility scope is partitioned by the `is_sensitive` macro argument: the standard variant covers non-sensitive facilities (`is_sensitive = false`); the sensitive variant covers sensitive facilities (`is_sensitive = true`).

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | No rows have `patient_id = var('test_patient')`. | BL-001 |
| AC-002 | All rows have `start_datetime` (viewer timezone) within the supplied `[fromDate, toDate]` window (when bounds are non-null). | BL-002 |
| AC-003 | When `includeOpenEncounters = 'no'`, no rows have `end_datetime is null`. When `'yes'` (or null), rows with `end_datetime is null` may appear. | BL-003 |
| AC-004 | When a parameter filter is non-null, every row matches it (facility, department, billing type, clinician). | BL-004 |
| AC-005 | `encounterLengthOfStay >= 1` for every row. | BL-005 |
| AC-006 | Each encounter resolves to at most one `invoice_price_list_id`. | BL-006 |
| AC-007 | `invoiceTotal` equals the sum of per-item `discounted_total` for non-cancelled invoices on the encounter. | BL-007, BL-008, BL-009 |
| AC-008 | `insuranceCoverage <= invoiceTotal` for every row. | BL-010 |
| AC-009 | `invoicePatientSubtotal = invoiceTotal − coalesce(insuranceCoverage, 0) − coalesce(invoiceDiscount, 0)`. | BL-013 |
| AC-010 | `invoicePatientTotal = invoicePatientSubtotal − coalesce(invoicePatientPayment, 0)`. | BL-014 |
| AC-011 | `invoiceFinalisedDateTime` is null for encounters whose invoices never transitioned to `finalised`. | BL-015 |
| AC-012 | The standard variant returns only non-sensitive facilities; the sensitive variant returns only sensitive facilities. | BL-017 |

Tests: there is no `.yml` for this report (report layer is exempt from generic-test files per `dbt-conventions.md` § Documentation). ACs above are validated by manual run + spot-check against the Tamanu UI.

## Open questions

_None._

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-06-17 | Maui team | Initial spec for the report ported from `tamanu-dbt-fsm` into the shared standard/sensitive macro pattern. |

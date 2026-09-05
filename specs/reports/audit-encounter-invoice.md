# Report Spec: `audit-encounter-invoice`

## Identity

| Field | Value |
|---|---|
| **Name** | `audit-encounter-invoice` |
| **Type** | Tamanu report (shared macro in `macros/reports/`, standard + sensitive wrappers in `models/reports/`) |
| **Layer** | `report` |
| **Materialisation** | `view` |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | _none_ |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-06-17 |
| **Last updated** | 2026-06-23 |

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
| `encounters_core()` | Shared macro resolving encounters to their facility and applying the `is_sensitive` partition (BL-001, BL-017). Reads `ref('encounters')`, `ref('locations')` and `ref('facilities')` — see `specs/dbt-model/encounters_core.md` |
| `ref('patients')` | Patient demographics + DOB for age |
| `ref('departments')`, `ref('users')`, `ref('reference_data')` | Discharging department, supervising clinician, billing type labels |
| `ref('ds__encounter_invoices')` | Per-invoice financials (totals, coverage, discounts, payments, finalisation). Resolves the price-list/coverage/discount logic — see its spec at `specs/dbt-model/ds__encounter_invoices.md` |

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

- **BL-001:** Exclude the test patient (enforced upstream by the `encounters` base model).
  Realised by `encounters_core()` BL-002 — see `specs/dbt-model/encounters_core.md`.
- **BL-002:** Restrict to encounters whose `start_datetime` (in the viewer's selected timezone) falls within `[fromDate, toDate]`. Both bounds are always supplied.
- **BL-003:** Include non-discharged encounters (those with null `end_datetime`) when `includeOpenEncounters = 'yes'`; exclude them when `'no'`. Default is `'yes'`.
- **BL-004:** Apply optional restrictions on facility, department, patient billing type, and supervising clinician. A null parameter disables that filter.
- **BL-005:** Length of stay is `end_datetime::date − start_datetime::date`, with a minimum of 1 day. For in-progress encounters, use `current_date − start_datetime::date` with the same minimum.
- **BL-006 to BL-012, BL-015, BL-016, BL-020 (per-invoice financials):** Price-list resolution, item pricing and discount, invoice total, insurance coverage, invoice-level discount, patient-payment netting, patient subtotal, finalisation timestamp, and the no-category product list are realised per invoice in `ds__encounter_invoices` (see `specs/dbt-model/ds__encounter_invoices.md`).
- **BL-013:** Patient subtotal is `invoiceTotal − insuranceCoverage − invoiceDiscount`, summed per encounter from `ds__encounter_invoices.patient_subtotal` (its BL-020) rather than re-derived from the aggregated components.
- **BL-014:** Patient total is `patientSubtotal − patientPayment`.
- **BL-017:** Facility scope is partitioned by the `is_sensitive` macro argument: the standard variant covers non-sensitive facilities (`is_sensitive = false`); the sensitive variant covers sensitive facilities (`is_sensitive = true`).
  Realised by `encounters_core()` BL-001 — see `specs/dbt-model/encounters_core.md`.
  BL-002, BL-003 and BL-004 above remain this report's own, passed to that macro as
  `extra_predicates` under its row-selecting contract (its BL-004).
- **BL-018:** Aggregate `ds__encounter_invoices` to one row per in-scope encounter, excluding cancelled invoices: invoice total, insurance coverage, invoice discount and patient payment are summed; finalised datetime is the maximum; no-category products are concatenated (ordered by invoice datetime then id). Encounters with no non-cancelled invoices still appear with null invoice columns. An encounter that has a non-cancelled invoice with no items reads a total of 0; an encounter with no invoice at all stays null.
- **BL-019:** Money columns (invoice total, insurance coverage, patient subtotal, patient payment, patient total) are rounded to 2 decimal places for display, matching the application's `formatDisplayPrice`. NULL is preserved.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | No rows have `patient_id = var('test_patient')`. | BL-001 |
| AC-002 | All rows have `start_datetime` (viewer timezone) within the supplied `[fromDate, toDate]` window (when bounds are non-null). | BL-002 |
| AC-003 | When `includeOpenEncounters = 'no'`, no rows have `end_datetime is null`. When `'yes'` (or null), rows with `end_datetime is null` may appear. | BL-003 |
| AC-004 | When a parameter filter is non-null, every row matches it (facility, department, billing type, clinician). | BL-004 |
| AC-005 | `encounterLengthOfStay >= 1` for every row. | BL-005 |
| AC-006 | `invoiceTotal` equals the sum of `ds__encounter_invoices.invoice_total` for the encounter's non-cancelled invoices; cancelled invoices are excluded. | BL-018 |
| AC-007 | An encounter with no non-cancelled invoices has null invoice columns but still appears. | BL-018 |
| AC-008 | `insuranceCoverage <= invoiceTotal` for every row. | BL-010, BL-018 |
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
| 2026-06-18 | Maui team | Initial spec for the report, ported from `tamanu-dbt-fsm` into the shared standard/sensitive macro pattern. Per-invoice financials live in `ds__encounter_invoices`; the report aggregates that dataset per encounter (BL-018). |
| 2026-06-23 | Maui team | Renamed report from `encounter-invoice-audit-line-list` to `audit-encounter-invoice` (config/SQL `audit-encounter-invoice.*`, display name "Audit - encounter invoice"). No logic change. |
| 2026-09-02 | Maui team | Extracted the `encounters_in_scope` CTE into the shared `encounters_core()` macro; BL-001 and BL-017 now resolve there. No behaviour change — verified by a full-project compiled diff (2 of 2952 models changed, both intended, token-identical apart from the macro's superset columns and one redundant wrapping paren). |
| 2026-09-04 | Maui team | BL-013's patient subtotal now sums `ds__encounter_invoices.patient_subtotal` (its new BL-020) instead of re-deriving the formula from the aggregated invoice/insurance/discount sums, prompted by `tamanu-dbt-fsm`'s new `daily-cash-collection-summary` report needing the same formula. No behaviour change — the two aggregation orders are mathematically equivalent (sum of per-invoice differences equals the difference of summed components), verified by unit test and a live replica comparison. |

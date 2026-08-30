# dbt Model Spec: `ds__encounter_invoice_items`

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__encounter_invoice_items` |
| **Type** | dbt model (consumer-shaped dataset) |
| **Layer** | `ds` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6734](https://linear.app/bes/issue/MAUI-6734) (spun off from `clinical__cost` OQ-001 — item-level billing detail) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-26 |
| **Last updated** | 2026-07-26 |

Per-invoice-item billing detail: one row per `invoice_items` line with its resolved
price, discount, discounted total and insurance coverage. This is a **Tamanu billing
construct with no OMOP counterpart** — OMOP `COST` attaches money to clinical *events*
(`drug_exposure`, `procedure_occurrence`, …), not to "invoice items" — so item-level
billing detail lives here in the `ds__` (Tamanu-shaped) layer, **not** in `clinical__`.
The OMOP-native per-event cost surface remains `clinical__cost` at invoice grain (see
its OQ-001 for the future per-event extension).

## Purpose

**Why does this model exist?** To expose the line-item breakdown behind each invoice —
what each product/service was priced at, what discount applied, and how much insurance
covered it — for billing reports and revenue analysis that need per-line detail rather
than the per-invoice totals `ds__encounter_invoices` already provides. The arithmetic
already exists inside `int__encounter_invoice_amounts` (its `item_*` CTEs) but is
aggregated away; this dataset surfaces it at item grain without duplicating logic.

**Who consumes it?** Item-level billing / "products sold" reports, invoice-item audits,
revenue-by-product analysis, and any consumer needing per-line charges. Payment/collection
analysis stays on `ds__encounter_invoices` (payments are invoice-grained — see BL-007).

**Business context:** Tamanu invoicing (all deployments that bill). Complements the
per-invoice `ds__encounter_invoices` and the OMOP `clinical__cost`; the three share one
arithmetic definition via the `int__` layer.

## Grain

**One row per:** non-deleted `invoice_items` row (one billed line).

`invoice_item_id` is the primary key. Facility-agnostic: the consumer applies facility or
sensitivity scoping. All joins below are many-to-one relative to the item, so grain is
preserved.

## Inputs

### Upstream models / sources

| Reference | Why we need it |
|---|---|
| `{{ ref('int__encounter_invoice_item_amounts') }}` | The shared per-item arithmetic (the `invoice_item_amounts()` macro): price resolution, item discount/adjustment, per-item coverage (BL-001) |
| `{{ ref('invoices') }}` | `status`, `datetime`, `encounter_id` for the item's invoice context |

### Required input columns

| Upstream | Columns used |
|---|---|
| `int__encounter_invoice_item_amounts` | `invoice_item_id`, `invoice_id`, `product_id`, `product_name`, `category`, `quantity`, `unit_price`, `item_adjustment`, `discounted_total`, `insurance_coverage`, `source_record_type`, `source_record_id`, `date` |
| `invoices` | `id`, `encounter_id`, `status`, `datetime` |

### Freshness expectations

Bases refreshed within 24 hours (inherits the standard reporting refresh).

## Output schema

| Column | Type | Description | Tests |
|---|---|---|---|
| `invoice_item_id` | character varying(255) | PK — `invoice_items.id` | `not_null`, `unique` |
| `invoice_id` | character varying(255) | Parent invoice | `not_null`, `relationships` → `invoices.id` |
| `encounter_id` | character varying(255) | The invoice's encounter | `not_null` |
| `invoice_status` | text | `in_progress` / `finalised` / `cancelled`, so consumers can exclude cancelled | `accepted_values` |
| `item_date` | date | The line's order/service date | |
| `product_id` | character varying(255) | The invoice product billed | |
| `product_name` | text | Finalised `product_name_final`, falling back to live `invoice_products.name` (BL-005) | |
| `category` | text | Product category (null for uncategorised products) | |
| `quantity` | numeric | Line quantity | |
| `unit_price` | numeric | Resolved unit price (BL-002) | |
| `item_adjustment` | numeric | Signed item adjustment `discounted_total − unit_price × quantity` — negative for a discount, positive for a markup, mirroring the app's `getItemAdjustmentAmount`; 0 when none (BL-003) | |
| `discounted_total` | numeric | `unit_price × quantity` after the item discount (BL-003) | `not_null` |
| `insurance_coverage` | numeric | Per-item insurance coverage, capped at `discounted_total` (BL-004) | |
| `source_record_type` **[ext]** | text | Originating clinical record type: `Prescription` / `LabTest` / `Procedure` / `ImagingRequestArea`, or null for manually-added products (BL-006) | |
| `source_record_id` **[ext]** | character varying(255) | FK into the `source_record_type` table (BL-006) | |

## Business logic

- **BL-001:** One row per invoice item, sourced from the ephemeral
  `int__encounter_invoice_item_amounts`, which is the **`invoice_item_amounts()` macro**.
  The macro holds the per-item arithmetic (price-list resolution, unit price, item
  discount, per-item coverage) and is embedded verbatim by both consumers:
  `int__encounter_invoice_item_amounts` exposes it one row per item, and
  `int__encounter_invoice_amounts` embeds it as `with items as (…)` and *aggregates* to
  invoice grain. One definition, no drift. Embedding via a macro (rather than one
  intermediate `ref()`-ing the other) keeps `invoice_items` / price lists / discounts as
  direct refs of `int__encounter_invoice_amounts`, so its unit tests mock the same bases
  and stay unchanged (AC-008). Sources from `bases/` only — never `public.*`, never a
  `ds__` dataset.
- **BL-002:** `unit_price` falls back through `invoice_items.price_final` →
  `invoice_items.manual_entry_price` → the resolved `invoice_price_list_items.price` → `0`,
  mirroring `getInvoiceItemPrice`. Price-list resolution reuses the invoice's single
  matched price list (as in `int__encounter_invoice_amounts` BL-006).
- **BL-003:** `discounted_total` applies the item discount to `unit_price × quantity`:
  `percentage` discounts multiply by `(1 − amount)`; `amount` discounts subtract `amount`
  with no floor (a negative line total is possible, mirroring the app). Mirrors
  `getInvoiceItemTotalDiscountedPrice`. `item_adjustment` is the **signed** difference
  `discounted_total − unit_price × quantity` — negative for a discount, positive for a
  markup, `0` when neither — mirroring the app's `getItemAdjustmentAmount` (OQ-002
  resolved: match the app's signed convention rather than a positive discount magnitude).
- **BL-004:** `insurance_coverage` is the per-item coverage — for each insurance plan linked
  to the invoice, the finalised snapshot for that (item, plan) when present, else the live
  per-product coverage, else the plan default, else 0; summed across plans and capped at the
  item's `discounted_total`. Mirrors `int__encounter_invoice_amounts` BL-010 at item grain.
- **BL-005:** `product_name` is the finalised `product_name_final`, falling back to the live
  `invoice_products.name` for in-progress invoices (product name is snapshotted at
  finalisation). `category` passes through the live product category (null for uncategorised).
- **BL-006:** `source_record_type` / `source_record_id` carry Tamanu's polymorphic link from
  the item to the clinical record that generated it (`Prescription`, `LabTest`, `Procedure`,
  `ImagingRequestArea`; null for manually-added products). Retained **[ext]** so a future
  OMOP per-event cost model (`clinical__cost` OQ-001) can resolve item `cost_event_id`s; not
  interpreted here.
- **BL-007:** **Payments are not represented at item grain.** Tamanu records patient and
  insurer payments against the invoice, not the item, so this dataset carries charges and
  coverage only; net payments stay on `ds__encounter_invoices`. This is a deliberate
  non-goal, not an omission.
- **BL-008:** `invoice_status` is carried from the invoice so consumers can exclude cancelled
  invoices (whose items still carry charges).

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `invoice_item_id` is `not_null` and `unique` | grain | dbt `not_null` + `unique` |
| AC-002 | Every `invoice_id` exists in `invoices.id` | BL-001 | dbt `relationships` |
| AC-003 | `sum(discounted_total)` per invoice equals `ds__encounter_invoices.invoice_total` (within rounding) — the item breakdown reconciles to the invoice total | BL-001, BL-003 | dbt singular test |
| AC-004 | `sum(insurance_coverage)` per invoice equals `ds__encounter_invoices.insurance_coverage` (within rounding) | BL-004 | dbt singular test |
| AC-005 | `insurance_coverage <= discounted_total` per item (cap) | BL-004 | dbt singular test |
| AC-006 | `invoice_status` is one of `in_progress` / `finalised` / `cancelled` | BL-008 | dbt `accepted_values` |
| AC-007 | `discounted_total` is `not_null` | BL-003 | dbt `not_null` |
| AC-008 | The extraction is behaviour-preserving: `int__encounter_invoice_amounts` output (invoice totals, coverage) is unchanged by embedding the shared macro | BL-001 | existing `test_int__encounter_invoice_amounts_*` unit tests stay green |

ACs are realised by `test_ds__encounter_invoice_items_*` (item grain) plus the reconciliation
singular tests; the per-item arithmetic is unit-tested on `int__encounter_invoice_item_amounts`.

## Lineage

```
invoices, invoice_items,  ──►  int__encounter_        ──┬──►  int__encounter_invoice_amounts ──►  ds__encounter_invoices
  price lists, discounts,        invoice_item_amounts   │                                    └►  clinical__cost (OMOP, invoice grain)
  insurance plans                                       └──►  ds__encounter_invoice_items  (item grain, THIS MODEL)
```

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Should `ds__encounter_invoice_items` also surface the resolved `invoice_price_list_id` / price-list code per line, for pricing audits? Cheap to add if a consumer wants it. | Maui team | — |

## Divergence from current code

Resolved during implementation — none outstanding.

| ID | Divergence | Resolution |
|---|---|---|
| DV-001 | The per-item arithmetic lived inline in `int__encounter_invoice_amounts` (`item_*` CTEs), not shared | **Resolved:** extracted into the `invoice_item_amounts()` macro, embedded by both `int__encounter_invoice_item_amounts` and `int__encounter_invoice_amounts`. Behaviour-preserving (AC-008): the existing `test_int__encounter_invoice_amounts_*` unit tests are unchanged (only the two new `source_record_*` columns added to their `invoice_items` mocks) and green. |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-07-26 | Maui team | Initial draft — item-grain billing detail spun off from `clinical__cost` OQ-001. Item detail is a Tamanu (non-OMOP) construct, so it lives in `ds__`/`int__`; per-item arithmetic shared via the `invoice_item_amounts()` macro; payments intentionally stay invoice-grained. |
| 2026-07-26 | Maui team | Implemented: `invoice_item_amounts()` macro, `int__encounter_invoice_item_amounts`, `ds__encounter_invoice_items` (+ yml/docs), reconciliation singular tests and an item-grain unit test; OQ-002 resolved (signed adjustment). AC tests run green against the 2.57 replica; status → `implemented`. |

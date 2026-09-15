# dbt Model Spec: `clinical__cost` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__cost` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6734](https://linear.app/bes/issue/MAUI-6734) (design spun off from the Queen of Sheba End-of-day Invoice Report) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-07-26 |
| **Last updated** | 2026-07-26 |

The OMOP-lite `COST` domain — the canonical billing surface for Tamanu invoices,
mapping the invoice / charge / payment graph onto OMOP CDM v5.4 Standardized
Health Economics. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

> **Decisions taken (this spec answered its gating question).** OMOP `COST`
> cannot carry the payment-method breakdown (Cash / Mobile Money / Card / …)
> the End-of-day Invoice Report needs, so **that report is built
> non-omop on `ds__encounter_invoices` + a deployment-local payment model**,
> not on `clinical__cost`. `clinical__cost` is nonetheless built as the
> totals-only canonical billing surface for cost / coverage metrics and
> dashboards. The layering conflict was resolved by extracting the
> shared arithmetic into `int__encounter_invoice_amounts`. Model, yml, docs and
> tests are implemented on branch `feature/maui-6734-clinical-cost`, and the
> `AC` tests have been **executed green against the release-2.57 replica** via
> `dbt build --select int__encounter_invoice_amounts ds__encounter_invoices clinical__cost`.
> Status is `implemented`.

## Purpose

**What this artefact measures.** One row per Tamanu invoice (any status —
`invoice_status` is carried so consumers can exclude cancelled invoices), in OMOP
`COST` shape: the amount charged (`total_charge`), the amount actually received
split by payer (`paid_by_patient`, `paid_by_payer`, `total_paid`), and the amount
insurance is expected to cover but may not yet have paid (`amount_allowed`). Each
row is anchored to the OMOP `VISIT_OCCURRENCE` for the encounter the invoice
belongs to.

**Clinical / operational context.** Tamanu records patient billing as `invoices`
(one per encounter), itemised into `invoice_items`, with discounts
(`invoice_item_discounts`, `invoice_discounts`), insurance plans
(`invoices_invoice_insurance_plans` and coverage snapshots), and payments
(`invoice_payments`, split into `invoice_patient_payments` and
`invoice_insurer_payments`). OMOP models money in the `COST` table, linked to a
clinical event via `cost_event_id` + `cost_domain_id`. This model is the contract
between the two.

**Who reads it.** Any consumer needing money-per-encounter without re-deriving
the invoice arithmetic: Tamanu billing reports (the End-of-day Invoice Report and
successors), Tupaia cost/coverage indicators, `metric__` health-economics
measures (cost per visit, coverage rate, collection rate), and ad-hoc analytics.
It is the shared-definition equivalent of `ds__encounter_invoices` but in OMOP
shape and joinable to the clinical event graph.

**Relationship to `ds__encounter_invoices` (layering — must resolve before build).**
The existing `ds__encounter_invoices` dataset already computes the hard
per-invoice arithmetic (price-list resolution, item discounts, insurance
coverage, net patient payment) and is well tested. `clinical__cost` wants that
arithmetic, but a `clinical__` model **cannot `ref()` a `ds__` dataset** —
datasets sit *above* `clinical__` in the layer graph
(bases → clinical → derived → metric → dataset), so reading one here would be a
backwards dependency (D2). The single-source-of-truth requirement therefore
forces a refactor, not a re-derivation: the per-invoice arithmetic must be
extracted **down** into a shared `int__encounter_invoice_amounts` ephemeral that
both `clinical__cost` and `ds__encounter_invoices` consume, with
`ds__encounter_invoices` reduced to a thin projection over it (or over
`clinical__cost` directly). Duplicating the arithmetic in `clinical__cost` is
explicitly rejected — it would let the two definitions drift (see **Decisions taken** above).

## Grain

**One row per:** invoice.

`cost_event_id` is the invoice's `visit_occurrence_id` (the encounter), and
`cost_domain_id` is the constant `'Visit'`. Invoice-level grain is chosen over
item-level because:

- **Payments are invoice-level (the binding reason).** Tamanu records patient and
  insurer payments against the **invoice**, not the item, so the `paid_by_patient`
  / `paid_by_payer` / `total_paid` columns cannot be allocated to item rows without
  a lossy, source-unsupported split. Item-level grain would leave every paid column
  unassignable — so the money side stays invoice-grained regardless of charges.
- **Only charges could go item-level, and only partway.** The item→event link
  *does* exist — `invoice_items.source_record_type` / `source_record_id` is a
  polymorphic FK (observed values: `Prescription`, `LabTest`, `Procedure`,
  `ImagingRequestArea`, plus null for manually-added products). But the OMOP
  targets are only partly built: `Prescription` → `clinical__drug_exposure` and
  `LabTest` → `clinical__measurement` exist (and still need id-mapping), while
  `Procedure` and `ImagingRequestArea` have **no** `clinical__` model yet, and
  null-source items have no event at all. So an item-level `cost_event_id` would
  resolve for only some items and fall back to the visit for the rest.

Item-level costing (one COST row per invoice item, `cost_event_id` → the item's
own event) therefore remains a future extension — not for lack of a source link,
but because payments can't be item-allocated and half the item types lack an OMOP
event target (OQ-001). The *non-OMOP* per-line billing detail (charges, discounts,
coverage per item) is served instead by `ds__encounter_invoice_items`
(`specs/dbt-model/ds__encounter_invoice_items.md`). Grain is
preserved: the shared `int__encounter_invoice_amounts` is one row per invoice
(its `invoice_id` is `not_null` + `unique`), and every join below is many-to-one.

**Performance caveat.** `int__encounter_invoice_amounts` is `ephemeral`, so its
arithmetic (notably the price-list cross join) is now inlined into **both**
`clinical__cost` and `ds__encounter_invoices`; in the `reporting_*` bundle both
are views, so that arithmetic re-executes per downstream query rather than once.
This is accepted for now — if it surfaces in `reporting_*` timings, materialise
the intermediate as a table on the replica (env-aware) so both consumers read it
once.

## Output schema

Columns follow OMOP CDM v5.4 `COST` naming. Tamanu-specific extension columns
(no OMOP `COST` equivalent) are flagged **[ext]** and retained because the
canonical billing surface must not lose information the source carries.

| Column | Type | Notes |
|---|---|---|
| `cost_id` | character varying(255) | `invoices.id`. Native Tamanu string ID — no remap to OMOP integer IDs (D1) |
| `cost_event_id` | character varying(255) | `invoice.encounter_id` → `clinical__visit_occurrence.visit_occurrence_id`. The billed encounter |
| `cost_domain_id` | text | Constant `'Visit'` — costs are attached to the visit, not an itemised event (grain / OQ-001) |
| `invoice_status` **[ext]** | text | Invoice lifecycle status (`in_progress` / `finalised` / `cancelled`) from `int__encounter_invoice_amounts.status`, carried so consumers can exclude cancelled invoices. OMOP `COST` has no status field |
| `cost_type_concept_id` | integer | Constant `32821` ("EHR billing record", OMOP Type Concept) — the cost is derived from the Tamanu billing subsystem |
| `currency_concept_id` | integer | Deployment currency (e.g. GHS for Queen of Sheba), resolved per deployment via a `map__omop_currency` seed or project var. NULL in the universal source-repo model |
| `total_charge` | numeric | Invoice value: `int__encounter_invoice_amounts.invoice_total` (sum of discounted item totals) |
| `total_paid` | numeric | Money actually received: `paid_by_patient` + `paid_by_payer` |
| `paid_by_patient` | numeric | Net patient payment (payments less refunds): `int__encounter_invoice_amounts.patient_payment` |
| `paid_by_payer` | numeric | Insurer payments **actually received**: `int__encounter_invoice_amounts.insurer_payment` (sum of `invoice_payments.amount` linked to `invoice_insurer_payments`, refunds netted). Distinct from `amount_allowed` |
| `amount_allowed` | numeric | Insurance **coverage** (expected, not necessarily paid): `int__encounter_invoice_amounts.insurance_coverage` |
| `discount_amount` **[ext]** | numeric | The **invoice-level** discount (`int__encounter_invoice_amounts.invoice_discount`). OMOP `COST` has no discount field — retained for billing consumers. Item-level discounts are already netted into `total_charge`, not double-counted here (BL-008) |
| `payer_plan_period_id` | varchar | FK to a future `clinical__payer_plan_period`. Typed `varchar` (cast NULL) pending that model — see OQ-002 |
| `cost_source_value` **[ext]** | text | `invoices.display_id` — the human-facing invoice number, for traceability |

**Explicitly NULL / not modelled** (OMOP `COST` columns Tamanu has no source for):
`total_cost` (provider cost of service — not tracked), `paid_patient_copay`,
`paid_patient_coinsurance`, `paid_patient_deductible`, `paid_by_primary`,
`paid_ingredient_cost`, `paid_dispensing_fee`, `revenue_code_concept_id`,
`revenue_code_source_value`, `drg_concept_id`, `drg_source_value`.

**Not representable in this schema at all:** the **payment-method** split
(Cash / Mobile Money / Card / Bank Transfer / Insurance). OMOP `COST` has no
payment-instrument dimension. This was the central design tension, resolved by
keeping `clinical__cost` totals-only (see **Decisions taken** above).

## Business logic

- **BL-001:** One row per invoice (any status), sourced solely from
  `{{ ref('int__encounter_invoice_amounts') }}` (the shared per-invoice
  arithmetic extracted from `ds__encounter_invoices`), which also carries the
  invoice's `display_id` through for `cost_source_value` — so `clinical__cost`
  needs no direct `ref('invoices')`. Never `public.*` (D10) and never a `ds__`
  dataset (backwards layer dependency, D2). Deleted / test-patient filtering is
  inherited upstream. `invoice_status` is carried through **[ext]** so consumers
  can exclude cancelled invoices (which still carry a `total_charge`); the model
  does not filter them, keeping the canonical surface lossless.
- **BL-002:** `cost_event_id` is the invoice's encounter id, and is an FK to
  `clinical__visit_occurrence.visit_occurrence_id`. Every invoice has a non-null
  `encounter_id` upstream, so the FK is total.
- **BL-003:** `total_charge` is `int__encounter_invoice_amounts.invoice_total` —
  the sum of discounted item totals. `clinical__cost` does not re-derive it.
- **BL-004:** `amount_allowed` is `int__encounter_invoice_amounts.insurance_coverage`
  (the amount insurance is expected to cover) and is kept strictly separate from
  `paid_by_payer` (money the insurer has actually paid). Coverage is an
  expectation; a payment is a receipt.
- **BL-005:** `paid_by_patient` is `int__encounter_invoice_amounts.patient_payment`
  — the net patient payment (refunds already netted upstream).
- **BL-006:** `paid_by_payer` is `int__encounter_invoice_amounts.insurer_payment`
  — the sum of `invoice_payments.amount` for payments carrying an
  `invoice_insurer_payments` row, with reversed payments netted by **excluding the
  reversed original** (an insurer reversal, unlike a patient refund, carries no
  `invoice_insurer_payments` row of its own, so it cannot be found by a
  negative-reversal lookup). Aggregated in the shared ephemeral (not here) so
  patient and insurer receipts have one definition, mirroring the app's
  `getInvoiceSummary`. **No status filter:** `invoice_payments.amount` is the amount
  *actually* paid and the insurer `status` is derived from it in the app
  (`getInvoiceInsurerPaymentStatus`: 0 → rejected, full → paid, part → partial), so
  rejected rows contribute 0 and partial rows contribute their real received value.
- **BL-007:** `total_paid` is `paid_by_patient + paid_by_payer` — all money
  received against the invoice, patient and insurer. This is the value the
  invoice report surfaces as "Total received".
- **BL-008:** `discount_amount` is `int__encounter_invoice_amounts.invoice_discount`
  — the **invoice-level** discount only. Tamanu applies discounts at two distinct
  levels (verified in `packages/utils/src/invoice/`): a per-**item** discount
  (`invoice_item_discounts`, `getInvoiceItemTotalDiscountedPrice`) that is baked
  into each line and therefore already netted into `total_charge`, and a per-
  **invoice** discount (`invoice_discounts`, `getInvoiceLevelDiscountAmount`) — a
  percentage applied to the patient subtotal. These are separate quantities in the
  app (`getInvoiceSummary` exposes item adjustments and the invoice discount as
  different lines), so there is **no double-counting**: `total_charge` stays on the
  net (post-item-discount) basis and `discount_amount` carries only the invoice
  discount. Surfacing the item-adjustment total as its own `[ext]` column is a
  possible future extension, not needed now.
- **BL-009:** `currency_concept_id` is the deployment's billing currency, resolved
  **per deployment**: the universal source-repo model leaves it NULL, and a
  deployment override supplies the concept via a `map__omop_currency` seed or a
  project var.
- **BL-010:** Money columns default to 0, not NULL, when the invoice has no
  charge / payment / coverage of that kind, so downstream sums never need
  `coalesce`. (An invoice with no items has `total_charge = 0`, etc.)

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `cost_id` is `not_null` | grain | dbt `not_null` |
| AC-002 | `cost_id` is `unique` | grain | dbt `unique` |
| AC-003 | Every `cost_event_id` exists in `clinical__visit_occurrence.visit_occurrence_id` | BL-002 | dbt `relationships` |
| AC-004 | `cost_domain_id` is `not_null` and always `'Visit'` | BL-001 | dbt `not_null` + `accepted_values` |
| AC-005 | `total_paid` equals `paid_by_patient + paid_by_payer` for every row (within rounding) | BL-007 | dbt singular test |
| AC-006 | `total_charge`, `total_paid`, `paid_by_patient`, `paid_by_payer`, `amount_allowed`, `discount_amount` are all `not_null` | BL-010 | dbt `not_null` |
| AC-007 | Row count equals `int__encounter_invoice_amounts` row count (no invoices dropped or duplicated) | BL-001 | dbt singular test |
| AC-008 | Every non-null `payer_plan_period_id` exists in `clinical__payer_plan_period` | BL-001 | dbt `relationships` (activated once that model exists — OQ-002) |
| AC-009 | `invoice_status` is `not_null` and one of `in_progress` / `finalised` / `cancelled` | BL-001 | dbt `not_null` + `accepted_values` |

## Registry entry

None. `clinical__` models are canonical clinical / billing facts, not indicators
or derived elements — only `metric__` and `derived__` artefacts get a
`metric_definitions.csv` row (D5, dbt-conventions § Documentation). A
`metric__cost_per_visit` or `metric__collection_rate` built on top of this model
would carry the registry row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__encounter_invoice_amounts` | `int/` | The shared per-invoice arithmetic (extracted from `ds__encounter_invoices`): charge, coverage, invoice-level discount, `status`, net patient payment **and net insurer payment**, plus `display_id` carried through for `cost_source_value` (BL-001, BL-003..BL-006, BL-008) |
| `clinical__visit_occurrence` | `clinical/` | `cost_event_id` FK target (AC-003) |
| `clinical__payer_plan_period` | `clinical/` | *Future* — `payer_plan_period_id` FK target (OQ-002) |

(`clinical__cost`'s only direct `ref()` is `int__encounter_invoice_amounts`. The
`invoices` `display_id` reaches it *through* the shared ephemeral — `clinical__cost`
does not `ref('invoices')` directly. `invoice_payments` / `invoice_insurer_payments`
are likewise consumed by `int__encounter_invoice_amounts`, not by `clinical__cost`.)

## Lineage

```
invoice_payments    ──┐
invoice_insurer_    ──┼──►  int__encounter_   ──┬──►  clinical__cost  ──►  metric__cost_* / reports
  payments             │      invoice_amounts   │    (display_id →     └►  Tupaia cost & coverage
invoices, items,    ──┘      (carries display_id)│     cost_source_value)
  price lists, ...                               └──►  ds__encounter_invoices
clinical__visit_    ─────►  clinical__cost   (cost_event_id FK)
  occurrence
```

## Open questions

(Only still-open items are listed. Resolved questions are recorded in the spec
body: currency-per-deployment in BL-009, the item-vs-invoice discount split in
BL-008, `cost_type_concept_id = 32821` ("EHR billing record") in the output
schema, and the payment-method / layering decisions under **Decisions taken**.)

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | **OMOP per-event cost** — a `COST` row per clinical *event* (`cost_event_id` → `drug_exposure` / a future `procedure_occurrence`), the OMOP-native way to cost per service. The source link exists (`invoice_items.source_record_type`/`source_record_id`: `Prescription`, `LabTest`, `Procedure`, `ImagingRequestArea`, null), but it is blocked on: (a) payments are invoice-level and can't be item-allocated; (b) only `Prescription`→`clinical__drug_exposure` and `LabTest`→`clinical__measurement` have OMOP targets — `Procedure`/`ImagingRequestArea` need new `clinical__` models first. Revisit when `clinical__procedure_occurrence` exists. (The *non-OMOP* per-invoice-item billing detail is handled separately by `ds__encounter_invoice_items`.) | Maui team | future |
| OQ-002 | Build a companion `clinical__payer_plan_period` (OMOP `PAYER_PLAN_PERIOD`) for insurance-plan coverage windows, so `payer_plan_period_id` resolves? Out of scope for this spec; tracked here. | Maui team | — |

## Divergence from current code

Not applicable — greenfield design spec, no existing `clinical__cost`
implementation to reconcile.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-07-26 | Maui team | Initial draft — OMOP `COST` design spun off from MAUI-6734; then implemented: `int__encounter_invoice_amounts` extraction, `ds__encounter_invoices` refactor, `clinical__cost` model + tests. Payment-method split and shared-arithmetic layering resolved. AC tests run green against the 2.57 replica; status → `implemented` |

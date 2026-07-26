# dbt Model Spec: `clinical__cost` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__cost` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics_*`) |
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
> the End-of-day Invoice Report needs (OQ-001), so **that report is built
> non-omop on `ds__encounter_invoices` + a deployment-local payment model**,
> not on `clinical__cost`. `clinical__cost` is nonetheless built as the
> totals-only canonical billing surface for cost / coverage metrics and
> dashboards. The layering conflict (OQ-007) was resolved by extracting the
> shared arithmetic into `int__encounter_invoice_amounts`. Model, yml, docs and
> tests are implemented on branch `feature/maui-6734-clinical-cost`, and the
> `AC` tests have been run green against the release-2.57 replica via
> `dbt build --select int__encounter_invoice_amounts ds__encounter_invoices clinical__cost`.

## Purpose

**What this artefact measures.** One row per finalised or in-progress Tamanu
invoice, in OMOP `COST` shape: the amount charged (`total_charge`), the amount
actually received split by payer (`paid_by_patient`, `paid_by_payer`,
`total_paid`), and the amount insurance is expected to cover but may not yet
have paid (`amount_allowed`). Each row is anchored to the OMOP `VISIT_OCCURRENCE`
for the encounter the invoice belongs to.

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
explicitly rejected — it would let the two definitions drift. See OQ-007.

## Grain

**One row per:** invoice.

`cost_event_id` is the invoice's `visit_occurrence_id` (the encounter), and
`cost_domain_id` is the constant `'Visit'`. Invoice-level grain is chosen over
item-level because:

- Tamanu payments (patient and insurer) are recorded at the **invoice** level,
  not the item level — item-level `COST` rows would require allocating payments
  across items, which is lossy and not represented in the source.
- Item → clinical-event linkage (invoice_product → `clinical__drug_exposure` /
  a future `clinical__procedure_occurrence`) does not exist in the omop-lite
  layer yet, so item-level `cost_event_id` could not point at a real event.

Item-level costing is a documented future extension — see OQ-004. Grain is
preserved: the shared `int__encounter_invoice_amounts` is one row per invoice
(its `invoice_id` is `not_null` + `unique`), and every join below is many-to-one.

## Output schema

Columns follow OMOP CDM v5.4 `COST` naming. Tamanu-specific extension columns
(no OMOP `COST` equivalent) are flagged **[ext]** and retained because the
canonical billing surface must not lose information the source carries.

| Column | Type | Notes |
|---|---|---|
| `cost_id` | uuid | `invoices.id`. Native UUID PK — no remap to OMOP integer IDs (D1) |
| `cost_event_id` | uuid | `invoice.encounter_id` → `clinical__visit_occurrence.visit_occurrence_id`. The billed encounter |
| `cost_domain_id` | text | Constant `'Visit'` — costs are attached to the visit, not an itemised event (grain / OQ-004) |
| `cost_type_concept_id` | integer | Constant provenance concept — the invoice originates in the Tamanu billing system. Concept TBD (OQ-005) |
| `currency_concept_id` | integer | Deployment currency (e.g. GHS for Queen of Sheba). Universal model cannot hardcode one currency — see OQ-002. NULL until resolved |
| `total_charge` | numeric | Invoice value: `int__encounter_invoice_amounts.invoice_total` (sum of discounted item totals) |
| `total_paid` | numeric | Money actually received: `paid_by_patient` + `paid_by_payer` |
| `paid_by_patient` | numeric | Net patient payment (payments less refunds): `int__encounter_invoice_amounts.patient_payment` |
| `paid_by_payer` | numeric | Insurer payments **actually received** — summed from `invoice_payments` linked to `invoice_insurer_payments`. Distinct from `amount_allowed` |
| `amount_allowed` | numeric | Insurance **coverage** (expected, not necessarily paid): `int__encounter_invoice_amounts.insurance_coverage` |
| `discount_amount` **[ext]** | numeric | Total adjustments (discounts). OMOP `COST` has no discount field — retained for billing consumers. Invoice-level discount from `int__encounter_invoice_amounts.invoice_discount`; item-level scope is OQ-003 |
| `payer_plan_period_id` | uuid | FK to a future `clinical__payer_plan_period`. NULL until that model exists (OQ-006) |
| `cost_source_value` **[ext]** | text | `invoices.display_id` — the human-facing invoice number, for traceability |

**Explicitly NULL / not modelled** (OMOP `COST` columns Tamanu has no source for):
`total_cost` (provider cost of service — not tracked), `paid_patient_copay`,
`paid_patient_coinsurance`, `paid_patient_deductible`, `paid_by_primary`,
`paid_ingredient_cost`, `paid_dispensing_fee`, `revenue_code_concept_id`,
`revenue_code_source_value`, `drg_concept_id`, `drg_source_value`.

**Not representable in this schema at all:** the **payment-method** split
(Cash / Mobile Money / Card / Bank Transfer / Insurance). OMOP `COST` has no
payment-instrument dimension. This is the central design tension — see OQ-001.

## Business logic

- **BL-001:** One row per invoice, sourced from
  `{{ ref('int__encounter_invoice_amounts') }}` (the shared per-invoice
  arithmetic extracted from `ds__encounter_invoices` — see OQ-007) plus `bases/`
  payment tables — never `public.*` (D10) and never a `ds__` dataset (backwards
  layer dependency, D2). Deleted / test-patient filtering is inherited upstream.
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
- **BL-006:** `paid_by_payer` is the sum of `invoice_payments.amount` for
  payments carrying an `invoice_insurer_payments` row, netted for refunds by the
  same `original_payment_id` rule the patient-payment aggregate uses upstream.
  A refund is negated only when it shares the insurer-payment linkage of the
  payment it reverses.
- **BL-007:** `total_paid` is `paid_by_patient + paid_by_payer` — all money
  received against the invoice, patient and insurer. This is the value the
  invoice report surfaces as "Total received".
- **BL-008:** `discount_amount` is `int__encounter_invoice_amounts.invoice_discount`
  (the invoice-level discount). Whether item-level discounts should also be
  folded in is OQ-003; if so, `total_charge` must switch to a gross basis to
  avoid double-counting.
- **BL-009:** `currency_concept_id` is the deployment's billing currency. The
  universal source-repo model leaves it NULL; a deployment override supplies the
  concept via a `map__omop_currency` seed or a project var (OQ-002).
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
| AC-008 | Every non-null `payer_plan_period_id` exists in `clinical__payer_plan_period` | BL-001 | dbt `relationships` (activated once that model exists — OQ-006) |

## Registry entry

None. `clinical__` models are canonical clinical / billing facts, not indicators
or derived elements — only `metric__` and `derived__` artefacts get a
`metric_definitions.csv` row (D5, dbt-conventions § Documentation). A
`metric__cost_per_visit` or `metric__collection_rate` built on top of this model
would carry the registry row.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `int__encounter_invoice_amounts` | `int/` | *To be extracted (OQ-007).* Per-invoice charge, coverage, net patient payment, invoice-level discount — the shared invoice arithmetic currently inside `ds__encounter_invoices` (BL-003..BL-005, BL-008) |
| `invoice_payments` | `bases/` | Payment amount, date, refund linkage — insurer-payment aggregate (BL-006) |
| `invoice_insurer_payments` | `bases/` | Marks which payments are insurer payments (BL-006) |
| `invoices` | `bases/` | `encounter_id` (→ `cost_event_id`), `display_id` (→ `cost_source_value`) |
| `clinical__visit_occurrence` | `clinical/` | `cost_event_id` FK target (AC-003) |
| `clinical__payer_plan_period` | `clinical/` | *Future* — `payer_plan_period_id` FK target (OQ-006) |

## Lineage

```
                         ┌──►  clinical__cost  ──►  metric__cost_* / billing reports
int__encounter_      ────┤                      └►  Tupaia cost & coverage indicators
  invoice_amounts        └──►  ds__encounter_invoices  (refactored to consume it — OQ-007)

invoices            ──┐
invoice_payments    ──┼──►  clinical__cost   (insurer-payment aggregate, source values)
invoice_insurer_    ──┘
  payments
clinical__visit_    ─────►  clinical__cost   (cost_event_id FK)
  occurrence
```

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | **Resolved (option a).** OMOP `COST` has no payment-method dimension. `clinical__cost` stays totals-only; the MAUI-6734 report gets its Cash / Mobile Money / Card / Bank Transfer / Insurance split from a deployment-local payment model, not from `clinical__cost`. A future `clinical__payment` companion (method-grained) remains an option if metrics need the split — not built now. | Data Lead | done |
| OQ-002 | How does a universal source-repo model carry deployment currency? `map__omop_currency` seed vs project var vs leave NULL and set per-deployment. Queen of Sheba is GHS. | Data Lead | — |
| OQ-003 | Does "Total item adjustments" mean invoice-level discount only (available directly), or item-level + invoice-level discounts combined? If combined, `total_charge` must be gross (pre-discount) to avoid double counting. Confirm with the MAUI-6734 PM. | @erin | — |
| OQ-004 | Item-level `COST` grain (one row per invoice item, `cost_event_id` → drug/procedure event) — worthwhile future extension, or does invoice-level grain suffice indefinitely? Depends on Tupaia / metric demand for cost-per-service. | Data Lead | — |
| OQ-005 | Which OMOP concept for `cost_type_concept_id` best encodes "Tamanu billing system origin"? | Data Lead | — |
| OQ-006 | Build a companion `clinical__payer_plan_period` (OMOP `PAYER_PLAN_PERIOD`) for insurance-plan coverage windows, so `payer_plan_period_id` resolves? Out of scope for this spec; tracked here. | Data Lead | — |
| OQ-007 | **Resolved.** Extracted the per-invoice arithmetic into `int__encounter_invoice_amounts` (ephemeral) and reduced `ds__encounter_invoices` to a thin projection over it — behaviour-preserving (same columns, order, semantics), so its existing `.yml`, tests and downstream refs are untouched. Reviewer must still confirm the refactor of this tested, in-use dataset is acceptable. | Data Lead | done |

## Divergence from current code

Not applicable — greenfield design spec, no existing `clinical__cost`
implementation to reconcile.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-07-26 | Maui team | Initial draft — OMOP `COST` design spun off from MAUI-6734; then implemented: `int__encounter_invoice_amounts` extraction, `ds__encounter_invoices` refactor, `clinical__cost` model + tests. Status → `review`; OQ-001 / OQ-007 resolved. AC tests defined, not yet run against a DB |

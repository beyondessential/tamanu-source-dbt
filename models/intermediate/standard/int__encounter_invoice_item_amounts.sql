-- int__encounter_invoice_item_amounts -- shared per-invoice-item billing arithmetic.
-- One row per invoice item: price-list resolution, unit price, item discount/adjustment,
-- and per-item insurance coverage. The logic is the invoice_item_amounts() macro, embedded
-- verbatim by int__encounter_invoice_amounts (which aggregates it to invoice grain) so both
-- share one definition without drift. Deleted / test-patient filtering is inherited from
-- bases. See specs/dbt-model/ds__encounter_invoice_items.md. Ephemeral: inlined by consumers.

{{ invoice_item_amounts() }}

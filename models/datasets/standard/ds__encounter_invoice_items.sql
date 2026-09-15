-- ds__encounter_invoice_items -- one row per invoice item with its resolved billing
-- figures. This is the item-grain (line-level) companion to ds__encounter_invoices:
-- price, discount/adjustment and insurance coverage per line. It is a Tamanu billing
-- construct with no OMOP counterpart, so it lives in the ds__ layer, not clinical__.
-- The per-item arithmetic is the shared int__encounter_invoice_item_amounts (also
-- aggregated by int__encounter_invoice_amounts), so line detail and invoice totals
-- reconcile by construction. Payments are invoice-grained and are NOT represented here
-- (BL-007) -- see ds__encounter_invoices. See specs/dbt-model/ds__encounter_invoice_items.md.

with items as (
    select * from {{ ref('int__encounter_invoice_item_amounts') }}
),

invoices as (
    select * from {{ ref('invoices') }}
)

select
    -- BL-001: one row per invoice item
    it.invoice_item_id,
    it.invoice_id,
    i.encounter_id,
    -- BL-008: invoice status, carried so consumers can exclude cancelled invoices
    i.status as invoice_status,
    it.date as item_date,
    it.product_id,
    -- BL-005: finalised product name, falling back to the live name
    it.product_name,
    it.category,
    it.quantity,
    -- BL-002: resolved unit price
    it.unit_price,
    -- BL-003: signed item adjustment (negative discount / positive markup)
    it.item_adjustment,
    it.discounted_total,
    -- BL-004: per-item insurance coverage, capped at the line's discounted total. Left
    -- raw (like discounted_total) so the per-line values sum exactly to the invoice
    -- coverage on ds__encounter_invoices, which rounds the total
    it.insurance_coverage,
    -- BL-006: polymorphic link to the originating clinical record
    it.source_record_type,
    it.source_record_id
from items it
join invoices i
    on i.id = it.invoice_id

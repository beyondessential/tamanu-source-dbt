-- ds__encounter_invoices -- one row per invoice with the resolved billing figures.
-- The per-invoice arithmetic lives in int__encounter_invoice_amounts so that
-- clinical__cost can share the same source of truth without a backwards
-- clinical->ds dependency (D2). This dataset is a thin projection over it: the
-- projected columns carry that model's semantics unchanged, and patient_subtotal
-- is derived here from three of them.
-- See specs/dbt-model/clinical__cost.md.

select
    invoice_id,
    encounter_id,
    status,
    invoice_datetime,
    invoice_finalised_datetime,
    invoice_total,
    insurance_coverage,
    invoice_discount,
    patient_payment,
    -- BL-020 (see specs/dbt-model/ds__encounter_invoices.md): patient
    -- subtotal, resolved once here so consumers read one definition rather
    -- than re-deriving it. Null when invoice_total is null (a no-items
    -- invoice), which a consumer aggregating it has to coalesce.
    invoice_total - coalesce(insurance_coverage, 0) - coalesce(invoice_discount, 0) as patient_subtotal,
    products_no_category
from {{ ref('int__encounter_invoice_amounts') }}

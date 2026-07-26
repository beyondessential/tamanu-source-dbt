-- ds__encounter_invoices -- one row per invoice with the resolved billing figures.
-- The per-invoice arithmetic now lives in int__encounter_invoice_amounts so that
-- clinical__cost can share the same source of truth without a backwards
-- clinical->ds dependency (D2). This dataset is a thin projection over it and
-- preserves its original output contract exactly (column set, order, semantics).
-- See specs/dbt-model/clinical__cost.md (OQ-007).

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
    products_no_category
from {{ ref('int__encounter_invoice_amounts') }}

{% macro encounter_invoices_dataset(is_sensitive=false) %}
{#-
    One row per invoice with the resolved billing figures, for one facility partition.
    Materialised by ds__encounter_invoices (standard) and ds__sensitive_encounter_invoices.

    The per-invoice arithmetic lives in encounter_invoice_amounts(), through the
    int__encounter_invoice_amounts pair, so clinical__cost shares the same source of truth
    without a backwards clinical->ds dependency (D2). This dataset is a thin projection over
    it: the projected columns carry that model's semantics unchanged, and patient_subtotal
    is derived here from four of them. See specs/dbt-model/ds__encounter_invoices.md.
-#}
select
    invoice_id,
    encounter_id,
    status,
    invoice_datetime,
    invoice_finalised_datetime,
    invoice_total,
    item_adjustment,
    insurance_coverage,
    invoice_discount,
    patient_payment,
    -- BL-020 (see specs/dbt-model/ds__encounter_invoices.md): patient
    -- subtotal, resolved once here so consumers read one definition rather
    -- than re-deriving it. Null when invoice_total is null (a no-items
    -- invoice), which a consumer aggregating it has to coalesce.
    invoice_total + item_adjustment
    - coalesce(insurance_coverage, 0) - coalesce(invoice_discount, 0) as patient_subtotal,
    products_no_category
from {{ ref('int__sensitive_encounter_invoice_amounts' if is_sensitive else 'int__encounter_invoice_amounts') }}
{% endmacro %}

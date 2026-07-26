-- int__encounter_invoice_amounts -- shared per-invoice billing arithmetic.
-- One row per invoice: item totals and insurance coverage (aggregated from the shared
-- per-item arithmetic in the invoice_item_amounts() macro), invoice-level discount, net
-- patient payment, net insurer payment, and finalisation. Consumed by both
-- ds__encounter_invoices (dataset) and clinical__cost (OMOP COST) so there is one source
-- of truth without a backwards clinical->ds dependency (D2). The per-item arithmetic is
-- the invoice_item_amounts() macro -- embedded here (so invoice_items / price lists /
-- discounts stay direct refs for unit testing) and also exposed one row per item by
-- int__encounter_invoice_item_amounts, which ds__encounter_invoice_items consumes.
-- See specs/dbt-model/clinical__cost.md. Ephemeral: inlined by consumers.

with items as (
    -- Per-item price (BL-006/007), item discount (BL-008) and coverage (BL-010) as this
    -- dataset's spec describes them; implemented by the shared invoice_item_amounts() macro
    -- (anchored BL-002/003/004 in ds__encounter_invoice_items.md). Aggregated to invoice grain.
    {{ invoice_item_amounts() }}
),

invoice_finalised as (
    -- BL-015: most recent transition into finalised status per invoice
    select
        icl.invoice_id,
        max(icl.logged_at at time zone '{{ var("timezone") }}') as finalised_at
    from {{ ref('invoices_change_logs') }} icl
    where
        icl.status = 'finalised'
        and (icl.previous_status is null or icl.previous_status != 'finalised')
    group by icl.invoice_id
),

insurance_coverage_agg as (
    -- BL-010: per-invoice insurance coverage -- the sum of the per-item coverage
    -- (already capped at each item's discounted total in the macro), rounded to 2 dp.
    -- Per-item coverage is null for items with no coverage, so an invoice with no insured
    -- items sums to null (not 0), matching the app's absence of coverage.
    select
        invoice_id,
        round(sum(insurance_coverage), 2) as insurance_coverage
    from items
    group by invoice_id
),

invoice_items_agg as (
    -- BL-009: invoice item total (sum of discounted item totals)
    select
        invoice_id,
        -- BL-016: names of the invoice's products that have no category, ordered by item date
        string_agg(
            product_name, ', '
            order by date
        ) filter (where category is null) as products_no_category,
        sum(discounted_total) as item_total
    from items
    group by invoice_id
),

invoice_discount_pct as (
    -- BL-011: Tamanu enforces one discount per invoice (application logic, no DB
    -- unique constraint) and if unexpected duplicates exist the most recently
    -- applied one wins deterministically
    select distinct on (invoice_id)
        invoice_id,
        percentage
    from {{ ref('invoice_discounts') }}
    order by invoice_id, applied_time desc, id
),

invoice_payments_agg as (
    -- BL-012: refunds are stored as positive amounts with
    -- original_payment_id set and negated so the sum gives the net patient
    -- payment total. The ipp.id filter keeps only patient payments, so a
    -- refund is netted only when it shares the patient-payment linkage of the
    -- payment it reverses. Insurer-payment refunds (no invoice_patient_payments
    -- row) are intentionally excluded, matching the patient-payment scope.
    select
        ipay.invoice_id,
        sum(
            case when ipay.original_payment_id is not null then -ipay.amount else ipay.amount end
        ) filter (where ipp.id is not null) as patient_payment
    from {{ ref('invoice_payments') }} ipay
    left join {{ ref('invoice_patient_payments') }} ipp
        on ipp.invoice_payment_id = ipay.id
    group by ipay.invoice_id
),

invoice_insurer_payments_agg as (
    -- BL-013: insurer payments actually received per invoice, mirroring the
    -- refund netting used for patient payments. A payment counts as an insurer
    -- payment when it carries an invoice_insurer_payments row.
    --
    -- No status filter: invoice_payments.amount is the amount actually paid, and
    -- invoice_insurer_payments.status is *derived from* it in the app
    -- (getInvoiceInsurerPaymentStatus: 0 -> rejected, full -> paid, part ->
    -- partial), so a rejected payment already contributes 0 and a partial one
    -- contributes its real received value. Tamanu's own insurer-received total
    -- (getSpecificInsurerPaymentRemainingBalance) sums amount across all insurer
    -- payments with no status filter -- this mirrors that exactly.
    select
        ipay.invoice_id,
        sum(
            case when ipay.original_payment_id is not null then -ipay.amount else ipay.amount end
        ) filter (where iip.id is not null) as insurer_payment
    from {{ ref('invoice_payments') }} ipay
    left join {{ ref('invoice_insurer_payments') }} iip
        on iip.invoice_payment_id = ipay.id
    group by ipay.invoice_id
)

-- One row per invoice. The status column lets consumers filter (e.g. exclude
-- cancelled) and aggregate; the snapshot-over-live coverage rule means a single
-- dataset serves both finalised and in-progress invoices.
select
    i.id as invoice_id,
    i.encounter_id,
    i.status,
    i.datetime as invoice_datetime,
    -- BL-015: finalisation timestamp, in deployment-local time (null until finalised)
    inf.finalised_at as invoice_finalised_datetime,
    -- BL-009: invoice total (sum of discounted item totals)
    iia.item_total as invoice_total,
    ica.insurance_coverage,
    -- BL-011: invoice-level discount amount, percentage applied to the patient
    -- subtotal (item total less insurance coverage), mirroring
    -- getInvoiceLevelDiscountAmount over patientSubtotal
    round(
        (coalesce(iia.item_total, 0) - coalesce(ica.insurance_coverage, 0))
        * coalesce(idsc.percentage, 0),
        2
    ) as invoice_discount,
    ipa.patient_payment,
    -- BL-013: net insurer payment actually received
    iipa.insurer_payment,
    iia.products_no_category
from {{ ref('invoices') }} i
left join invoice_finalised inf
    on inf.invoice_id = i.id
left join invoice_items_agg iia
    on iia.invoice_id = i.id
left join insurance_coverage_agg ica
    on ica.invoice_id = i.id
left join invoice_discount_pct idsc
    on idsc.invoice_id = i.id
left join invoice_payments_agg ipa
    on ipa.invoice_id = i.id
left join invoice_insurer_payments_agg iipa
    on iipa.invoice_id = i.id

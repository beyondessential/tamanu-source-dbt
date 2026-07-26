-- int__encounter_invoice_amounts -- shared per-invoice billing arithmetic.
-- One row per invoice: price-list resolution, item discounts, insurance coverage,
-- invoice-level discount, net patient payment, net insurer payment. Extracted from ds__encounter_invoices
-- so both ds__encounter_invoices (dataset) and clinical__cost (OMOP COST) consume a
-- single source of truth without a backwards clinical->ds dependency (D2).
-- See specs/dbt-model/clinical__cost.md. Ephemeral: inlined by consumers.

with invoice_finalised as (
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

invoice_context as materialized (
    -- Per-invoice context for price-list resolution, mirroring the inputs the
    -- app passes to getIdForPatientEncounter. Facility-agnostic: the consumer
    -- applies any facility or sensitivity scoping. Billing type falls back to
    -- the patient's additional data when the encounter has none.
    -- `materialized` is load-bearing: it is referenced once, so without the hint
    -- Postgres inlines it and drives the `cross join invoice_price_lists` from
    -- the encounters table (exploding to ~745k rows). Materialising bounds the
    -- cross join to the invoice count (3.6x faster on the all-time view).
    select
        i.id as invoice_id,
        f.id as facility_id,
        coalesce(e.patient_billing_type_id, pad.patient_billing_type_id) as patient_billing_type_id,
        -- BL-006: patient age in completed years at the invoice date, computed once
        date_part('year', age(i.datetime, p.date_of_birth)) as age_at_invoice
    from {{ ref('invoices') }} i
    join {{ ref('encounters') }} e
        on e.id = i.encounter_id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    join {{ ref('patients') }} p
        on p.id = e.patient_id
    left join {{ ref('patient_additional_data') }} pad
        on pad.patient_id = e.patient_id
),

claimed_facilities as (
    -- Facilities explicitly claimed by a current price list -- computed once
    -- so the facility-exclusion check below is a small anti-join rather than a
    -- correlated re-scan of invoice_price_lists per invoice.
    select distinct ipl.rules ->> 'facilityId' as facility_id
    from {{ ref('invoice_price_lists') }} ipl
    where ipl.visibility_status = 'current'
        and (ipl.rules ->> 'facilityId') is not null
),

invoice_price_list as (
    -- BL-006: resolve the single matching price list per invoice, mirroring
    -- getIdForPatientEncounter. Matches on facility (with exclusionary logic),
    -- patient billing type, and patient age in completed years at the invoice
    -- date (the app resolves at invoice time). When several match, the lowest
    -- evaluation_order wins, then earliest created_at, then code -- mirroring
    -- the application ordering (Postgres asc is nulls-last, so price lists with
    -- no evaluation_order fall back to created_at/code, as the app intends).
    select distinct on (ic.invoice_id)
        ic.invoice_id,
        ipl.id as invoice_price_list_id
    from invoice_context ic
    cross join {{ ref('invoice_price_lists') }} ipl
    where ipl.visibility_status = 'current'
        -- Facility: direct match, or no facility rule and this facility
        -- is not explicitly claimed by another price list
        and (
            (ipl.rules ->> 'facilityId') = ic.facility_id
            or (
                (ipl.rules ->> 'facilityId') is null
                and not exists (
                    select 1 from claimed_facilities cf
                    where cf.facility_id = ic.facility_id
                )
            )
        )
        -- Patient billing type
        and (
            (ipl.rules ->> 'patientType') is null
            or (ipl.rules ->> 'patientType') = ic.patient_billing_type_id
        )
        -- Patient age at the invoice date: exact numeric or min/max range
        and (
            (ipl.rules -> 'patientAge') is null
            or (
                jsonb_typeof(ipl.rules -> 'patientAge') = 'number'
                and ic.age_at_invoice
                = (ipl.rules ->> 'patientAge')::integer
            )
            or (
                jsonb_typeof(ipl.rules -> 'patientAge') = 'object'
                and (
                    (ipl.rules -> 'patientAge' ->> 'min') is null
                    or ic.age_at_invoice
                    >= (ipl.rules -> 'patientAge' ->> 'min')::integer
                )
                and (
                    (ipl.rules -> 'patientAge' ->> 'max') is null
                    or ic.age_at_invoice
                    <= (ipl.rules -> 'patientAge' ->> 'max')::integer
                )
            )
        )
    order by ic.invoice_id asc, ipl.evaluation_order asc, ipl.created_at asc, ipl.code asc
),

item_unit_price as (
    -- BL-007: mirrors getInvoiceItemPrice. Resolves the unit price once
    -- (price_final, else manual entry, else the resolved price-list price, else 0).
    select
        ii.id as invoice_item_id,
        ii.invoice_id,
        ii.product_id,
        ii.date,
        -- product_name_final is snapshotted at finalisation, so it is null for
        -- in-progress invoices -- fall back to the live product name
        coalesce(ii.product_name_final, ip.name) as product_name,
        ii.quantity,
        ip.category,
        ip.insurable,
        coalesce(
            ii.price_final,
            ii.manual_entry_price,
            ipli.price,
            0
        ) as price
    from {{ ref('invoice_items') }} ii
    left join {{ ref('invoice_products') }} ip
        on ip.id = ii.product_id
    left join invoice_price_list ipl_match
        on ipl_match.invoice_id = ii.invoice_id
    -- One price-list item per (price list and product) is guaranteed by a DB
    -- unique constraint on invoice_price_list_items, so this join cannot fan out.
    left join {{ ref('invoice_price_list_items') }} ipli
        on ipli.invoice_price_list_id = ipl_match.invoice_price_list_id
        and ipli.invoice_product_id = ii.product_id
        and ipli.is_hidden = false
),

item_resolved_price as (
    -- BL-008: mirrors getInvoiceItemTotalDiscountedPrice. Applies the item-level
    -- discount (percentage or flat amount) to unit price x quantity.
    select
        iup.invoice_item_id,
        iup.invoice_id,
        iup.product_id,
        iup.date,
        iup.product_name,
        iup.quantity,
        iup.category,
        iup.insurable,
        iup.price,
        case
            when iid.type = 'percentage'
                then iup.price * iup.quantity * (1 - coalesce(iid.amount, 0))
            when iid.type = 'amount'
                -- flat amount subtracted with no floor, so an over-large discount
                -- can take the line total negative (matching the application)
                then iup.price * iup.quantity - coalesce(iid.amount, 0)
            else iup.price * iup.quantity
        end as discounted_total
    from item_unit_price iup
    -- Tamanu enforces one discount per item (application logic, no DB
    -- unique constraint) and the id tie-break makes distinct on
    -- deterministic if unexpected duplicates exist
    left join (
        select distinct on (invoice_item_id)
            invoice_item_id,
            amount,
            type
        from {{ ref('invoice_item_discounts') }}
        order by invoice_item_id, id
    ) iid on iid.invoice_item_id = iup.invoice_item_id
),

item_coverage as (
    -- BL-010: mirrors getInvoiceItemCoveragePercentage applied per plan (as the
    -- app does over invoiceForResponse's insurancePlanItems). For each insurance
    -- plan currently linked to the invoice, coverage is the finalised snapshot
    -- for that (item, plan) when present, otherwise the live per-product
    -- coverage, falling back to the plan default, then 0. Summed across the
    -- item's plans. Driving from the linked plans (not the finalised rows) keeps
    -- finalised a per-plan override, so a mix of finalised and live plans, or a
    -- plan unlinked after finalisation, resolves exactly as the app does.
    select
        irp.invoice_item_id,
        sum(coalesce(
            -- Finalised: snapshotted per-plan coverage, immune to plan changes
            fin.coverage_value_final,
            -- Live: per-product coverage, then the plan default
            iipi.coverage_value,
            iip.default_coverage,
            0
        )) as total_pct
    from item_resolved_price irp
    join {{ ref('invoices_invoice_insurance_plans') }} iiip
        on iiip.invoice_id = irp.invoice_id
    join {{ ref('invoice_insurance_plans') }} iip
        on iip.id = iiip.invoice_insurance_plan_id
    left join {{ ref('invoice_insurance_plan_items') }} iipi
        on iipi.invoice_insurance_plan_id = iiip.invoice_insurance_plan_id
        and iipi.invoice_product_id = irp.product_id
    left join {{ ref('invoice_item_finalised_insurances') }} fin
        on fin.invoice_item_id = irp.invoice_item_id
        and fin.invoice_insurance_plan_id = iiip.invoice_insurance_plan_id
    where irp.insurable = true
    group by irp.invoice_item_id
),

insurance_coverage_agg as (
    -- BL-010: per-invoice insurance coverage, mirroring
    -- getInsuranceCoverageTotalAmount. Applies the combined coverage percentage
    -- to each insurable item's discounted price, capping per-item coverage at
    -- the discounted total (handles combined percentages over 100%). No filter
    -- on the sign of the discounted total -- the app includes negatively
    -- discounted items, where the cap pins coverage to the (negative) total.
    select
        irp.invoice_id,
        round(sum(least(
            irp.discounted_total * ic.total_pct / 100,
            irp.discounted_total
        )), 2) as insurance_coverage
    from item_resolved_price irp
    join item_coverage ic
        on ic.invoice_item_id = irp.invoice_item_id
    group by irp.invoice_id
),

invoice_items_agg as (
    -- BL-009: invoice item total and BL-016: the products with no category
    select
        irp.invoice_id,
        string_agg(
            irp.product_name, ', '
            order by irp.date
        ) filter (where irp.category is null) as products_no_category,
        sum(irp.discounted_total) as item_total
    from item_resolved_price irp
    group by irp.invoice_id
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

{#
    invoice_item_amounts -- shared per-invoice-item billing arithmetic.

    Emits a full `with ... select` producing one row per invoice item: price-list
    resolution, resolved unit price, item discount/adjustment, and per-item insurance
    coverage. Kept as a macro (not a ref'd model) so both consumers embed the *bases*
    directly:
      - int__encounter_invoice_item_amounts  = {{ invoice_item_amounts() }}   (item grain)
      - int__encounter_invoice_amounts        wraps it as `with items as (...)` and
                                               aggregates to invoice grain

    Embedding via a macro (rather than one int ref'ing the other) keeps invoice_items /
    price lists / discounts / insurance plans as direct refs of int__encounter_invoice_amounts,
    so its unit tests mock those bases exactly as before. One definition, no drift.
    See specs/dbt-model/ds__encounter_invoice_items.md.
#}
{% macro invoice_item_amounts() %}
with invoice_context as materialized (
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
        -- BL-002: patient age in completed years at the invoice date, computed once
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
    -- BL-002: resolve the single matching price list per invoice, mirroring
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
    -- BL-002: mirrors getInvoiceItemPrice. Resolves the unit price once
    -- (price_final, else manual entry, else the resolved price-list price, else 0).
    select
        ii.id as invoice_item_id,
        ii.invoice_id,
        ii.product_id,
        ii.date,
        -- product_name_final is snapshotted at finalisation, so it is null for
        -- in-progress invoices -- fall back to the live product name (BL-005)
        coalesce(ii.product_name_final, ip.name) as product_name,
        ii.quantity,
        ip.category,
        ip.insurable,
        -- polymorphic link to the originating clinical record, carried through (BL-006)
        ii.source_record_type,
        ii.source_record_id,
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
    -- BL-003: mirrors getInvoiceItemTotalDiscountedPrice. Applies the item-level
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
        iup.source_record_type,
        iup.source_record_id,
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
    -- BL-004: mirrors getInvoiceItemCoveragePercentage applied per plan (as the
    -- app does over invoiceForResponse's insurancePlanItems). For each insurance
    -- plan currently linked to the invoice, coverage is the finalised snapshot
    -- for that (item, plan) when present, otherwise the live per-product
    -- coverage, falling back to the plan default, then 0. Summed across the
    -- item's plans. Driving from the linked plans (not the finalised rows) keeps
    -- finalised a per-plan override, so a mix of finalised and live plans, or a
    -- plan unlinked after finalisation, resolves exactly as the app does. Only
    -- insurable items on plan-linked invoices get a row (inner joins).
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
)

-- One row per invoice item. `insurance_coverage` is left UNROUNDED and null when the
-- item has no coverage (non-insurable or no plan linked) so the invoice-level model can
-- reproduce its exact `round(sum(...), 2)` and null-when-no-coverage semantics.
select
    irp.invoice_item_id,
    irp.invoice_id,
    irp.product_id,
    irp.date,
    irp.product_name,
    irp.category,
    irp.quantity,
    irp.price as unit_price,
    irp.discounted_total,
    -- BL-003: signed item adjustment (discounted minus undiscounted) -- negative for a
    -- discount, positive for a markup -- mirroring getItemAdjustmentAmount
    irp.discounted_total - irp.price * irp.quantity as item_adjustment,
    -- BL-004: per-item insurance coverage, capped at the discounted total; null when the
    -- item has no coverage row so the invoice-level sum stays null for no-insurance invoices
    case
        when ic.invoice_item_id is not null
            then least(irp.discounted_total * ic.total_pct / 100, irp.discounted_total)
    end as insurance_coverage,
    -- BL-006: polymorphic link to the originating clinical record (Prescription / LabTest
    -- / Procedure / ImagingRequestArea; null for manually-added products)
    irp.source_record_type,
    irp.source_record_id
from item_resolved_price irp
left join item_coverage ic
    on ic.invoice_item_id = irp.invoice_item_id
{% endmacro %}

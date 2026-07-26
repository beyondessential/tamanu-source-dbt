-- clinical__cost -- OMOP-lite COST domain. One row per invoice (BL-001), anchored to
-- the encounter's visit_occurrence via cost_event_id. Charges, coverage and net
-- patient payment come from the shared int__encounter_invoice_amounts arithmetic;
-- insurer payments actually received are aggregated here from bases/ (D10). Native
-- UUID keys (D1). See specs/dbt-model/clinical__cost.md for BL-001..BL-010.
--
-- Note: the payment-method split (Cash/Mobile Money/Card/...) is intentionally NOT
-- modelled here -- OMOP COST has no payment-instrument dimension (spec OQ-001).

with invoice_amounts as (
    select * from {{ ref('int__encounter_invoice_amounts') }}
),

invoices as (
    select * from {{ ref('invoices') }}
),

insurer_payments_agg as (
    -- BL-006: insurer payments actually received per invoice. A payment counts as
    -- an insurer payment when it carries an invoice_insurer_payments row. Refunds
    -- (original_payment_id set) are negated so the sum is the net insurer receipt,
    -- mirroring the patient-payment netting in int__encounter_invoice_amounts.
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

select
    -- identity (BL-001)
    a.invoice_id as cost_id,

    -- event anchor: the billed encounter, FK to clinical__visit_occurrence (BL-002)
    a.encounter_id as cost_event_id,
    'Visit' as cost_domain_id,

    -- provenance: constant, concept TBD (spec OQ-005). 0 = no matching concept
    0 as cost_type_concept_id,

    -- deployment currency: universal model leaves it unset; deployments override
    -- via map__omop_currency or a var (BL-009, spec OQ-002)
    cast(null as integer) as currency_concept_id,

    -- charged, paid and expected-coverage amounts. Default to 0 so downstream sums
    -- never need coalesce (BL-010)
    coalesce(a.invoice_total, 0)                                as total_charge,      -- BL-003
    coalesce(a.patient_payment, 0) + coalesce(ipa.insurer_payment, 0) as total_paid,  -- BL-007
    coalesce(a.patient_payment, 0)                             as paid_by_patient,   -- BL-005
    coalesce(ipa.insurer_payment, 0)                          as paid_by_payer,     -- BL-006
    coalesce(a.insurance_coverage, 0)                         as amount_allowed,    -- BL-004
    coalesce(a.invoice_discount, 0)                          as discount_amount,   -- BL-008 [ext]

    -- payer plan period: future clinical__payer_plan_period (spec OQ-006)
    cast(null as varchar) as payer_plan_period_id,

    -- human-facing invoice number, retained for traceability [ext]
    i.display_id as cost_source_value

from invoice_amounts a
left join insurer_payments_agg ipa
    on ipa.invoice_id = a.invoice_id
left join invoices i
    on i.id = a.invoice_id

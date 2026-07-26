-- clinical__cost -- OMOP-lite COST domain. One row per invoice (BL-001), anchored to
-- the encounter's visit_occurrence via cost_event_id. Charges, coverage, net patient
-- payment and net insurer payment all come from the shared
-- int__encounter_invoice_amounts arithmetic (single source of truth); this
-- model only reshapes them into OMOP COST columns. Native UUID keys (D1).
-- See specs/dbt-model/clinical__cost.md for BL-001..BL-010.
--
-- Note: the payment-method split (Cash/Mobile Money/Card/...) is intentionally NOT
-- modelled here -- OMOP COST has no payment-instrument dimension (see the
-- "Decisions taken" note in specs/dbt-model/clinical__cost.md).

with invoice_amounts as (
    select * from {{ ref('int__encounter_invoice_amounts') }}
)

select
    -- identity (BL-001). Cast to varchar (native Tamanu string id, D1) for a
    -- type-safe key consistent with the other clinical__ models
    a.invoice_id::varchar as cost_id,

    -- event anchor: the billed encounter, FK to clinical__visit_occurrence (BL-002)
    a.encounter_id::varchar as cost_event_id,
    'Visit' as cost_domain_id,

    -- invoice lifecycle status, carried so consumers can exclude cancelled
    -- invoices (which still carry a charge). OMOP COST has no status field, so
    -- this is a Tamanu extension column (BL-001) [ext]
    a.status as invoice_status,

    -- provenance: 32821 = "EHR billing record" (OMOP Type Concept) -- the cost is
    -- derived from the Tamanu billing subsystem
    32821 as cost_type_concept_id,

    -- deployment currency: universal model leaves it unset; deployments override
    -- per deployment via map__omop_currency or a var (BL-009)
    null::integer as currency_concept_id,

    -- charged, paid and expected-coverage amounts. Default to 0 so downstream sums
    -- never need coalesce (BL-010)
    coalesce(a.invoice_total, 0) as total_charge,      -- BL-003
    coalesce(a.patient_payment, 0) + coalesce(a.insurer_payment, 0) as total_paid,  -- BL-007
    coalesce(a.patient_payment, 0) as paid_by_patient,   -- BL-005
    coalesce(a.insurer_payment, 0) as paid_by_payer,     -- BL-006
    coalesce(a.insurance_coverage, 0) as amount_allowed,    -- BL-004
    coalesce(a.invoice_discount, 0) as discount_amount,   -- BL-008 [ext]

    -- payer plan period: future clinical__payer_plan_period (spec OQ-002)
    null::varchar as payer_plan_period_id,

    -- human-facing invoice number, retained for traceability [ext]
    a.display_id as cost_source_value

from invoice_amounts a

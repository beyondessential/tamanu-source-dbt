-- metric__billing -- D5 metric view for the patient billing indicators registered in
-- documentations/metrics/billing.yml: invoice, invoice_total, invoice_insurance_coverage,
-- invoice_discount, invoice_patient_total, invoice_patient_paid, invoice_patient_balance and
-- invoice_patient_payment.
-- See specs/dbt-model/metric__billing.md for the BL clauses this model implements
-- (BL-001..BL-018).
--
-- Per-subject grain. The seven invoice metrics have one row per non-cancelled invoice, dated
-- to the invoice. invoice_patient_payment has one row per patient payment or refund, dated to
-- the payment. Every row of an invoice carries the same disaggregations, so a consumer can
-- group invoice and payment rows together.
--
-- BL-001: the registry carries the definitions, and this model is their implementation.

with invoices as (
    select * from {{ ref('ds__encounter_invoices') }}
    -- BL-002: in-progress and finalised invoices only
    where status in ('in_progress', 'finalised')
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

locations as (
    select * from {{ ref('locations') }}
),

invoice_payments as (
    select * from {{ ref('invoice_payments') }}
),

invoice_patient_payments as (
    select * from {{ ref('invoice_patient_payments') }}
),

invoice_context as (
    select
        i.invoice_id::varchar as invoice_id,
        i.status as invoice_status,
        -- BL-003: invoice date and time, already deployment-local
        i.invoice_datetime,
        -- BL-004: the dataset's resolved figures, unchanged, with NULL emitted as 0
        -- BL-017: the invoice's current figures, so a later change restates its month
        coalesce(i.invoice_total, 0) as invoice_total,
        coalesce(i.insurance_coverage, 0) as insurance_coverage,
        coalesce(i.invoice_discount, 0) as invoice_discount,
        coalesce(i.patient_subtotal, 0) as patient_total,
        coalesce(i.patient_payment, 0) as patient_paid,
        -- BL-012: the facility of the encounter's location
        l.facility_id,
        -- BL-009: no else branch, so a visit concept outside the map surfaces as NULL and
        -- fails the not_null test rather than landing in a bucket
        case vo.visit_concept_id
            when 9201 then 'inpatient'
            when 262 then 'inpatient'
            when 9203 then 'emergency'
            when 9202 then 'outpatient'
            when 0 then 'none'
        end as care_setting,
        -- BL-010: concept 262 is an admission with an earlier emergency phase
        coalesce(vo.visit_concept_id = 262, false) as is_admitted_via_emergency,
        -- BL-011: current values, unresolved and ungrouped
        vo.department_id,
        vo.visit_source_value as encounter_type
    from invoices i
    join visit_occurrence vo
        on vo.visit_occurrence_id = i.encounter_id
    join locations l
        on l.id = vo.care_site_id
),

invoice_rows as (
    select
        m.metric_id,
        ic.invoice_id as subject_id,
        ic.invoice_datetime as period_start,
        -- BL-003: invoice rows at minute granularity
        'minute'::text as period_granularity,
        m.value_numeric,
        ic.invoice_id,
        ic.invoice_status,
        ic.facility_id,
        ic.care_setting,
        ic.is_admitted_via_emergency,
        ic.department_id,
        ic.encounter_type
    from invoice_context ic
    cross join lateral (
        values
        -- BL-006: the invoice count, 1 per invoice
        ('invoice', 1::numeric),
        -- BL-004: the invoice amounts
        ('invoice_total', ic.invoice_total),
        ('invoice_insurance_coverage', ic.insurance_coverage),
        ('invoice_discount', ic.invoice_discount),
        ('invoice_patient_total', ic.patient_total),
        ('invoice_patient_paid', ic.patient_paid),
        -- BL-005: negative when the invoice is overpaid
        ('invoice_patient_balance', ic.patient_total - ic.patient_paid)
    ) m (metric_id, value_numeric)
),

payment_rows as (
    select
        'invoice_patient_payment'::text as metric_id,
        ipay.id::varchar as subject_id,
        -- BL-007: dated to the payment
        ipay.date::timestamp as period_start,
        'day'::text as period_granularity,
        -- BL-007: a refund carries original_payment_id and a positive amount, so negate it
        -- to net it against the payment it reverses
        -- BL-008: so an invoice's payment rows sum to its invoice_patient_paid
        case
            when ipay.original_payment_id is not null then -ipay.amount
            else ipay.amount
        end::numeric as value_numeric,
        -- BL-013: the invoice's disaggregations, and the inner join drops payments on
        -- cancelled invoices (BL-002)
        ic.invoice_id,
        ic.invoice_status,
        ic.facility_id,
        ic.care_setting,
        ic.is_admitted_via_emergency,
        ic.department_id,
        ic.encounter_type
    from invoice_payments ipay
    join invoice_context ic
        on ic.invoice_id = ipay.invoice_id::varchar
    -- BL-007: patient payments only
    where exists (
            select 1 from invoice_patient_payments ipp
            where ipp.invoice_payment_id = ipay.id
        )
),

billing_rows as (
    select * from invoice_rows
    union all
    select * from payment_rows
)

-- BL-014: counts and amounts only, and the consumer forms rates and running totals
-- BL-016: no patient identifier or patient attribute is selected
select
    metric_id::text as metric_id,
    null::text as variant_id,
    subject_id,
    period_start,
    null::timestamp as period_end,
    period_granularity,
    value_numeric,
    null::boolean as value_boolean,
    invoice_id,
    invoice_status::text as invoice_status,
    facility_id,
    care_setting,
    is_admitted_via_emergency,
    department_id,
    encounter_type::text as encounter_type
from billing_rows

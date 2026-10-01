-- Singular tests for metric__billing. One row per violation, tagged with the acceptance
-- criterion it breaks. See specs/dbt-model/metric__billing.md.

with billing as (
    select * from {{ ref('metric__billing') }}
),

-- One row per invoice, with each invoice metric as a column.
per_invoice as (
    select
        invoice_id,
        sum(value_numeric) filter (where metric_id = 'invoice_total') as invoice_total,
        sum(value_numeric) filter (where metric_id = 'invoice_insurance_coverage') as insurance_coverage,
        sum(value_numeric) filter (where metric_id = 'invoice_discount') as invoice_discount,
        sum(value_numeric) filter (where metric_id = 'invoice_patient_total') as patient_total,
        sum(value_numeric) filter (where metric_id = 'invoice_patient_paid') as patient_paid,
        sum(value_numeric) filter (where metric_id = 'invoice_patient_balance') as patient_balance,
        coalesce(sum(value_numeric) filter (where metric_id = 'invoice_patient_payment'), 0) as payments
    from billing
    group by invoice_id
),

-- AC-005: minute for invoice metrics, day for payments (BL-003, BL-007).
ac_005 as (
    select
        subject_id,
        'AC-005' as failed_ac
    from billing
    where period_granularity
        != case when metric_id = 'invoice_patient_payment' then 'day' else 'minute' end
),

-- AC-006: the invoice count is 1 on every row (BL-006).
ac_006 as (
    select
        subject_id,
        'AC-006' as failed_ac
    from billing
    where metric_id = 'invoice' and value_numeric != 1
),

-- AC-008: invoice total = coverage + discount + patient total (BL-004).
ac_008 as (
    select
        invoice_id as subject_id,
        'AC-008' as failed_ac
    from per_invoice
    where abs(invoice_total - (insurance_coverage + invoice_discount + patient_total)) > 0.01
),

-- AC-009: patient balance = patient total - patient paid (BL-005).
ac_009 as (
    select
        invoice_id as subject_id,
        'AC-009' as failed_ac
    from per_invoice
    where abs(patient_balance - (patient_total - patient_paid)) > 0.01
),

-- AC-010: an invoice's payment rows sum to its patient paid (BL-007, BL-008).
ac_010 as (
    select
        invoice_id as subject_id,
        'AC-010' as failed_ac
    from per_invoice
    where abs(payments - patient_paid) > 0.01
),

-- AC-012: only an inpatient invoice can be flagged as admitted via emergency (BL-010).
ac_012 as (
    select
        subject_id,
        'AC-012' as failed_ac
    from billing
    where is_admitted_via_emergency and care_setting != 'inpatient'
),

-- AC-015: no encounter has more than one non-cancelled invoice (BL-013).
ac_015 as (
    select
        encounter_id::varchar as subject_id,
        'AC-015' as failed_ac
    from {{ ref('ds__encounter_invoices') }}
    where status != 'cancelled'
    group by encounter_id
    having count(*) > 1
)

select
    subject_id,
    failed_ac
from ac_005
union all
select
    subject_id,
    failed_ac
from ac_006
union all
select
    subject_id,
    failed_ac
from ac_008
union all
select
    subject_id,
    failed_ac
from ac_009
union all
select
    subject_id,
    failed_ac
from ac_010
union all
select
    subject_id,
    failed_ac
from ac_012
union all
select
    subject_id,
    failed_ac
from ac_015

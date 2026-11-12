{{ incremental_from_table(
    key='id',
    table='invoice_insurer_payments'
) }}
select
    iip.id,
    iip.invoice_payment_id,
    iip.insurer_id,
    iip.status,
    iip.reason,
    iip.updated_at_sync_tick
from {{ source('tamanu', 'invoice_insurer_payments') }} iip
join {{ source('tamanu', 'invoice_payments') }} ipay on ipay.id = iip.invoice_payment_id
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iip.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and iip.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

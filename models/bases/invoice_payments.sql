{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='invoice_payments',
    source_type='table'
) }}
select
    ipay.id,
    ipay.invoice_id,
    ipay.date::date,
    ipay.receipt_number,
    ipay.amount,
    ipay.original_payment_id,
    ipay.updated_at_sync_tick
from {{ source('tamanu', 'invoice_payments') }} ipay
join {{ source('tamanu', 'invoices') }} i on i.id = ipay.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and ipay.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

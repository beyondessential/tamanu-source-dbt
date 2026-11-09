{{ incremental_config(
    key='id',
    source='invoice_item_discounts',
    source_type='table'
) }}
select
    iid.id,
    iid.invoice_item_id,
    iid.amount,
    iid.type,
    iid.reason,
    iid.updated_at_sync_tick
from {{ source('tamanu', 'invoice_item_discounts') }} iid
join {{ source('tamanu', 'invoice_items') }} ii on ii.id = iid.invoice_item_id
join {{ source('tamanu', 'invoices') }} i on i.id = ii.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iid.deleted_at is null
    and ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and iid.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

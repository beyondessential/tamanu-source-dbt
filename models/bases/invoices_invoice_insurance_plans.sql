{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='invoices_invoice_insurance_plans',
    source_type='table'
) }}
select
    iiip.id,
    iiip.invoice_id,
    iiip.invoice_insurance_plan_id,
    iiip.updated_at_sync_tick
from {{ source('tamanu', 'invoices_invoice_insurance_plans') }} iiip
join {{ source('tamanu', 'invoices') }} i on i.id = iiip.invoice_id
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
where
    iiip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and iiip.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

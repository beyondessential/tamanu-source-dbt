{{ incremental_config(
    key='id',
    source='imaging_request_areas',
    source_type='table'
) }}
select
    ira.id,
    ira.imaging_request_id,
    ira.area_id,
    ira.updated_at_sync_tick
from {{ source('tamanu', 'imaging_request_areas') }} ira
join {{ source('tamanu', 'imaging_requests') }} ir on ir.id = ira.imaging_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = ir.encounter_id
where ira.deleted_at is null
    and ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and ira.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

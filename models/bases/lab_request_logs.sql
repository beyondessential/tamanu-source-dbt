{{ incremental_config(
    key='id',
    source='lab_request_logs',
    source_type='table'
) }}
select
    lrl.id,
    lrl.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    lrl.updated_at at time zone '{{ var("timezone") }}' as updated_datetime,
    lrl.lab_request_id,
    lrl.status,
    lrl.updated_by_id,
    lrl.updated_at_sync_tick
from {{ source('tamanu', 'lab_request_logs') }} lrl
join {{ source('tamanu', 'lab_requests') }} lr on lr.id = lrl.lab_request_id
join {{ source('tamanu', 'encounters') }} e on e.id = lr.encounter_id
where lrl.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and lrl.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

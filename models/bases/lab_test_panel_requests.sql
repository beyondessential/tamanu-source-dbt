{{ incremental_config(
    key='id',
    source='lab_test_panel_requests',
    source_type='table'
) }}
select
    ltpr.id,
    ltpr.lab_test_panel_id,
    ltpr.encounter_id,
    ltpr.lab_request_id,
    ltpr.updated_at_sync_tick
from {{ source('tamanu', 'lab_test_panel_requests') }} ltpr
join {{ source('tamanu', 'encounters') }} e on e.id = ltpr.encounter_id
where ltpr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and ltpr.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

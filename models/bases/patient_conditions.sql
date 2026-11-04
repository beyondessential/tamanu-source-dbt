{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='patient_conditions',
    source_type='table'
) }}
select
    id,
    recorded_date::timestamp as recorded_datetime,
    note,
    condition_id,
    patient_id,
    examiner_id as recorded_by_id,
    resolved as is_resolved,
    resolution_date::timestamp as resolved_datetime,
    resolution_practitioner_id as resolved_by_id,
    resolution_note,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_conditions') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

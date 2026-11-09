{{ incremental_config(
    key='id',
    source='patient_facilities',
    source_type='table'
) }}
select
    id,
    created_at at time zone '{{ var("timezone") }}' as created_at,
    patient_id,
    facility_id,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_facilities') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

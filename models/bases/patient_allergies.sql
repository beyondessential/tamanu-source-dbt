{{ incremental_config(
    key='id',
    source='patient_allergies',
    source_type='table'
) }}
select
    id,
    patient_id,
    allergy_id,
    recorded_date::date as recorded_date,
    practitioner_id as recorded_by,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_allergies') }}
where deleted_at is null
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

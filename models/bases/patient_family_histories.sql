{{ incremental_from_table(
    key='id',
    table='patient_family_histories'
) }}
select
    id,
    recorded_date::timestamp as recorded_datetime,
    patient_id,
    practitioner_id as clinician_id,
    diagnosis_id,
    relationship,
    note,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_family_histories') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

{{ incremental_config_for_analytics(
    unique_key='id',
    source_table='patient_program_registrations',
    source_type='table'
) }}
select
    id,
    date::timestamp as datetime,
    registration_status,
    patient_id,
    program_registry_id,
    clinical_status_id,
    clinician_id as registered_by_id,
    registering_facility_id,
    facility_id,
    village_id,
    deactivated_clinician_id as deactivated_by_id,
    deactivated_date::timestamp as deactivated_datetime,
    updated_at_sync_tick
from {{ source('tamanu', 'patient_program_registrations') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

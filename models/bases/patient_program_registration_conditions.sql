{{ incremental_config(
    key='id',
    source='patient_program_registration_conditions',
    source_type='table'
) }}
select
    pprc.id,
    pprc.date::timestamp as datetime,
    pprc.program_registry_condition_id,
    pprc.patient_program_registration_id,
    pprc.program_registry_condition_category_id,
    pprc.reason_for_change,
    pprc.clinician_id as recorded_by_id,
    pprc.deletion_date::timestamp as deleted_datetime,
    pprc.deletion_clinician_id as deleted_by_id,
    pprc.updated_at_sync_tick
from {{ source('tamanu', 'patient_program_registration_conditions') }} pprc
join {{ source('tamanu', 'patient_program_registrations') }} ppr
    on ppr.id = pprc.patient_program_registration_id
where pprc.deleted_at is null
    and ppr.patient_id != '{{ var("test_patient") }}'
    {%- if is_incremental() %}
    and pprc.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}

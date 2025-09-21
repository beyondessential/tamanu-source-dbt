select
    pprc.id,
    pprc.date::timestamp as datetime,
    pprc.program_registry_condition_id,
    pprc.patient_program_registration_id,
    pprc.program_registry_condition_category_id,
    pprc.reason_for_change,
    pprc.clinician_id as recorded_by_id,
    pprc.deletion_date::timestamp as deleted_datetime,
    pprc.deletion_clinician_id as deleted_by_id
from {{ resolve_input_model('patient_program_registration_conditions', source_type=var('base_model_source_type', 'source')) }} pprc
join {{ resolve_input_model('patient_program_registrations', source_type=var('base_model_source_type', 'source')) }} ppr
    on ppr.id = pprc.patient_program_registration_id
where pprc.deleted_at is null
    and ppr.patient_id != '{{ var("test_patient") }}'

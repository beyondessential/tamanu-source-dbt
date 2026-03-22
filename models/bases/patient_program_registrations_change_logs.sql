with filtered_changes as (
    {{ base_history_from_log('patient_program_registrations') }}
        and (
            version = 'unknown'
            or string_to_array(version, '.')::int [] >= string_to_array('2.33.0', '.')::int []
        )
        and record_data ->> 'patient_id' != '{{ var("test_patient") }}'
)

select
    fc.changelog_id,
    fc.logged_at,
    fc.updated_by_user_id,
    fc.record_id as id,
    (fc.record_data ->> 'date')::timestamp as datetime,
    fc.record_data ->> 'registration_status' as registration_status,
    fc.record_data ->> 'patient_id' as patient_id,
    fc.record_data ->> 'program_registry_id' as program_registry_id,
    fc.record_data ->> 'clinical_status_id' as clinical_status_id,
    fc.record_data ->> 'clinician_id' as registered_by_id,
    fc.record_data ->> 'registering_facility_id' as registering_facility_id,
    fc.record_data ->> 'facility_id' as facility_id,
    fc.record_data ->> 'village_id' as village_id,
    fc.record_data ->> 'deactivated_clinician_id' as deactivated_by_id,
    (fc.record_data ->> 'deactivated_date')::timestamp as deactivated_datetime
from filtered_changes fc

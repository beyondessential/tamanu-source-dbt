-- Version >= 2.33
select
    c.id,
    c.record_updated_at::timestamp,
    -- Extract fields from record_data JSON when version >= 2.33
    (c.record_data->>'date')::timestamp as datetime,
    c.record_data->>'registration_status' as registration_status,
    c.record_data->>'patient_id' as patient_id,
    c.record_data->>'program_registry_id' as program_registry_id,
    c.record_data->>'clinical_status_id' as clinical_status_id,
    c.record_data->>'clinician_id' as registered_by_id,
    c.record_data->>'registering_facility_id' as registering_facility_id,
    c.record_data->>'facility_id' as facility_id,
    c.record_data->>'village_id' as village_id,
    c.record_data->>'deactivated_clinician_id' as deactivated_by_id,
    (c.record_data->>'deactivated_date')::timestamp as deactivated_datetime
from {{ source("logs__tamanu", "changes") }} c
where c.table_name = 'patient_program_registrations'
    and c.version >= '2.33'
    and c.record_data->>'patient_id' != '{{ var("test_patient") }}'

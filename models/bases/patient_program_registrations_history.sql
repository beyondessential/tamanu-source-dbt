with filtered_changes as (
    select 
        id,
        logged_at,
        record_data
    from {{ source("logs__tamanu", "changes") }}
    where table_name = 'patient_program_registrations'
        and string_to_array(version, '.')::int[] >= string_to_array('2.33.0', '.')::int[]
        and record_deleted_at is null
        and record_data->>'patient_id' != '{{ var("test_patient") }}'
)

select
    fc.id,
    fc.logged_at::timestamp,
    r.date::timestamp as datetime,
    r.registration_status,
    r.patient_id,
    r.program_registry_id,
    r.clinical_status_id,
    r.clinician_id as registered_by_id,
    r.registering_facility_id,
    r.facility_id,
    r.village_id,
    r.deactivated_clinician_id as deactivated_by_id,
    r.deactivated_date::timestamp as deactivated_datetime
from filtered_changes fc
cross join jsonb_to_recordset(fc.record_data) as r(
    date text,
    registration_status text,
    patient_id text,
    program_registry_id text,
    clinical_status_id text,
    clinician_id text,
    registering_facility_id text,
    facility_id text,
    village_id text,
    deactivated_clinician_id text,
    deactivated_date text
)

with filtered_changes as (
    select 
        id,
        logged_at,
        record_data
    from {{ source("logs__tamanu", "changes") }}
    where table_name = 'patient_program_registration_conditions'
        and string_to_array(version, '.')::int[] >= string_to_array('2.33.0', '.')::int[]
        and record_deleted_at is null
)

select
    fc.id,
    fc.logged_at::timestamp,
    r.date::timestamp as datetime,
    r.program_registry_condition_id,
    r.patient_program_registration_id,
    r.condition_category,
    r.reason_for_change,
    r.clinician_id as recorded_by_id,
    r.deletion_date::timestamp as deleted_datetime,
    r.deletion_clinician_id as deleted_by_id
from filtered_changes fc
cross join jsonb_to_recordset(fc.record_data) as r(
    date text,
    program_registry_condition_id text,
    patient_program_registration_id text,
    condition_category text,
    reason_for_change text,
    clinician_id text,
    deletion_date text,
    deletion_clinician_id text
)

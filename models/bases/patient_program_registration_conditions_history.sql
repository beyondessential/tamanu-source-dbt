with filtered_changes as (
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_data
    from {{ source("logs__tamanu", "changes") }}
    where table_name = 'patient_program_registration_conditions'
        and (version = 'unknown'
            or string_to_array(version, '.')::int[] >= string_to_array('2.33.0', '.')::int[]
        )
        and record_deleted_at is null
)

select
    fc.changelog_id,
    fc.logged_at::timestamp,
    fc.updated_by_user_id,
    fc.record_data->>'id' as id,
    (fc.record_data->>'date')::timestamp as datetime,
    fc.record_data->>'program_registry_condition_id' as program_registry_condition_id,
    fc.record_data->>'patient_program_registration_id' as patient_program_registration_id,
    fc.record_data->>'condition_category' as condition_category,
    fc.record_data->>'reason_for_change' as reason_for_change,
    fc.record_data->>'clinician_id' as recorded_by_id,
    (fc.record_data->>'deletion_date')::timestamp as deleted_datetime,
    fc.record_data->>'deletion_clinician_id' as deleted_by_id
from filtered_changes fc

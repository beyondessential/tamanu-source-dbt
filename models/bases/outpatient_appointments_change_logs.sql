-- Base model for outpatient appointment change logs
-- Extracts appointment modifications from logs.changes table
-- Each row represents a change event to an appointment

with appointment_changes as (
    select
        c.id as change_id,
        c.record_id as appointment_id,
        c.logged_at as modified_datetime,
        c.updated_by_user_id as modified_by_user_id,
        c.record_data,
        c.record_created_at,
        -- Extract current values from the change log record_data
        (c.record_data->>'start_time')::timestamp as start_datetime,
        (c.record_data->>'end_time')::timestamp as end_datetime,
        c.record_data->>'patient_id' as patient_id,
        c.record_data->>'clinician_id' as clinician_id,
        c.record_data->>'location_group_id' as location_group_id,
        c.record_data->>'appointment_type_id' as appointment_type_id,
        (c.record_data->>'is_high_priority')::boolean as is_high_priority,
        c.record_data->>'status' as status,
        (c.record_data->>'schedule_id')::uuid as schedule_id,
        -- Get creator from the first change_sequence (initial creation)
        first_value(c.updated_by_user_id) over (
            partition by c.record_id
            order by c.logged_at
        ) as created_by_user_id,
        -- Use LAG to get the previous record state
        lag(c.record_data) over (
            partition by c.record_id
            order by c.logged_at
        ) as previous_record_data,
        -- Track change sequence
        row_number() over (
            partition by c.record_id
            order by c.logged_at
        ) as change_sequence
    from {{ source('logs__tamanu', 'changes') }} c
    where c.table_name = 'appointments'
        and c.record_deleted_at is null
)

select
    change_id,
    appointment_id,
    modified_datetime,
    modified_by_user_id,
    created_by_user_id,
    patient_id,
    -- Current appointment details
    start_datetime,
    end_datetime,
    clinician_id,
    location_group_id,
    appointment_type_id,
    is_high_priority,
    status,
    schedule_id,
    -- Previous appointment details
    (previous_record_data->>'start_time')::timestamp as prev_start_datetime,
    (previous_record_data->>'end_time')::timestamp as prev_end_datetime,
    (previous_record_data->>'clinician_id') as prev_clinician_id,
    (previous_record_data->>'location_group_id') as prev_location_group_id,
    (previous_record_data->>'appointment_type_id') as prev_appointment_type_id,
    (previous_record_data->>'is_high_priority')::boolean as prev_is_high_priority,
    (previous_record_data->>'status') as prev_status,
    change_sequence
from appointment_changes

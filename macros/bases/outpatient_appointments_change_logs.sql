{% macro outpatient_appointments_change_log_events(record_id_filter=none) %}
-- Shared change-log extraction for outpatient appointments. Three callers: the base model
-- (unfiltered), the audit report, and the audit dataset's incremental build. BL-031.
--
-- record_id_filter narrows WHICH appointments are included, never how much of an included
-- appointment's history is seen -- the window functions below need the full history per
-- appointment to stay correct.
with appointment_changes as (
    select
        c.id as change_id,
        c.record_id as appointment_id,
        c.logged_at at time zone '{{ var("timezone") }}' as modified_datetime,
        -- Incremental cursor: monotonic and btree-indexed, unlike logged_at. BL-032.
        c.updated_at_sync_tick,
        c.updated_by_user_id as modified_by_user_id,
        -- Extract current values from the change log record_data
        (c.record_data ->> 'start_time')::timestamp as start_datetime,
        (c.record_data ->> 'end_time')::timestamp as end_datetime,
        c.record_data ->> 'patient_id' as patient_id,
        c.record_data ->> 'clinician_id' as clinician_id,
        c.record_data ->> 'location_group_id' as location_group_id,
        c.record_data ->> 'appointment_type_id' as appointment_type_id,
        (c.record_data ->> 'is_high_priority')::boolean as is_high_priority,
        c.record_data ->> 'status' as status,
        (c.record_data ->> 'schedule_id')::uuid as schedule_id,
        -- Get creator from the first change_sequence (initial creation)
        first_value(c.updated_by_user_id) over (
            partition by c.record_id
            order by c.logged_at, c.record_updated_at, c.id
        ) as created_by_user_id,
        -- Use LAG to get the previous record state
        lag(c.record_data) over (
            partition by c.record_id
            order by c.logged_at, c.record_updated_at, c.id
        ) as previous_record_data,
        -- Track change sequence
        row_number() over (
            partition by c.record_id
            order by c.logged_at, c.record_updated_at, c.id
        ) as change_sequence
    from {{ ref('outpatient_appointments_change_events') }} c
    {%- if record_id_filter %}
    where {{ record_id_filter }}
    {%- endif %}
)

select
    change_id,
    appointment_id,
    modified_datetime,
    updated_at_sync_tick,
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
    (previous_record_data ->> 'start_time')::timestamp as prev_start_datetime,
    (previous_record_data ->> 'end_time')::timestamp as prev_end_datetime,
    (previous_record_data ->> 'clinician_id') as prev_clinician_id,
    (previous_record_data ->> 'location_group_id') as prev_location_group_id,
    (previous_record_data ->> 'appointment_type_id') as prev_appointment_type_id,
    (previous_record_data ->> 'is_high_priority')::boolean as prev_is_high_priority,
    (previous_record_data ->> 'status') as prev_status,
    change_sequence
from appointment_changes
{% endmacro %}

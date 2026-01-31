-- Outpatient Appointments Audit Dataset
-- This dataset tracks changes/modifications to outpatient appointments
-- Each row represents a change event (creation, modification, or cancellation)
-- Excludes status-only changes unless the status change is to 'Cancelled'
-- Only includes appointments that have been modified (not just created)
-- change_number: 0 = initial creation, 1+ = modifications

with appointments_with_modifications as (
    -- Only include appointments that have meaningful modifications (not just status-only changes)
    select distinct appointment_id
    from {{ ref('outpatient_appointments_change_logs') }} cl
    where change_sequence > 1
        and (
            -- Has status change to Cancelled
            (cl.status = 'Cancelled' and cl.prev_status IS DISTINCT FROM 'Cancelled')
            -- Or has substantive field changes
            or (
                cl.prev_start_datetime IS DISTINCT FROM cl.start_datetime
                or cl.prev_end_datetime IS DISTINCT FROM cl.end_datetime
                or cl.prev_clinician_id IS DISTINCT FROM cl.clinician_id
                or cl.prev_location_group_id IS DISTINCT FROM cl.location_group_id
                or cl.prev_appointment_type_id IS DISTINCT FROM cl.appointment_type_id
                or cl.prev_is_high_priority IS DISTINCT FROM cl.is_high_priority
                or cl.prev_schedule_id IS DISTINCT FROM cl.schedule_id
            )
        )
),

filtered_changes as (
    select
        cl.*,
        -- Determine if this is a meaningful change
        case
            when cl.change_sequence = 1 then true -- Include creation events (will be change_number 0)
            -- Include if status changed to Cancelled
            when cl.status = 'Cancelled' and cl.prev_status IS DISTINCT FROM 'Cancelled' then true
            -- Include if any non-status fields changed
            when (
                cl.prev_start_datetime IS DISTINCT FROM cl.start_datetime
                or cl.prev_end_datetime IS DISTINCT FROM cl.end_datetime
                or cl.prev_clinician_id IS DISTINCT FROM cl.clinician_id
                or cl.prev_location_group_id IS DISTINCT FROM cl.location_group_id
                or cl.prev_appointment_type_id IS DISTINCT FROM cl.appointment_type_id
                or cl.prev_is_high_priority IS DISTINCT FROM cl.is_high_priority
                or cl.prev_schedule_id IS DISTINCT FROM cl.schedule_id
            ) then true
            -- Exclude status-only changes (including status changes that aren't to Cancelled)
            else false
        end as is_meaningful_change
    from {{ ref('outpatient_appointments_change_logs') }} cl
    -- Only process changes for appointments that have been modified
    join appointments_with_modifications awm on awm.appointment_id = cl.appointment_id
),

numbered_changes as (
    select
        fc.*,
        -- Assign change number: 0 for creation, 1+ for modifications
        -- row_number starts at 1, so subtract 1 to get 0-based numbering
        row_number() over (
            partition by fc.appointment_id
            order by fc.modified_datetime
        ) - 1 as change_number
    from filtered_changes fc
    where fc.is_meaningful_change = true
)

select
    fc.change_id,
    fc.appointment_id,
    fc.change_number,
    -- Patient details
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    -- Current appointment details
    fc.start_datetime as appointment_start_datetime,
    fc.end_datetime as appointment_end_datetime,
    apt.name as appointment_type,
    fc.appointment_type_id,
    clinician.display_name as clinician,
    fc.clinician_id,
    lg.name as location_group,
    fc.location_group_id,
    case when fc.is_high_priority then 'Yes' else 'No' end as priority,
    fc.schedule_id,
    s.until_date as repeating_end_date,
    case
        when fc.schedule_id is not null then 'Yes'
        else 'No'
    end as is_repeating,
    -- Modification details
    creator.display_name as created_by,
    fc.created_by_user_id,
    modifier.display_name as modified_by,
    fc.modified_by_user_id,
    fc.modified_datetime,
    case when fc.status = 'Cancelled' then 'Yes' else 'No' end as is_cancelled,
    -- Previous appointment details (only shown if different from current)
    case
        when fc.prev_start_datetime IS DISTINCT FROM fc.start_datetime
        then fc.prev_start_datetime
    end as prev_start_datetime,
    case
        when fc.prev_end_datetime IS DISTINCT FROM fc.end_datetime
        then fc.prev_end_datetime
    end as prev_end_datetime,
    case
        when fc.prev_appointment_type_id IS DISTINCT FROM fc.appointment_type_id
        then prev_apt.name
    end as prev_appointment_type,
    case
        when fc.prev_appointment_type_id IS DISTINCT FROM fc.appointment_type_id
        then fc.prev_appointment_type_id
    end as prev_appointment_type_id,
    case
        when fc.prev_clinician_id IS DISTINCT FROM fc.clinician_id
        then prev_clinician.display_name
    end as prev_clinician,
    case
        when fc.prev_clinician_id IS DISTINCT FROM fc.clinician_id
        then fc.prev_clinician_id
    end as prev_clinician_id,
    case
        when fc.prev_location_group_id IS DISTINCT FROM fc.location_group_id
        then prev_lg.name
    end as prev_area,
    case
        when fc.prev_location_group_id IS DISTINCT FROM fc.location_group_id
        then fc.prev_location_group_id
    end as prev_location_group_id,
    case
        when fc.prev_is_high_priority IS DISTINCT FROM fc.is_high_priority
        then case when fc.prev_is_high_priority then 'Yes' else 'No' end
    end as prev_priority,
    case
        when fc.prev_schedule_id IS DISTINCT FROM fc.schedule_id
        then fc.prev_schedule_id
    end as prev_schedule_id,
    case
        when fc.prev_schedule_id IS DISTINCT FROM fc.schedule_id
        then prev_s.until_date
    end as prev_repeating_end_date,
    case
        when fc.prev_schedule_id IS DISTINCT FROM fc.schedule_id
        then case when fc.prev_schedule_id is not null then 'Yes' else 'No' end
    end as prev_is_repeating,
    -- Facility details for filtering
    f.id as facility_id,
    f.name as facility
from numbered_changes fc
join {{ ref('patients') }} p on p.id = fc.patient_id
left join {{ ref('users') }} clinician on clinician.id = fc.clinician_id
left join {{ ref('users') }} prev_clinician on prev_clinician.id = fc.prev_clinician_id
left join {{ ref('users') }} creator on creator.id = fc.created_by_user_id
left join {{ ref('users') }} modifier on modifier.id = fc.modified_by_user_id
left join {{ ref('location_groups') }} lg on lg.id = fc.location_group_id
left join {{ ref('location_groups') }} prev_lg on prev_lg.id = fc.prev_location_group_id
left join {{ ref('reference_data') }} apt on apt.id = fc.appointment_type_id
left join {{ ref('reference_data') }} prev_apt on prev_apt.id = fc.prev_appointment_type_id
left join {{ source('tamanu', 'appointment_schedules') }} s on s.id = fc.schedule_id::uuid
left join {{ source('tamanu', 'appointment_schedules') }} prev_s on prev_s.id = fc.prev_schedule_id::uuid
-- Join to facility, department, location for filtering
left join {{ ref('facilities') }} f on f.id = lg.facility_id
    and not f.is_sensitive

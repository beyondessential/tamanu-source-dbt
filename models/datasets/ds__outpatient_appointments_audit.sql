-- Outpatient Appointments Audit Dataset
-- This dataset tracks changes/modifications to outpatient appointments
-- Each row represents a modification event (excludes initial creation)
-- Excludes status-only changes unless the status change is to 'Cancelled'
-- Only includes appointments that have been modified (not just created)
-- change_number: starts from 1 for the first modification, increments for subsequent changes

with change_evaluation as (
    select
        cl.*,
        -- Determine if this change has meaningful field modifications
        case
            -- Status changed to Cancelled
            when cl.status = 'Cancelled' and cl.prev_status IS DISTINCT FROM 'Cancelled' then true
            -- Any non-status fields changed
            when (
                cl.prev_start_datetime IS DISTINCT FROM cl.start_datetime
                or cl.prev_end_datetime IS DISTINCT FROM cl.end_datetime
                or cl.prev_clinician_id IS DISTINCT FROM cl.clinician_id
                or cl.prev_location_group_id IS DISTINCT FROM cl.location_group_id
                or cl.prev_appointment_type_id IS DISTINCT FROM cl.appointment_type_id
                or cl.prev_is_high_priority IS DISTINCT FROM cl.is_high_priority
            ) then true
            else false
        end as is_meaningful_change
    from {{ ref('outpatient_appointments_change_logs') }} cl
),

numbered_changes as (
    select
        ce.*,
        -- Assign change number: starts from 1 for first modification
        row_number() over (
            partition by ce.appointment_id
            order by ce.modified_datetime
        ) as change_number
    from change_evaluation ce
    where ce.is_meaningful_change = true
        and ce.change_sequence > 1  -- Exclude initial creation
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
    end as prev_location_group,
    case
        when fc.prev_location_group_id IS DISTINCT FROM fc.location_group_id
        then fc.prev_location_group_id
    end as prev_location_group_id,
    case
        when fc.prev_is_high_priority IS NOT NULL
            and fc.prev_is_high_priority IS DISTINCT FROM fc.is_high_priority
        then case when fc.prev_is_high_priority then 'Yes' else 'No' end
    end as prev_priority, 
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
-- Join to facility, department, location for filtering
left join {{ ref('facilities') }} f on f.id = lg.facility_id
    and not f.is_sensitive

{% macro outpatient_appointments_audit_dataset(is_sensitive=false) %}

{{
    config(
        materialized='incremental' if target.name.startswith('analytics') else 'view',
        incremental_strategy='delete+insert',
        unique_key='appointment_id'
    )
}}

-- Outpatient Appointments Audit Dataset
-- One row per meaningful modification to an appointment, excluding creation and status-only
-- changes. Full, unfiltered history -- the report applies its own date range. BL-023, BL-025.
--
-- delete+insert keyed on appointment_id, not append: change_number and the prev_* columns
-- come from window functions partitioned by appointment_id, so a new event invalidates that
-- appointment's LATER rows, whose own cursor never moves. Append would leave them stale.
-- BL-034.
--
-- Incremental refresh is not self-healing: dbt only deletes ids present in the new result,
-- and candidates are detected from logs.changes alone. An appointment recomputing to zero
-- rows, or a change in facility sensitivity or a joined name, leaves stale rows behind.
-- Needs a periodic --full-refresh. BL-035.

with
{% if is_incremental() %}
candidate_appointment_ids as (
    -- >= not >: a sync tick is shared by every row written in that session, so a strict
    -- comparison would permanently skip rows landing on the boundary tick after the last
    -- run read it. Reprocessing that tick is free -- delete+insert is idempotent per
    -- appointment. BL-032.
    select distinct c.record_id as appointment_id
    from {{ ref('outpatient_appointment_change_events') }} c
    where c.updated_at_sync_tick >= (select coalesce(max(updated_at_sync_tick), 0) from {{ this }})
),
{% endif %}

change_evaluation as (
    select
        cl.*,
        -- Determine if this change has meaningful field modifications
        case
            -- Status changed to Cancelled
            when cl.status = 'Cancelled' and cl.prev_status is distinct from 'Cancelled' then true
            -- Any non-status fields changed
            when (
                cl.prev_start_datetime is distinct from cl.start_datetime
                or cl.prev_end_datetime is distinct from cl.end_datetime
                or cl.prev_clinician_id is distinct from cl.clinician_id
                or cl.prev_location_group_id is distinct from cl.location_group_id
                or cl.prev_appointment_type_id is distinct from cl.appointment_type_id
                or cl.prev_is_high_priority is distinct from cl.is_high_priority
            ) then true
            else false
        end as is_meaningful_change
    from (
        {{ outpatient_appointments_change_log_events(
            record_id_filter="c.record_id in (select appointment_id from candidate_appointment_ids)" if is_incremental() else none
        ) }}
    ) cl
    -- Inner join: restricts the audit to the appointment population bases/ defines, which
    -- excludes soft-deleted appointments (BL-036), and supplies the schedule's
    -- cancelled_at_date without reading the source table.
    join {{ ref('outpatient_appointments') }} a on a.id = cl.appointment_id
    where
        -- Exclude appointments that were automatically cancelled when the schedule was cancelled
        -- (Keep appointments that were individually cancelled, not bulk-cancelled via schedule)
        not (
            cl.status = 'Cancelled'
            and a.cancelled_at_date is not null
            and cl.start_datetime::date > a.cancelled_at_date::date
        )
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
    -- Incremental cursor for analytics builds (see header comment) -- not report-facing,
    -- but must be a persisted column so later runs can read the watermark back from it.
    fc.updated_at_sync_tick,
    case when fc.status = 'Cancelled' then 'Yes' else 'No' end as is_cancelled,
    -- Previous appointment details (only shown if different from current)
    case
        when fc.prev_start_datetime is distinct from fc.start_datetime
        then fc.prev_start_datetime
    end as prev_start_datetime,
    case
        when fc.prev_end_datetime is distinct from fc.end_datetime
        then fc.prev_end_datetime
    end as prev_end_datetime,
    case
        when fc.prev_appointment_type_id is distinct from fc.appointment_type_id
        then prev_apt.name
    end as prev_appointment_type,
    case
        when fc.prev_appointment_type_id is distinct from fc.appointment_type_id
        then fc.prev_appointment_type_id
    end as prev_appointment_type_id,
    case
        when fc.prev_clinician_id is distinct from fc.clinician_id
        then prev_clinician.display_name
    end as prev_clinician,
    case
        when fc.prev_clinician_id is distinct from fc.clinician_id
        then fc.prev_clinician_id
    end as prev_clinician_id,
    case
        when fc.prev_location_group_id is distinct from fc.location_group_id
        then prev_lg.name
    end as prev_location_group,
    case
        when fc.prev_location_group_id is distinct from fc.location_group_id
        then fc.prev_location_group_id
    end as prev_location_group_id,
    case
        when fc.prev_is_high_priority is not null
            and fc.prev_is_high_priority is distinct from fc.is_high_priority
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
join {{ ref('location_groups') }} lg on lg.id = fc.location_group_id
left join {{ ref('location_groups') }} prev_lg on prev_lg.id = fc.prev_location_group_id
left join {{ ref('reference_data') }} apt on apt.id = fc.appointment_type_id
left join {{ ref('reference_data') }} prev_apt on prev_apt.id = fc.prev_appointment_type_id
-- Join to facility for filtering by sensitivity
join {{ ref('facilities') }} f on f.id = lg.facility_id
    and f.is_sensitive = {{ is_sensitive }}
-- No tail filter on the cursor, deliberately: delete+insert removes all of a candidate's
-- existing rows, so this must re-emit its full history, not just the changed rows. BL-034.

{% endmacro %}

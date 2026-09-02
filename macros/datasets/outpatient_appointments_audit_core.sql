{% macro outpatient_appointments_audit_core(is_sensitive=false, record_id_filter=none) %}
-- Shared audit rows: everything both the dataset and the report need, resolved but
-- unformatted. Callers differ only in projection -- the dataset renames, the report applies
-- translate_label and to_char. Keeping the logic here is what stops the two drifting, which
-- has happened before.

with change_evaluation as (
    select
        cl.*,
        -- BL-025: which field changes count as meaningful
        case
            when cl.status = 'Cancelled' and cl.prev_status is distinct from 'Cancelled' then true
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
        {{ outpatient_appointments_change_log_events(record_id_filter=record_id_filter) }}
    ) cl
    -- BL-036: restricts the audit to the population bases/outpatient_appointments defines,
    -- and supplies cancelled_at_date for BL-026 without reading the source table
    join {{ ref('outpatient_appointments') }} a on a.id = cl.appointment_id
    where
        -- BL-026: drop appointments auto-cancelled by a schedule bulk-cancellation, keeping
        -- individual cancellations
        not (
            cl.status = 'Cancelled'
            and a.cancelled_at_date is not null
            and cl.start_datetime::date > a.cancelled_at_date::date
        )
),

numbered_changes as (
    select
        ce.*,
        -- BL-024: 1 for the first meaningful change, incrementing per appointment.
        -- change_sequence breaks ties so the number is deterministic and matches the
        -- extraction's own ordering.
        row_number() over (
            partition by ce.appointment_id
            order by ce.modified_datetime, ce.change_sequence
        ) as change_number
    from change_evaluation ce
    where ce.is_meaningful_change = true
        and ce.change_sequence > 1  -- BL-023: exclude the creation event
)

select
    fc.change_id,
    fc.appointment_id,
    fc.change_number,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    fc.start_datetime,
    fc.end_datetime,
    apt.name as appointment_type,
    fc.appointment_type_id,
    clinician.display_name as clinician,
    fc.clinician_id,
    lg.name as location_group,
    fc.location_group_id,
    fc.is_high_priority,
    fc.schedule_id,
    fc.status,
    creator.display_name as created_by,
    fc.created_by_user_id,
    modifier.display_name as modified_by,
    fc.modified_by_user_id,
    fc.modified_datetime,
    fc.updated_at_sync_tick,
    -- BL-027: previous values, blank where unchanged
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
        then prev_lg.id
    end as prev_location_group_id,
    case
        when fc.prev_is_high_priority is not null
            and fc.prev_is_high_priority is distinct from fc.is_high_priority
        then fc.prev_is_high_priority
    end as prev_is_high_priority,
    f.id as facility_id,
    f.name as facility
from numbered_changes fc
join {{ ref('patients') }} p on p.id = fc.patient_id
left join {{ ref('users') }} clinician on clinician.id = fc.clinician_id
left join {{ ref('users') }} prev_clinician on prev_clinician.id = fc.prev_clinician_id
left join {{ ref('users') }} creator on creator.id = fc.created_by_user_id
left join {{ ref('users') }} modifier on modifier.id = fc.modified_by_user_id
-- BL-028: patient, area and facility are inner joins, so an event whose
-- location_group_id is null or dangling produces no row at all
join {{ ref('location_groups') }} lg on lg.id = fc.location_group_id
-- BL-033: the previous area resolves through the partition as well, so a standard report
-- cannot name an area in a sensitive facility an appointment was moved out of. The sensitive
-- variant is the privileged view and sees areas from both sides.
left join (
    select lg2.id, lg2.name
    from {{ ref('location_groups') }} lg2
    join {{ ref('facilities') }} f2 on f2.id = lg2.facility_id
    {%- if not is_sensitive %}
    where f2.is_sensitive = false
    {%- endif %}
) prev_lg on prev_lg.id = fc.prev_location_group_id
left join {{ ref('reference_data') }} apt on apt.id = fc.appointment_type_id
left join {{ ref('reference_data') }} prev_apt on prev_apt.id = fc.prev_appointment_type_id
-- BL-033: facility scope partitioned by the is_sensitive argument
join {{ ref('facilities') }} f on f.id = lg.facility_id
    and f.is_sensitive = {{ is_sensitive }}

{% endmacro %}

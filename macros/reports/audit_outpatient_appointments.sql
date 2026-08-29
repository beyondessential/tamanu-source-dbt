{% macro audit_outpatient_appointments_report(is_sensitive=false) %}

-- Outpatient Appointment Audit Report
-- One row per change event, with current and previous appointment details.
--
-- The logic lives here rather than in a dataset view so the date range can be applied
-- before the change-log window functions, which would otherwise block predicate pushdown
-- and force a full logs.changes scan on every run. BL-030.

-- Narrows to appointments with an event in range, using no window functions so the
-- predicate reaches the scan. The final WHERE re-applies the same filter, so correctness
-- never depends on this being exact.
with candidate_appointment_ids as (
    select distinct c.record_id as appointment_id
    from {{ source('logs__tamanu', 'changes') }} c
    where c.table_name = 'appointments'
        and c.record_deleted_at is null
        and (c.record_data ->> 'appointment_type_id') is not null
        and (c.record_data ->> 'patient_id') != '{{ var("test_patient") }}'
        and {{ to_user_selected_timezone("(c.record_data ->> 'start_time')::timestamp") }}
            >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
        and {{ to_user_selected_timezone("(c.record_data ->> 'start_time')::timestamp") }}
            <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
),

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
            record_id_filter="c.record_id in (select appointment_id from candidate_appointment_ids)"
        ) }}
    ) cl
    left join {{ source('tamanu', 'appointment_schedules') }} s on s.id = cl.schedule_id
    where
        -- Exclude appointments that were automatically cancelled when the schedule was cancelled
        -- (Keep appointments that were individually cancelled, not bulk-cancelled via schedule)
        not (
            cl.status = 'Cancelled'
            and s.cancelled_at_date is not null
            and cl.start_datetime::date > s.cancelled_at_date::date
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
    p.display_id as "{{ translate_label('patientDisplayId') }}",
    p.first_name as "{{ translate_label('patientFirstName') }}",
    p.last_name as "{{ translate_label('patientLastName') }}",
    to_char(p.date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    -- Change event details
    fc.change_number as "{{ translate_label('auditChangeNumber') }}",
    -- Current appointment details (at time of report)
    to_char({{ to_user_selected_timezone('fc.start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentDateTime') }}",
    apt.name as "{{ translate_label('appointmentType') }}",
    clinician.display_name as "{{ translate_label('appointmentClinician') }}",
    lg.name as "{{ translate_label('appointmentLocationGroup') }}",
    case when fc.is_high_priority then 'Yes' else 'No' end as "{{ translate_label('appointmentPriority') }}",
    case
        when fc.schedule_id is not null then 'Yes'
        else 'No'
    end as "{{ translate_label('appointmentIsRepeating') }}",
    -- Modification details
    creator.display_name as "{{ translate_label('auditCreatedBy') }}",
    modifier.display_name as "{{ translate_label('auditModifiedBy') }}",
    to_char({{ to_user_selected_timezone('fc.modified_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('auditModifiedDateTime') }}",
    case when fc.status = 'Cancelled' then 'Yes' else 'No' end as "{{ translate_label('appointmentIsCancelled') }}",
    -- Previous appointment details (only shown if different from current)
    case
        when fc.prev_start_datetime is distinct from fc.start_datetime
        then to_char({{ to_user_selected_timezone('fc.prev_start_datetime') }}, '{{ var("datetime_format") }}')
    end as "{{ translate_label('auditPrevAppointmentDateTime') }}",
    case
        when fc.prev_appointment_type_id is distinct from fc.appointment_type_id
        then prev_apt.name
    end as "{{ translate_label('auditPrevAppointmentType') }}",
    case
        when fc.prev_clinician_id is distinct from fc.clinician_id
        then prev_clinician.display_name
    end as "{{ translate_label('auditPrevClinician') }}",
    case
        when fc.prev_location_group_id is distinct from fc.location_group_id
        then prev_lg.name
    end as "{{ translate_label('auditPrevLocationGroup') }}",
    case
        when fc.prev_is_high_priority is not null
            and fc.prev_is_high_priority is distinct from fc.is_high_priority
        then case when fc.prev_is_high_priority then 'Yes' else 'No' end
    end as "{{ translate_label('auditPrevPriority') }}"
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
where
    -- Date range filter on appointment datetime (safety net -- see header comment)
    {{ to_user_selected_timezone('fc.start_datetime') }}
        >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('fc.start_datetime') }}
        <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
    -- Facility filter
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else f.id = {{ parameter('facilityId') }}
    end
order by p.display_id, fc.appointment_id, fc.change_number

{% endmacro %}

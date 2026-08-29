{% macro audit_outpatient_appointments_report(is_sensitive=false) %}

-- Outpatient Appointment Audit Report
-- One row per change event, with current and previous appointment details.
--
-- BL-030: the logic lives here, not in a dataset view, so the date range can be applied
-- before the change-log window functions -- which would otherwise block predicate pushdown
-- and force a full change-log scan on every run. The candidate CTE below uses no window
-- functions so the predicate reaches the scan; the final WHERE re-applies the same filter,
-- so correctness never depends on the early filter being exact.
with candidate_appointment_ids as (
    select distinct c.record_id as appointment_id
    from {{ ref('outpatient_appointments_change_events') }} c
    where {{ to_user_selected_timezone("(c.record_data ->> 'start_time')::timestamp") }}
            >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
        and {{ to_user_selected_timezone("(c.record_data ->> 'start_time')::timestamp") }}
            <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
),

change_evaluation as (
    select
        cl.*,
        -- BL-025: which field changes count as meaningful
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
        -- BL-024: 1 for the first meaningful change, incrementing per appointment
        row_number() over (
            partition by ce.appointment_id
            order by ce.modified_datetime
        ) as change_number
    from change_evaluation ce
    where ce.is_meaningful_change = true
        and ce.change_sequence > 1  -- BL-023: exclude the creation event
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
    -- BL-027: previous values, blank where unchanged
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
-- BL-028: patient, area and facility are inner joins, so an event whose
-- location_group_id is null or dangling produces no row at all
join {{ ref('location_groups') }} lg on lg.id = fc.location_group_id
left join {{ ref('location_groups') }} prev_lg on prev_lg.id = fc.prev_location_group_id
left join {{ ref('reference_data') }} apt on apt.id = fc.appointment_type_id
left join {{ ref('reference_data') }} prev_apt on prev_apt.id = fc.prev_appointment_type_id
-- BL-033: facility scope partitioned by the is_sensitive argument
join {{ ref('facilities') }} f on f.id = lg.facility_id
    and f.is_sensitive = {{ is_sensitive }}
where
    -- BL-029: filters the event's own appointment start, not when the edit was made.
    -- Also the BL-030 safety net -- see header.
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

{% macro audit_outpatient_appointments_report(is_sensitive=false) %}

-- Outpatient Appointment Audit Report
-- One row per change event, with current and previous appointment details.
--
-- BL-030: the date range is applied before the change-log window functions, which would
-- otherwise block predicate pushdown and force a full change-log scan on every run. The
-- candidate filter below uses no window functions so the predicate reaches the scan; the
-- final WHERE re-applies the same filter, so correctness never depends on the early filter
-- being exact.
--
-- Business logic lives in outpatient_appointments_audit_core() alongside the dataset; this
-- macro only filters and formats.

{%- set candidate_filter -%}
c.record_id in (
    select distinct c2.record_id
    from {{ ref('outpatient_appointments_change_events') }} c2
    where {{ to_user_selected_timezone("(c2.record_data ->> 'start_time')::timestamp") }}
            >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
        and {{ to_user_selected_timezone("(c2.record_data ->> 'start_time')::timestamp") }}
            <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
)
{%- endset -%}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    change_number as "{{ translate_label('auditChangeNumber') }}",
    to_char({{ to_user_selected_timezone('start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentDateTime') }}",
    appointment_type as "{{ translate_label('appointmentType') }}",
    clinician as "{{ translate_label('appointmentClinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup') }}",
    case when is_high_priority then 'Yes' else 'No' end as "{{ translate_label('appointmentPriority') }}",
    case when schedule_id is not null then 'Yes' else 'No' end as "{{ translate_label('appointmentIsRepeating') }}",
    created_by as "{{ translate_label('auditCreatedBy') }}",
    modified_by as "{{ translate_label('auditModifiedBy') }}",
    to_char({{ to_user_selected_timezone('modified_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('auditModifiedDateTime') }}",
    case when status = 'Cancelled' then 'Yes' else 'No' end as "{{ translate_label('appointmentIsCancelled') }}",
    to_char({{ to_user_selected_timezone('prev_start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('auditPrevAppointmentDateTime') }}",
    prev_appointment_type as "{{ translate_label('auditPrevAppointmentType') }}",
    prev_clinician as "{{ translate_label('auditPrevClinician') }}",
    prev_location_group as "{{ translate_label('auditPrevLocationGroup') }}",
    case when prev_is_high_priority then 'Yes' else 'No' end as "{{ translate_label('auditPrevPriority') }}"
from (
    {{ outpatient_appointments_audit_core(
        is_sensitive=is_sensitive,
        record_id_filter=candidate_filter
    ) }}
) core
where
    -- BL-029: filters the event's own appointment start, not when the edit was made.
    -- Also the BL-030 safety net -- see header.
    {{ to_user_selected_timezone('start_datetime') }}
        >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('start_datetime') }}
        <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
order by display_id, appointment_id, change_number

{% endmacro %}

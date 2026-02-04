-- Outpatient Appointment Audit Report
-- Shows all modifications and cancellations to outpatient appointments
-- Each row represents a change event with both current and previous appointment details

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    -- Change event details
    change_number as "{{ translate_label('auditChangeNumber') }}",
    -- Current appointment details (at time of report)
    to_char(appointment_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentDateTime') }}",
    appointment_type as "{{ translate_label('appointmentType') }}",
    clinician as "{{ translate_label('appointmentClinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup') }}",
    priority as "{{ translate_label('appointmentPriority') }}",
    to_char(repeating_end_date::date, '{{ var("date_format") }}') as "{{ translate_label('appointmentRepeatingEndDate') }}",
    -- Modification details
    created_by as "{{ translate_label('auditCreatedBy') }}",
    modified_by as "{{ translate_label('auditModifiedBy') }}",
    to_char(modified_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('auditModifiedDateTime') }}",
    is_cancelled as "{{ translate_label('appointmentIsCancelled') }}",
    -- Previous appointment details (prior to changes)
    to_char(prev_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('auditPrevAppointmentDateTime') }}",
    prev_appointment_type as "{{ translate_label('auditPrevAppointmentType') }}",
    prev_clinician as "{{ translate_label('auditPrevClinician') }}",
    prev_location_group as "{{ translate_label('auditPrevLocationGroup') }}",
    prev_priority as "{{ translate_label('auditPrevPriority') }}"
from {{ ref('ds__outpatient_appointments_audit') }}
where
    -- Date range filter on appointment datetime
    case
        when {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }} is null then true
        else appointment_start_datetime >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2025-01-31', data_type='date') }} is null then true
        else appointment_start_datetime <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
    end
    -- Facility filter
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
order by display_id, appointment_id, change_number

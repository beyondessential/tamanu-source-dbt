select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    billing_type as "{{ translate_label('patientBillingType', 'Patient billing type') }}",
    appointment_start_datetime as "{{ translate_label('appointmentDateTime', 'Appointment date and time') }}",
    appointment_end_datetime as "{{ translate_label('appointmentEndDateTime', 'Appointment end date and time') }}",
    appointment_type as "{{ translate_label('appointmentType', 'Appointment type') }}",
    appointment_status as "{{ translate_label('appointmentStatus', 'Appointment status') }}",
    clinician as "{{ translate_label('appointmentClinician', 'Clinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup', 'Area') }}",

    priority as "{{ translate_label('appointmentPriority', 'Priority appointment') }}",
    case
        when schedule_id notnull then {{ get_recurrence_description('interval', 'frequency', 'days_of_week', 'nth_weekday') }}
        else 'No'
    end as "{{ translate_label('appointmentIsRepeating', 'Repeating appointment') }}",
    until_date as "{{ translate_label('appointmentRepeatingEndDate', 'Repeating appointment end date') }}"
from {{ ref('ds__appointments') }}
where case
        when {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }} is null then true
        else appointment_start_datetime >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2025-01-31', data_type='date') }} is null then true
        else appointment_start_datetime <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}

    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id = {{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('appointmentStatus') }} is null then true
        else appointment_status = {{ parameter('appointmentStatus') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else clinician_id = {{ parameter('clinicianId') }}
    end
    and
    case
        when {{ parameter('appointmentTypeId') }} is null then true
        else appointment_type_id = {{ parameter('appointmentTypeId') }}
    end

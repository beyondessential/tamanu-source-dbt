select
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label','Village') }}",
    billing_type as "{{ translate_string('general.localisedField.patientBillingTypeId.label', 'Patient type') }}",
    to_char(appointment_start_datetime, '{{ var("datetime_format") }}') as "Appointment date and time",
    appointment_type as "{{ translate_string('scheduling.newAppointment.type.label', 'Appointment type') }}",
    appointment_status as "{{ translate_string('', 'Appointment status') }}",
    clinician as "{{ translate_string('general.localisedField.clinician.label', 'Clinician') }}",
    location_group as "{{ translate_string('general.localisedField.area.label', 'Area') }}"
from {{ ref('ds__appointments') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else appointment_start_datetime >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else appointment_start_datetime <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id ={{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('appointmentStatus') }} is null then true
        else appointment_status ={{ parameter('appointmentStatus') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else clinician_id ={{ parameter('clinicianId') }}
    end

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    appointment_start_datetime as "{{ translate_label('appointmentDateTime') }}",
    appointment_end_datetime as "{{ translate_label('appointmentEndDateTime') }}",
    appointment_type as "{{ translate_label('appointmentType') }}",
    appointment_status as "{{ translate_label('appointmentStatus') }}",
    clinician as "{{ translate_label('appointmentClinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup') }}",

    priority as "{{ translate_label('appointmentPriority') }}",
    case
        when schedule_id notnull then {{ get_recurrence_description('interval', 'frequency', 'days_of_week', 'nth_weekday') }}
        else 'No'
    end as "{{ translate_label('appointmentIsRepeating') }}",
    until_date as "{{ translate_label('appointmentRepeatingEndDate') }}"
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

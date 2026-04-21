select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    contact_number as "{{ translate_label('patientContactNumber') }}",
    village as "{{ translate_label('patientVillage') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    to_char({{ to_user_selected_timezone('appointment_start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentDateTime') }}",
    to_char({{ to_user_selected_timezone('appointment_end_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentEndDateTime') }}",
    appointment_type as "{{ translate_label('appointmentType') }}",
    appointment_status as "{{ translate_label('appointmentStatus') }}",
    clinician as "{{ translate_label('appointmentClinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup') }}",
    priority as "{{ translate_label('appointmentPriority') }}",
    case
        when schedule_id notnull then {{ get_recurrence_description('interval', 'frequency', 'days_of_week', 'nth_weekday') }}
        else 'No'
    end as "{{ translate_label('appointmentIsRepeating') }}",
    to_char(until_date, '{{ var("date_format") }}') as "{{ translate_label('appointmentRepeatingEndDate') }}",
    created_by as "{{ translate_label('appointmentCreatedBy') }}"
from {{ ref('ds__sensitive_outpatient_appointments') }}
where case
        when {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }} is null then true
        else {{ to_user_selected_timezone('appointment_start_datetime') }} >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2025-01-31', data_type='date') }} is null then true
        else {{ to_user_selected_timezone('appointment_start_datetime') }} <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id = {{ parameter('locationGroupId') }}
    end
    and
    case
        when coalesce({{ parameter('appointmentStatus') }}) is null then true
        else appointment_status in ({{ parameter('appointmentStatus') }})
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
order by appointment_start_datetime

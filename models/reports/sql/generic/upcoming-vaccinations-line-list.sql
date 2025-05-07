select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    due_date as "{{ translate_string('vaccinationDueDate', 'Vaccination due date') }}",
    vaccine_name as "{{ translate_string('vaccineName', 'Vaccine name') }}",
    vaccine_schedule as "{{ translate_string('vaccineSchedule', 'Schedule') }}",
    vaccine_status as "{{ translate_string('vaccinationStatus', 'Vaccine status') }}"
from {{ ref("ds__patient_vaccinations_upcoming") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_of_birth::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_of_birth::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('status') }} is null then true
        else vaccine_status = {{ parameter('status') }}
    end
    and
    case
        when {{ parameter('category') }} is null then true
        else vaccine_category = {{ parameter('category') }}
    end
    and
    case
        when {{ parameter('vaccine') }} is null then true
        else vaccine_name = {{ parameter('vaccine') }}
    end

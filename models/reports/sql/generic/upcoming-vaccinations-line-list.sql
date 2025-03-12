select
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    to_char(due_date, '{{ var("date_format") }}') as "{{ translate_string('', 'Vaccination due date') }}",
    vaccine_name as "{{ translate_string('vaccine.vaccineName.label', 'Vaccine name') }}",
    vaccine_schedule as "{{ translate_string('vaccine.schedule.label', 'Schedule') }}",
    vaccine_status as "{{ translate_string('general.localisedField.vaccinationStatus.label', 'Vaccine status') }}"
from {{ ref("ds__patient_vaccinations_upcoming") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_of_birth::date
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_of_birth::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('status') }} is null then true
        else vaccine_status ={{ parameter('status') }}
    end
    and
    case
        when {{ parameter('category') }} is null then true
        else vaccine_category ={{ parameter('category') }}
    end
    and
    case
        when {{ parameter('vaccine') }} is null then true
        else vaccine_name ={{ parameter('vaccine') }}
    end

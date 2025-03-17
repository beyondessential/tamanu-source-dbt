select
    display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label','First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label','Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    registering_facility as "{{ translate_string('general.localisedField.facility.label', 'Registering facility') }}",
    registered_by as "{{ translate_string('', 'Registered by') }}",
    currently_at as "{{ translate_string('', 'Currently in') }}",
    related_conditions as "{{ translate_string('', 'Related conditions') }}",
    clinical_status as "{{ translate_string('', 'Status') }}",
    to_char(registration_datetime, '{{ var("date_format") }}') as "{{ translate_string('', 'Date of Registration') }}"
from {{ ref('ds__patient_program_registrations') }}
where registration_status = 'active'
    and is_most_recent
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else registration_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else registration_datetime::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('registryId') }} is null then true
        else program_registry_id = {{ parameter('registryId') }}
    end

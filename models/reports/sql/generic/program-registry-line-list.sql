select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    registering_facility as "{{ translate_string('registryRegisteringFacility', 'Registering facility') }}",
    registered_by as "{{ translate_string('registryRegisteredBy', 'Registered by') }}",
    currently_at as "{{ translate_string('registryCurrentlyAt', 'Currently at') }}",
    related_conditions as "{{ translate_string('registryConditions', 'Related conditions') }}",
    clinical_status as "{{ translate_string('registryClinicalStatus', 'Status') }}",
    registration_datetime as "{{ translate_string('registryRegisteredDate', 'Date of registration') }}"
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

select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility', 'Registering facility') }}",
    registered_by as "{{ translate_label('registryRegisteredBy', 'Registered by') }}",
    currently_at as "{{ translate_label('registryCurrentlyAt', 'Currently at') }}",
    related_conditions as "{{ translate_label('registryConditions', 'Related conditions') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus', 'Status') }}",
    registration_datetime as "{{ translate_label('registryRegisteredDate', 'Date of registration') }}"
from {{ ref('ds__patient_program_registrations') }}
where registration_status = 'active'
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

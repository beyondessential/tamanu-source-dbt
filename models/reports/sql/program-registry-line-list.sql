select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility') }}",
    registered_by as "{{ translate_label('registryRegisteredBy') }}",
    currently_at as "{{ translate_label('registryCurrentlyAt') }}",
    related_conditions as "{{ translate_label('registryConditions') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus') }}",
    registration_datetime as "{{ translate_label('registryRegisteredDate') }}"
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

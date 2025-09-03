select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility') }}",
    subdivision as "{{ translate_label('patientSubdivision') }}",
    division as "{{ translate_label('patientDivision') }}",
    registered_by as "{{ translate_label('registryRegisteredBy') }}",
    currently_at as "{{ translate_label('registryCurrentlyAt') }}",
    related_conditions as "{{ translate_label('registryConditions') }}",
    related_condition_categories as "{{ translate_label('registryConditionCategories') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus') }}",
    to_char(registration_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('registryRegisteredDate') }}"
from {{ ref('ds__patient_program_registrations') }}
where registration_status = 'active'
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else registration_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else registration_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('registryId') }} is null then true
        else program_registry_id = {{ parameter('registryId') }}
    end
    and
    case
        when {{ parameter('subdivisionId') }} is null then true
        else subdivision_id = {{ parameter('subdivisionId') }}
    end
    and
    case
        when {{ parameter('divisionId') }} is null then true
        else division_id = {{ parameter('divisionId') }}
    end
order by registration_datetime desc

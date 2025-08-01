select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility', 'Registering facility') }}",
    registered_by as "{{ translate_label('registryRegisteredBy', 'Registered by') }}",
    currently_at as "{{ translate_label('registryCurrentlyAt', 'Currently at') }}",
    related_conditions as "{{ translate_label('registryConditions', 'Related conditions') }}",
    related_condition_categories as "{{ translate_label('registryConditionCategories', 'Related condition categories') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus', 'Status') }}",
    to_char(registration_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('registryRegisteredDate', 'Date of registration') }}",
    to_char(deactivated_datetime::date, '{{ var("date_format") }}') as "{{ translate_label('registryDeactivatedDate', 'Date of removal') }}",
    deactivated_by as "{{ translate_label('registryDeactivatedBy', 'Removed by') }}"
from {{ ref('ds__patient_program_registrations') }}
where registration_status != 'active'
    and
    case
        when {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }} is null then true
        else deactivated_datetime
            >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2025-01-31', data_type='date') }} is null then true
        else deactivated_datetime
            <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('registryId') }} is null then true
        else program_registry_id = {{ parameter('registryId') }}
    end
order by deactivated_datetime desc

select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    registering_facility as "{{ translate_label_from_seed('registryRegisteringFacility') }}",
    registered_by as "{{ translate_label_from_seed('registryRegisteredBy') }}",
    currently_at as "{{ translate_label_from_seed('registryCurrentlyAt') }}",
    related_conditions as "{{ translate_label_from_seed('registryConditions') }}",
    related_condition_categories as "{{ translate_label_from_seed('registryConditionCategories') }}",
    clinical_status as "{{ translate_label_from_seed('registryClinicalStatus') }}",
    to_char(registration_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('registryRegisteredDate') }}",
    to_char(deactivated_datetime::date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('registryDeactivatedDate') }}",
    deactivated_by as "{{ translate_label_from_seed('registryDeactivatedBy') }}"
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

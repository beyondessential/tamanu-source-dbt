select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility') }}",
    registered_by as "{{ translate_label('registryRegisteredBy') }}",
    currently_at as "{{ translate_label('registryCurrentlyAt') }}",
    related_conditions as "{{ translate_label('registryConditions') }}",
    related_condition_categories as "{{ translate_label('registryConditionCategories') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus') }}",
    to_char({{ to_user_selected_timezone('registration_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('registryRegisteredDate') }}",
    to_char({{ to_user_selected_timezone('deactivated_datetime') }}::date, '{{ var("date_format") }}') as "{{ translate_label('registryDeactivatedDate') }}",
    deactivated_by as "{{ translate_label('registryDeactivatedBy') }}"
from {{ ref('ds__patient_program_registrations') }}
where registration_status != 'active'
    and
    case
        when {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }} is null then true
        else {{ to_user_selected_timezone('deactivated_datetime') }}
            >= {{ parameter('fromDate', default_value='2025-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2025-01-31', data_type='date') }} is null then true
        else {{ to_user_selected_timezone('deactivated_datetime') }}
            <= {{ parameter('toDate', default_value='2025-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('registryId') }} is null then true
        else program_registry_id = {{ parameter('registryId') }}
    end
order by deactivated_datetime desc

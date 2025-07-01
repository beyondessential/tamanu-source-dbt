select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'Patient first name') }}",
    last_name as "{{ translate_label('patientLastName', 'Patient last name') }}",
    date_of_birth::date as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    initcap(sex::text) as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Home village') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility', 'Registering facility') }}",
    related_conditions as "{{ translate_label('registryConditions', 'Related conditions') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus', 'Status') }}",
    registered_by as "{{ translate_label('registryRegisteredBy', 'Registered by') }}",
    registration_datetime::date as "{{ translate_label('registryRegisteredDate', 'Date of registration') }}",
    removal_datetime::date as "{{ translate_label('registryRemovedDate', 'Date of removal') }}",
    removed_by as "{{ translate_label('registryRemovedBy', 'Removed by') }}"
from {{ ref('ds__program_registry_removed_patients') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else removal_datetime::date
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
order by removal_datetime desc

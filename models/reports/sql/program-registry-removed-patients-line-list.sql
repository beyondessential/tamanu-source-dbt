select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth::date as "{{ translate_label('patientDateOfBirth') }}",
    initcap(sex::text) as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    registering_facility as "{{ translate_label('registryRegisteringFacility') }}",
    related_conditions as "{{ translate_label('registryConditions') }}",
    clinical_status as "{{ translate_label('registryClinicalStatus') }}",
    registered_by as "{{ translate_label('registryRegisteredBy') }}",
    registration_datetime::date as "{{ translate_label('registryRegisteredDate') }}",
    removal_datetime::date as "{{ translate_label('registryRemovedDate') }}",
    removed_by as "{{ translate_label('registryRemovedBy') }}"
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

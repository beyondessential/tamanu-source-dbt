select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    medical_area as "{{ translate_label('patientMedicalArea') }}",
    sub_division as "{{ translate_label('patientSubDivision') }}",
    division as "{{ translate_label('patientDivision') }}",
    condition as "{{ translate_label('registryConditions') }}",
    condition_category as "{{ translate_label('registryConditionCategories') }}",
    to_char(condition_recorded_date, '{{ var("date_format") }}') as "{{ translate_label('registryConditionRecordedDate') }}",
    condition_recorded_by as "{{ translate_label('registryConditionRecordedBy') }}",
    registration_status as "{{ translate_label('registryRegistrationStatus') }}"
from {{ ref('ds__patient_program_registration_conditions') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else condition_recorded_date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else condition_recorded_date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('registryId') }} is null then true
        else program_registry_id = {{ parameter('registryId') }}
    end
    and
    case 
        when {{ parameter('medicalAreaId') }} is null then true
        else medical_area_id = {{ parameter('medicalAreaId') }}
    end
    and
    case
        when {{ parameter('subDivisionId') }} is null then true
        else sub_division_id = {{ parameter('subDivisionId') }}
    end
    and
    case
        when {{ parameter('divisionId') }} is null then true
        else division_id = {{ parameter('divisionId') }}
    end
    and
    case
        when {{ parameter('conditionId') }} is null then true
        else condition_id = {{ parameter('conditionId') }}
    end

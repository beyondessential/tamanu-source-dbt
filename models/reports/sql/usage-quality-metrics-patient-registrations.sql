select
    registration_date as "{{ translate_label('patientRegistrationDate') }}",
    total_patient_registrations as "{{ translate_label('patientTotalPatientRegistrations') }}",
    total_birth_registrations as "{{ translate_label('patientTotalBirthRegistrations') }}",
    total_incorrect_registrations_for_patient_under_6mth as "{{ translate_label('patientTotalIncorrectRegistrationsForAgedUnder6Months') }}"
from {{ ref("ds__usage_quality_metrics_patient_registrations") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else registration_date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else registration_date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
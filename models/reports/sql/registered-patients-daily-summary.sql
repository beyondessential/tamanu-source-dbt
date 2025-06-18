select
    registration_date as "{{ translate_label('patientRegistrationDate', 'Registration date') }}",
    count(
        case when sex = 'Male' then 1 end
    ) as "{{ translate_label('patientMaleCount', 'Total patients (male)') }}",
    count(
        case when sex = 'Female' then 1 end
    ) as "{{ translate_label('patientFemaleCount', 'Total patients (female)') }}"
from {{ ref("ds__patients") }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else registration_date::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else registration_date::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
group by registration_date::date

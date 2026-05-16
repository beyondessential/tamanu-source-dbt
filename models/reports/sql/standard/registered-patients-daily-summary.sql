select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_label('patientRegistrationDate') }}",
    count(
        case when sex = 'Male' then 1 end
    ) as "{{ translate_label('patientMaleCount') }}",
    count(
        case when sex = 'Female' then 1 end
    ) as "{{ translate_label('patientFemaleCount') }}"
from {{ ref("ds__patients") }}
where
    registration_date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    registration_date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
group by registration_date

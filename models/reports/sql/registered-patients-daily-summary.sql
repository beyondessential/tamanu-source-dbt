select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientRegistrationDate') }}",
    count(
        case when sex = 'Male' then 1 end
    ) as "{{ translate_label_from_seed('patientMaleCount') }}",
    count(
        case when sex = 'Female' then 1 end
    ) as "{{ translate_label_from_seed('patientFemaleCount') }}"
from {{ ref("ds__patients") }}
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
group by registration_date

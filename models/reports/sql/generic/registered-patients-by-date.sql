select
    to_char(registration_date, '{{ var("date_format") }}') as "{{ translate_string('', 'Registration date') }}",
    count(
        case when sex = 'male' then 1 end
    ) as "{{ translate_string('', 'Males created') }}",
    count(
        case when sex = 'female' then 1 end
    ) as "{{ translate_string('', 'Females created') }}"
from {{ ref("ds__patients") }}
where
        case
            when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
            else registration_date::date >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
        end
        and
        case
            when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
            else registration_date::date <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
        end
group by registration_date::date

select *
from {{ ref("ds__patients_translated") }}
where case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else "Registration date" >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else "Registration date" <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by "Registration date"

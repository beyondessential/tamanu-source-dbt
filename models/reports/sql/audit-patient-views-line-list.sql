select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    date_part('year', age(current_date, date_of_birth))::integer as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    viewed_by_user as "{{ translate_label('logAccessBy', 'Viewed by user') }}",
    user_email as "{{ translate_label('userEmail', 'User email') }}",
    user_role as "{{ translate_label('userRole', 'User role') }}",
    to_char(date_time_viewed, '{{ var("datetime_format") }}') as "{{ translate_label('logAccessDatetime', 'Date and time viewed') }}"
from {{ ref('ds__patient_access_logs') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_time_viewed::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_time_viewed::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('patientId') }} is null then true
        else patient_id = {{ parameter('patientId') }}
    end
    and
    case
        when {{ parameter('userId') }} is null then true
        else viewed_by_user_id = {{ parameter('userId') }}
    end
order by date_time_viewed

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    date_part('year', age(current_date, date_of_birth))::integer as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    viewed_by_user as "{{ translate_label('logAccessBy') }}",
    user_email as "{{ translate_label('userEmail') }}",
    user_role as "{{ translate_label('userRole') }}",
    viewed_at_facility as "{{ translate_label('logAccessAtFacility') }}",
    to_char(date_time_viewed, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('logAccessDatetime') }}"
from {{ ref('ds__patients_access_logs') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else date_time_viewed >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else date_time_viewed <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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

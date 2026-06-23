select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    edited_by_user as "{{ translate_label('logChangeBy') }}",
    user_email as "{{ translate_label('userEmail') }}",
    user_role as "{{ translate_label('userRole') }}",
    to_char({{ to_user_selected_timezone('edited_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('logChangeDateTime') }}"
from {{ ref('ds__patients_change_logs') }}
where
    {{ to_user_selected_timezone('edited_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('edited_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    and
    case
        when {{ parameter('patientId') }} is null then true
        else patient_id = {{ parameter('patientId') }}
    end
    and
    case
        when {{ parameter('userId') }} is null then true
        else edited_by_user = {{ parameter('userId') }}
    end
order by edited_datetime

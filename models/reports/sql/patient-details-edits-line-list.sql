select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    edited_by_user as "{{ translate_label('logChangeBy', 'Edited by user') }}",
    user_email as "{{ translate_label('userEmail', 'User email') }}",
    user_role as "{{ translate_label('userRole', 'User role') }}",
    edited_datetime as "{{ translate_label('logChangeDateTime', 'Date and time edited') }}"
from {{ ref('ds__patient_details_edits') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else edited_datetime::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else edited_datetime::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
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

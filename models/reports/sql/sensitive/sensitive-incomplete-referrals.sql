select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    diagnoses as "{{ translate_label('diagnoses') }}",
    referral_type as "{{ translate_label('referralType') }}",
    referring_doctor_name as "{{ translate_label('referralCompletedBy') }}",
    to_char({{ to_user_selected_timezone('referral_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('referralDate') }}",
    department as "{{ translate_label('department') }}"
from {{ ref('ds__sensitive_referrals') }}
where status in ('pending', 'cancelled')
    and {{ to_user_selected_timezone('referral_datetime') }}
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('referral_datetime') }}
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    and
    case
        when {{ parameter('doctorId') }} is null then true
        else referring_doctor_id = {{ parameter('doctorId') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
order by referral_datetime, last_name, first_name

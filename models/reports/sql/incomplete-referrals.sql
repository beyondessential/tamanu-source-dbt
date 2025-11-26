select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    diagnoses as "{{ translate_label_from_seed('diagnoses') }}",
    referral_type as "{{ translate_label_from_seed('referralType') }}",
    referring_doctor_name as "{{ translate_label_from_seed('referralCompletedBy') }}",
    to_char(referral_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('referralDate') }}",
    department as "{{ translate_label_from_seed('department') }}"
from {{ ref('ds__referrals') }}
where status in ('pending', 'cancelled')
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else referral_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else referral_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
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

select
    display_id as "{{ translate_label('patientDisplayId','Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName','First name') }}",
    last_name as "{{ translate_label('patientLastName','Last name') }}",
    diagnoses as "{{ translate_label('diagnoses', 'Diagnoses') }}",
    referral_type as "{{ translate_label('referralType', 'Referral name') }}",
    referring_doctor_name as "{{ translate_label('referralCompletedBy', 'Referring doctor') }}",
    to_char(referral_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('referralDate', 'Referral date') }}",
    department as "{{ translate_label('department', 'Department') }}"
from {{ ref('ds__referrals') }}
where status in ('pending', 'cancelled')
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else referral_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else referral_datetime::date
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

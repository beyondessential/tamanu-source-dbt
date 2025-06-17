select
    display_id as "{{ translate_string('patientDisplayId','Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName','First name') }}",
    last_name as "{{ translate_string('patientLastName','Last name') }}",
    diagnoses as "{{ translate_string('diagnosisName', 'Diagnoses') }}",
    referral_type as "{{ translate_string('referralType', 'Referral name') }}",
    referring_doctor_name as "{{ translate_string('referralCompletedBy', 'Referring doctor') }}",
    referral_datetime as "{{ translate_string('referralDate', 'Referral date') }}",
    department as "{{ translate_string('departmentName', 'Department') }}"
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

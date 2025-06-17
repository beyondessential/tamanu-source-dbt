select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First Name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last Name') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    conditions as "{{ translate_label('patientNCDConditions', 'NCD') }}",
    test_name as "{{ translate_label('labTestName', 'Lab test') }}",
    requested_datetime::date as "{{ translate_label('labTestLastDate', 'Date of last lab test') }}",
    follow_up_frequency as "{{ translate_label('labTestFollowUpFrequency', 'Required frequency of lab test') }}",
    follow_up_due_date::date as "{{ translate_label('labTestFollowUpDueDate', 'Next lab test due by') }}",
    follow_up_status as "{{ translate_label('labTestFollowUpStatus', 'Status') }}"
from {{ ref('ds__lab_follow_ups') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else follow_up_due_date::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else follow_up_due_date::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case
        when {{ parameter('followUpStatus', default_value='null', data_type='text') }} is null
            then true
        else follow_up_status = {{ parameter('followUpStatus', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('testType', default_value='null', data_type='text') }} is null
            then true
        else test_id = {{ parameter('testType', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('condition', default_value='null', data_type='text') }} is null
            then true
        else conditions ilike '%' || {{ parameter('condition', default_value='null', data_type='text') }} || '%'
    end
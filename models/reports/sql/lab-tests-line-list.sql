select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    facility as "{{ translate_label_from_seed('facility') }}",
    department as "{{ translate_label_from_seed('department') }}",
    requesting_department as "{{ translate_label_from_seed('requestingDepartment') }}",
    concat_ws(', ', location_group, location) as "{{ translate_label_from_seed('location') }}",
    lab_request_id as "{{ translate_label_from_seed('labRequestId') }}",
    status as "{{ translate_label_from_seed('labRequestStatus') }}",
    lab_test_panel as "{{ translate_label_from_seed('labTestPanel') }}",
    lab_test_category as "{{ translate_label_from_seed('labTestCategory') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('labRequestDateTime') }}",
    requested_by as "{{ translate_label_from_seed('labRequestClinician') }}",
    to_char(lab_request_published_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('labRequestPublishedDateTime') }}",
    to_char(lab_test_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('labTestDate') }}",
    result as "{{ translate_label_from_seed('labTestResults') }}",
    verification as "{{ translate_label_from_seed('labTestVerification') }}",
    lab_test_type as "{{ translate_label_from_seed('labTestType') }}",
    to_char(lab_test_completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('labTestCompletedDateTime') }}"
from {{ ref('ds__lab_tests') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else requested_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else requested_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('statusId') }} is null then true
        else status_id = {{ parameter('statusId') }}
    end
    and
    case
        when {{ parameter('testCategoryId') }} is null then true
        else lab_test_category_id = {{ parameter('testCategoryId') }}
    end
order by
    requested_datetime,
    lab_test_panel,
    lab_request_published_datetime,
    lab_test_completed_datetime,
    lab_test_type

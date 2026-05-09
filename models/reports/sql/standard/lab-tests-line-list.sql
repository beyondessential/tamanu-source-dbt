select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    facility as "{{ translate_label('facility') }}",
    department as "{{ translate_label('department') }}",
    requesting_department as "{{ translate_label('requestingDepartment') }}",
    concat_ws(', ', location_group, location) as "{{ translate_label('location') }}",
    lab_request_id as "{{ translate_label('labRequestId') }}",
    status as "{{ translate_label('labRequestStatus') }}",
    lab_test_panel as "{{ translate_label('labTestPanel') }}",
    lab_test_category as "{{ translate_label('labTestCategory') }}",
    to_char({{ to_user_selected_timezone('requested_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestDateTime') }}",
    requested_by as "{{ translate_label('labRequestClinician') }}",
    to_char({{ to_user_selected_timezone('lab_request_published_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestPublishedDateTime') }}",
    to_char(lab_test_date, '{{ var("date_format") }}') as "{{ translate_label('labTestDate') }}",
    result as "{{ translate_label('labTestResults') }}",
    verification as "{{ translate_label('labTestVerification') }}",
    lab_test_type as "{{ translate_label('labTestType') }}",
    to_char({{ to_user_selected_timezone('lab_test_completed_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('labTestCompletedDateTime') }}"
from {{ ref('ds__lab_tests') }}
where {{ to_user_selected_timezone('requested_datetime') }}
        >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('requested_datetime') }}
        <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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

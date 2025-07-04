select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
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
    requested_datetime as "{{ translate_label('labRequestDateTime') }}",
    requested_by as "{{ translate_label('labRequestClinician') }}",
    lab_request_published_datetime as "{{ translate_label('labRequestPublishedDateTime') }}",
    lab_test_date as "{{ translate_label('labTestDate') }}",
    result as "{{ translate_label('labTestResults') }}",
    verification as "{{ translate_label('labTestVerification') }}",
    lab_test_type as "{{ translate_label('labTestType') }}",
    lab_test_completed_datetime as "{{ translate_label('labTestCompletedDateTime') }}"
from {{ ref('ds__lab_tests') }}
where is_sensitive
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else requested_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else requested_datetime::date
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

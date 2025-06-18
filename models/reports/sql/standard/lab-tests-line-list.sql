select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    facility as "{{ translate_label('facility', 'Facility') }}",
    department as "{{ translate_label('department', 'Department') }}",
    requesting_department as "{{ translate_label('requestingDepartment', 'Requesting department') }}",
    concat_ws(', ', location_group, location) as "{{ translate_label('location', 'Location') }}",
    lab_request_id as "{{ translate_label('labRequestId', 'Request ID') }}",
    status as "{{ translate_label('labRequestStatus', 'Status') }}",
    lab_test_panel as "{{ translate_label('labTestPanel', 'Lab test panel') }}",
    lab_test_category as "{{ translate_label('labTestCategory', 'Test category') }}",
    requested_datetime as "{{ translate_label('labRequestDateTime', 'Lab request date and time') }}",
    requested_by as "{{ translate_label('labRequestClinician', 'Requesting clinician') }}",
    lab_request_published_datetime as "{{ translate_label('labRequestPublishedDateTime', 'Lab request published date and time') }}",
    lab_test_date as "{{ translate_label('labTestDate', 'Lab test date') }}",
    result as "{{ translate_label('labTestResults', 'Result') }}",
    verification as "{{ translate_label('labTestVerification', 'Verification') }}",
    lab_test_type as "{{ translate_label('labTestType', 'Lab test type') }}",
    lab_test_completed_datetime as "{{ translate_label('labTestCompletedDateTime', 'Lab test completed date and time') }}"
from {{ ref('ds__lab_tests') }}
where
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

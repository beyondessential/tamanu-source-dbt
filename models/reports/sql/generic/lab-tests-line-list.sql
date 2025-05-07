select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    facility as "{{ translate_string('facilityName', 'Facility') }}",
    department as "{{ translate_string('departmentName', 'Department') }}",
    concat_ws(', ', location_group, location) as "{{ translate_string('locationName', 'Location') }}",
    lab_request_id as "{{ translate_string('labRequestId', 'Lab request ID') }}",
    status as "{{ translate_string('labRequestStatus', 'Status') }}",
    lab_test_panel as "{{ translate_string('labTestPanel', 'Lab test panel') }}",
    lab_test_category as "{{ translate_string('labTestCategory', 'Lab test category') }}",
    requested_datetime as "{{ translate_string('labRequestDateAndTime', 'Lab request date and time') }}",
    requested_by as "{{ translate_string('labRequestClinician', 'Requesting clinician') }}",
    lab_request_published_datetime as "{{ translate_string('labRequestPublishedDateTime', 'Lab request published date and time') }}",
    lab_test_date as "{{ translate_string('labTestDate', 'Lab test date') }}",
    result as "{{ translate_string('labTestResults', 'Result') }}",
    lab_test_type as "{{ translate_string('labTestType', 'Lab test type') }}",
    lab_test_completed_datetime as "{{ translate_string('labTestCompletedDateTime', 'Lab test completed date and time') }}"
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

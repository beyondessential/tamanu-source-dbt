select
    display_id as "{{ translate_string('report.reporting.displayId.label','Patient ID') }}",
    first_name as "{{ translate_string('report.reporting.firstName.label','First name') }}",
    last_name as "{{ translate_string('report.reporting.lastName.label','Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('report.reporting.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('report.reporting.age.label', 'Age') }}",
    sex as "{{ translate_string('report.reporting.sex.label', 'Sex') }}",
    village as "{{ translate_string('report.reporting.village.label', 'Village') }}",
    facility as "{{ translate_string('report.reporting.facility.label', 'Facility') }}",
    department as "{{ translate_string('report.reporting.department.label', 'Department') }}",
    concat_ws(', ', location_group, location) as "{{ translate_string('report.reporting.location.label', 'Location') }}",
    lab_request_id as "{{ translate_string('report.reporting.labRequestId.label', 'Lab request ID') }}",
    status as "{{ translate_string('report.reporting.status.label', 'Status') }}",
    lab_test_panel as "{{ translate_string('report.reporting.labTestPanel.label', 'Lab test panel') }}",
    lab_test_category as "{{ translate_string('report.reporting.labTestCategory.label', 'Lab test category') }}",
    to_char(requested_datetime, '{{ var("date_format") }}') as "{{ translate_string('report.reporting.labRequestDateAndTime.label', 'Lab request date and time') }}",
    requested_by as "{{ translate_string('report.reporting.requestingClinician.label', 'Requesting clinician') }}",
    lab_request_published_datetime as "{{ translate_string('report.reporting.labRequestPublishedDateAndTime.label', 'Lab request published date and time') }}",
    lab_test_date as "{{ translate_string('report.reporting.labTestDate.label', 'Lab test date') }}",
    result as "{{ translate_string('report.reporting.result.label', 'Result') }}",
    lab_test_type as"{{ translate_string('report.reporting.labTestType.label', 'Lab test type') }}",
    lab_test_completed_datetime as "{{ translate_string('report.reporting.labTestCompletedDateAndTime', 'Lab test completed date and time') }}"
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
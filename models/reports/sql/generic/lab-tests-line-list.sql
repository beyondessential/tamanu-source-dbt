select
    display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label','First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label','Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.table.column.age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    concat_ws(', ', location_group, location) as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    lab_request_id as "{{ translate_string('general.localisedField.requestId.label', 'Request ID') }}",
    status as "{{ translate_string('lab.table.column.status', 'Status') }}",
    lab_test_panel as "{{ translate_string('lab.testSelect.panel.label', 'Panel') }}",
    lab_test_category as "{{ translate_string('lab.testSelect.testCategory.label', 'Test category') }}",
    to_char(requested_datetime, '{{ var("date_format") }}') as "{{ translate_string('lab.table.column.requestedDate', 'Request date and time') }}",
    requested_by as "{{ translate_string('general.localisedField.requestedById.label', 'Requesting clinician') }}",
    lab_request_published_datetime as "{{ translate_string('', 'Published date and time') }}",
    lab_test_date as "{{ translate_string('', 'Lab test date') }}",
    result as "{{ translate_string('lab.results.table.column.result', 'Result') }}",
    lab_test_type as"{{ translate_string('lab.testType.label', 'Lab test type') }}",
    lab_test_completed_datetime as "{{ translate_string('lab.results.table.column.completedDate', 'Completed date and time') }}"
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
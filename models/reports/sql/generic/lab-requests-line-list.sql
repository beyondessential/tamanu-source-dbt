select
    display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label','First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label','Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    concat_ws(', ', location_group, location) as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    laboratory as "{{ translate_string('general.localisedField.laboratory.label', 'Laboratory') }}",
    request_id as "{{ translate_string('general.localisedField.requestId.label', 'Request ID') }}",
    status as "{{ translate_string('lab.table.column.status', 'Status') }}",
    to_char(requested_datetime, '{{ var("date_format") }}') as "{{ translate_string('lab.requestDateTime.label', 'Request date and time') }}",
    clinician as "{{ translate_string('general.localisedField.requestedById.label', 'Requesting clinician') }}",
    requesting_department as "{{ translate_string('', 'Requesting department') }}",
    priority as "{{ translate_string('general.localisedField.priority.label', 'Priority') }}",
    category as "{{ translate_string('lab.testSelect.testCategory.label', 'Test category') }}",
    tests as "{{ translate_string('', 'Test requested') }}",
    to_char(
        collected_datetime, '{{ var("date_format") }}'
    ) as "{{ translate_string('lab.sampleDetail.table.column.collectionDateTime', 'Sample collection date and time') }}",
    collected_by as "{{ translate_string('lab.sampleDetail.table.column.collectedBy', 'Sample collected by') }}",
    specimen_type as "{{ translate_string('refData.labTestType.labTestType-Specimentype', 'Specimen type') }}",
    site as "{{ translate_string('refData.labTestType.labTestType-Siteofcollection-Specimen', 'Site') }}",
    to_char(completed_datetime, '{{ var("date_format") }}') as "{{ translate_string('', 'Completed date and time') }}",
    reason_for_cancellation as "{{ translate_string('', 'Reason for cancellation') }}"
from {{ ref('ds__lab_requests') }}
where
    case
        when {{ parameter('requestedById') }} is null then true
        else requested_by_id = {{ parameter('requestedById') }}
    end
    and
    case
        when {{ parameter('testCategoryId') }} is null then true
        else category_id = {{ parameter('testCategoryId') }}
    end
    and
    case
        when {{ parameter('statusId') }} is null then true
        else status_id = {{ parameter('statusId') }}
    end
    and
    case
        when{{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else requested_datetime::date
            >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when{{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else requested_datetime::date
            <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end

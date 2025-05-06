select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    facility as "{{ translate_string('facilityName', 'Facility') }}",
    department as "{{ translate_string('departmentName', 'Department') }}",
    concat_ws(', ', location_group, location) as "{{ translate_string('locationName', 'Location') }}",
    laboratory as "{{ translate_string('labLaboratory', 'Laboratory') }}",
    request_id as "{{ translate_string('labRequestId', 'Request ID') }}",
    status as "{{ translate_string('labRequestStatus', 'Status') }}",
    to_char(requested_datetime, '{{ var("date_format") }}') as "{{ translate_string('labRequestDateTime', 'Request date and time') }}",
    clinician as "{{ translate_string('labRequestClinician', 'Requesting clinician') }}",
    requesting_department as "{{ translate_string('labRequestDepartment', 'Requesting department') }}",
    priority as "{{ translate_string('labRequestPriority', 'Priority') }}",
    category as "{{ translate_string('labTestCategory', 'Test category') }}",
    sensitive_tests as "{{ translate_string('labTestResults', 'Test requested') }}",
    to_char(
        collected_datetime, '{{ var("date_format") }}'
    ) as "{{ translate_string('labRequestSampleDateTime', 'Sample collection date and time') }}",
    collected_by as "{{ translate_string('labRequestSampleCollectedBy', 'Sample collected by') }}",
    specimen_type as "{{ translate_string('labRequestSpecimenType', 'Specimen type') }}",
    site as "{{ translate_string('labRequestSampleSite', 'Site') }}",
    to_char(sensitive_completed_datetime, '{{ var("date_format") }}') as "{{ translate_string('labRequestCompletedDateTime', 'Completed date and time') }}",
    reason_for_cancellation as "{{ translate_string('labRequestCancellationReason', 'Reason for cancellation') }}"
from {{ ref('ds__lab_requests') }}
where sensitive_tests is not null
    and
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

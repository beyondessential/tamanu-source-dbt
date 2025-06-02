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
    concat_ws(', ', location_group, location) as "{{ translate_label('location', 'Location') }}",
    laboratory as "{{ translate_label('labLaboratory', 'Laboratory') }}",
    request_id as "{{ translate_label('labRequestId', 'Request ID') }}",
    status as "{{ translate_label('labRequestStatus', 'Status') }}",
    requested_datetime as "{{ translate_label('labRequestDateTime', 'Lab request date and time') }}",
    clinician as "{{ translate_label('labRequestClinician', 'Requesting clinician') }}",
    requesting_department as "{{ translate_label('labRequestDepartment', 'Requesting department') }}",
    priority as "{{ translate_label('labRequestPriority', 'Priority') }}",
    category as "{{ translate_label('labTestCategory', 'Test category') }}",
    sensitive_tests as "{{ translate_label('labTestRequested', 'Test requested') }}",
    collected_datetime as "{{ translate_label('labRequestSampleCollectionDateTime', 'Sample collection date and time') }}",
    collected_by as "{{ translate_label('labRequestSampleCollectedBy', 'Sample collected by') }}",
    specimen_type as "{{ translate_label('labRequestSpecimenType', 'Specimen type') }}",
    site as "{{ translate_label('labRequestSampleSite', 'Site') }}",
    sensitive_completed_datetime as "{{ translate_label('labRequestCompletedDateTime', 'Completed date and time') }}",
    reason_for_cancellation as "{{ translate_label('labRequestCancellationReason', 'Reason for cancellation') }}"
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

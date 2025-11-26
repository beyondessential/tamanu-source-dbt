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
    concat_ws(', ', location_group, location) as "{{ translate_label_from_seed('location') }}",
    laboratory as "{{ translate_label_from_seed('labLaboratory') }}",
    request_id as "{{ translate_label_from_seed('labRequestId') }}",
    status as "{{ translate_label_from_seed('labRequestStatus') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('labRequestDateTime') }}",
    requested_by as "{{ translate_label_from_seed('labRequestClinician') }}",
    requesting_department as "{{ translate_label_from_seed('labRequestDepartment') }}",
    priority as "{{ translate_label_from_seed('labRequestPriority') }}",
    lab_test_category as "{{ translate_label_from_seed('labTestCategory') }}",
    tests as "{{ translate_label_from_seed('labTestRequested') }}",
    to_char(collected_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('labRequestSampleCollectionDateTime') }}",
    collected_by as "{{ translate_label_from_seed('labRequestSampleCollectedBy') }}",
    specimen_type as "{{ translate_label_from_seed('labRequestSpecimenType') }}",
    site as "{{ translate_label_from_seed('labRequestSampleSite') }}",
    to_char(completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('labRequestCompletedDateTime') }}",
    reason_for_cancellation as "{{ translate_label_from_seed('labRequestCancellationReason') }}"
from {{ ref('ds__lab_requests') }}
where case
        when {{ parameter('requestedById') }} is null then true
        else requested_by_id = {{ parameter('requestedById') }}
    end
    and
    case
        when {{ parameter('testCategoryId') }} is null then true
        else lab_test_category_id = {{ parameter('testCategoryId') }}
    end
    and
    case
        when {{ parameter('statusId') }} is null then true
        else status_id = {{ parameter('statusId') }}
    end
    and
    case
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
order by requested_datetime, last_name, first_name, tests

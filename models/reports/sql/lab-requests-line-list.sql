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
    concat_ws(', ', location_group, location) as "{{ translate_label('location') }}",
    laboratory as "{{ translate_label('labLaboratory') }}",
    request_id as "{{ translate_label('labRequestId') }}",
    status as "{{ translate_label('labRequestStatus') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestDateTime') }}",
    clinician as "{{ translate_label('labRequestClinician') }}",
    requesting_department as "{{ translate_label('labRequestDepartment') }}",
    priority as "{{ translate_label('labRequestPriority') }}",
    category as "{{ translate_label('labTestCategory') }}",
    non_sensitive_tests as "{{ translate_label('labTestRequested') }}",
    to_char(collected_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestSampleCollectionDateTime') }}",
    collected_by as "{{ translate_label('labRequestSampleCollectedBy') }}",
    specimen_type as "{{ translate_label('labRequestSpecimenType') }}",
    site as "{{ translate_label('labRequestSampleSite') }}",
    to_char(non_sensitive_completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestCompletedDateTime') }}",
    reason_for_cancellation as "{{ translate_label('labRequestCancellationReason') }}"
from {{ ref('ds__lab_requests') }}
where non_sensitive_tests is not null
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
order by requested_datetime

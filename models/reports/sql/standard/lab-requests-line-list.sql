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
    to_char({{ to_user_selected_timezone('requested_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestDateTime') }}",
    requested_by as "{{ translate_label('labRequestClinician') }}",
    requesting_department as "{{ translate_label('labRequestDepartment') }}",
    priority as "{{ translate_label('labRequestPriority') }}",
    lab_test_category as "{{ translate_label('labTestCategory') }}",
    tests as "{{ translate_label('labTestRequested') }}",
    to_char({{ to_user_selected_timezone('collected_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestSampleCollectionDateTime') }}",
    collected_by as "{{ translate_label('labRequestSampleCollectedBy') }}",
    specimen_type as "{{ translate_label('labRequestSpecimenType') }}",
    site as "{{ translate_label('labRequestSampleSite') }}",
    to_char({{ to_user_selected_timezone('completed_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('labRequestCompletedDateTime') }}",
    reason_for_cancellation as "{{ translate_label('labRequestCancellationReason') }}"
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
    {{ to_user_selected_timezone('requested_datetime') }}
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('requested_datetime') }}
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
order by requested_datetime, last_name, first_name, tests

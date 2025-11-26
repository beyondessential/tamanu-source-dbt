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
    location_group as "{{ translate_label_from_seed('locationGroup') }}",
    request_id as "{{ translate_label_from_seed('imagingRequestId') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('imagingRequestDateTime') }}",
    supervising_clinician as "{{ translate_label_from_seed('imagingSupervisingClinician') }}",
    requesting_clinician as "{{ translate_label_from_seed('imagingRequestingClinician') }}",
    priority as "{{ translate_label_from_seed('imagingPriority') }}",
    imaging_type as "{{ translate_label_from_seed('imagingType') }}",
    imaging_area as "{{ translate_label_from_seed('imagingArea') }}",
    status as "{{ translate_label_from_seed('imagingStatus') }}",
    to_char(completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('imagingCompletedDateTime') }}",
    reason_for_cancellation as "{{ translate_label_from_seed('imagingCancellationReason') }}"
from {{ ref('ds__imaging_requests') }}
where case
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
    and
    case
        when {{ parameter('requestedById') }} is null then true
        else requesting_clinician_id = {{ parameter('requestedById') }}
    end
    and
    case
        when {{ parameter('imagingType') }} is null then true
        else imaging_type_id = {{ parameter('imagingType') }}
    end
    and
    case
        when {{ parameter('statusId') }} is null then true
        else status_id = {{ parameter('statusId') }}
    end
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
order by requested_datetime

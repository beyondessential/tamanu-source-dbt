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
    location_group as "{{ translate_label('locationGroup') }}",
    request_id as "{{ translate_label('imagingRequestId') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('imagingRequestDateTime') }}",
    supervising_clinician as "{{ translate_label('imagingSupervisingClinician') }}",
    requesting_clinician as "{{ translate_label('imagingRequestingClinician') }}",
    priority as "{{ translate_label('imagingPriority') }}",
    imaging_type as "{{ translate_label('imagingType') }}",
    imaging_area as "{{ translate_label('imagingArea') }}",
    status as "{{ translate_label('imagingStatus') }}",
    to_char(completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('imagingCompletedDateTime') }}",
    reason_for_cancellation as "{{ translate_label('imagingCancellationReason') }}"
from {{ ref('ds__sensitive_imaging_requests') }}
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

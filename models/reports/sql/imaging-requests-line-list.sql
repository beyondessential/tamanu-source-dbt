select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    facility as "{{ translate_label('facility') }}",
    department as "{{ translate_label('department') }}",
    location_group as "{{ translate_label('locationGroup') }}",
    request_id as "{{ translate_label('imagingRequestId') }}",
    requested_datetime as "{{ translate_label('imagingRequestDateTime') }}",
    supervising_clinician as "{{ translate_label('imagingSupervisingClinician') }}",
    requesting_clinician as "{{ translate_label('imagingRequestingClinician') }}",
    priority as "{{ translate_label('imagingPriority') }}",
    imaging_type as "{{ translate_label('imagingType') }}",
    imaging_area as "{{ translate_label('imagingArea') }}",
    status as "{{ translate_label('imagingStatus') }}",
    completed_datetime as "{{ translate_label('imagingCompletedDateTime') }}",
    reason_for_cancellation as "{{ translate_label('imagingCancellationReason') }}"
from {{ ref('ds__imaging_requests') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }} is null then true
        else requested_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }} is null then true
        else requested_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
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

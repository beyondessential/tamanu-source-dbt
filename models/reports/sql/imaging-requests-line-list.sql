select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    facility as "{{ translate_label('facility', 'Facility') }}",
    department as "{{ translate_label('department', 'Department') }}",
    location_group as "{{ translate_label('locationGroup', 'Area') }}",
    request_id as "{{ translate_label('imagingRequestId', 'Request ID') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('imagingRequestDateTime', 'Request date and time') }}",
    supervising_clinician as "{{ translate_label('imagingSupervisingClinician', 'Supervising clinician') }}",
    requesting_clinician as "{{ translate_label('imagingRequestingClinician', 'Requesting clinician') }}",
    priority as "{{ translate_label('imagingPriority', 'Priority') }}",
    imaging_type as "{{ translate_label('imagingType', 'Imaging type') }}",
    imaging_area as "{{ translate_label('imagingArea', 'Area to be imaged') }}",
    status as "{{ translate_label('imagingStatus', 'Status') }}",
    to_char(completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('imagingCompletedDateTime', 'Completed date and time') }}",
    reason_for_cancellation as "{{ translate_label('imagingCancellationReason', 'Reason for cancellation') }}"
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
order by requested_datetime

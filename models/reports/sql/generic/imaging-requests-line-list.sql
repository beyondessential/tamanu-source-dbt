select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('patientDob', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    facility as "{{ translate_string('patientFacility', 'Facility') }}",
    department as "{{ translate_string('patientDepartment', 'Department') }}",
    location_group as "{{ translate_string('patientArea', 'Area') }}",
    request_id as "{{ translate_string('imagingRequestId', 'Request ID') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('imagingRequestedDate', 'Request date and time') }}",
    supervising_clinician as "{{ translate_string('supervisingClinician', 'Supervising clinician') }}",
    requesting_clinician as "{{ translate_string('requestingClinician', 'Requesting clinician') }}",
    priority as "{{ translate_string('imagingPriority', 'Priority') }}",
    imaging_type as "{{ translate_string('imagingType', 'Imaging type') }}",
    imaging_area as "{{ translate_string('imagingArea', 'Area to be imaged') }}",
    status as "{{ translate_string('imagingStatus', 'Status') }}",
    to_char(completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('imagingCompletedDate', 'Completed date and time') }}",
    reason_for_cancellation as "{{ translate_string('imagingCancellationReason', 'Reason for cancellation') }}"
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

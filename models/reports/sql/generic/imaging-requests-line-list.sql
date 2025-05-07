select
    display_id as "{{ translate_string('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_string('patientFirstName', 'First name') }}",
    last_name as "{{ translate_string('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_string('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_string('patientAge', 'Age') }}",
    sex as "{{ translate_string('patientSex', 'Sex') }}",
    village as "{{ translate_string('patientVillage', 'Village') }}",
    facility as "{{ translate_string('facilityName', 'Facility') }}",
    department as "{{ translate_string('departmentName', 'Department') }}",
    location_group as "{{ translate_string('locationGroupName', 'Area') }}",
    request_id as "{{ translate_string('imagingRequestId', 'Request ID') }}",
    requested_datetime as "{{ translate_string('imagingRequestDatetime', 'Request date and time') }}",
    supervising_clinician as "{{ translate_string('imagingSupervisingClinician', 'Supervising clinician') }}",
    requesting_clinician as "{{ translate_string('imagingRequestingClinician', 'Requesting clinician') }}",
    priority as "{{ translate_string('imagingPriority', 'Priority') }}",
    imaging_type as "{{ translate_string('imagingType', 'Imaging type') }}",
    imaging_area as "{{ translate_string('imagingArea', 'Area to be imaged') }}",
    status as "{{ translate_string('imagingStatus', 'Status') }}",
    completed_datetime as "{{ translate_string('imagingCompletedDateTime', 'Completed date and time') }}",
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

select
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    location_group as "{{ translate_string('general.localisedField.area.label', 'Area') }}",
    request_id as "{{ translate_string('general.localisedField.requestId.label', 'Request ID') }}",
    to_char(requested_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('imaging.requestedDate.label', 'Request date and time') }}",
    supervising_clinician as "{{ translate_string('general.supervisingClinician.label', 'Supervising clinician') }}",
    requesting_clinician as "{{ translate_string('general.requestingClinician.label', 'Requesting clinician') }}",
    priority as "{{ translate_string('general.localisedField.priority.label', 'Priority') }}",
    imaging_type as "{{ translate_string('imaging.imagingType.label', 'Imaging type') }}",
    imaging_area as "{{ translate_string('', 'Area to be imaged') }}",
    status as "{{ translate_string('general.localisedField.status.label', 'Status') }}",
    to_char(completed_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('imaging.completedDate.label', 'Completed date and time') }}",
    reason_for_cancellation as "{{ translate_string('imaging.modal.cancel.reason.label', 'Reason for cancellation') }}"
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
        when{{ parameter('requestedById') }} is null then true
        else requesting_clinician_id ={{ parameter('requestedById') }}
    end
    and
    case
        when{{ parameter('imagingType') }} is null then true
        else imaging_type_id ={{ parameter('imagingType') }}
    end
    and
    case
        when{{ parameter('statusId') }} is null then true
        else status_id ={{ parameter('statusId') }}
    end
    and
    case
        when{{ parameter('facilityId') }} is null then true
        else facility_id ={{ parameter('facilityId') }}
    end

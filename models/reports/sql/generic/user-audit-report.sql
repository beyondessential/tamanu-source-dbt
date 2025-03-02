select
    user_name as "{{ translate_string('', 'User name') }}",
    user_role as "{{ translate_string('', 'User role') }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    patient_category as "{{ translate_string('general.localisedField.patientBillingTypeId.label', 'Patient category') }}",
    triage_category as "{{ translate_string('', 'Triage category') }}",
    facility as "{{ translate_string('general.localisedField.facility.label', 'Facility') }}",
    department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    location_group as "{{ translate_string('general.localisedField.area.label', 'Area') }}",
    location as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    to_char(encounter_start_datetime, '{{ var("date_format") }}') as "{{ translate_string('', 'Encounter start date') }}",
    to_char(encounter_end_datetime, '{{ var("date_format") }}') as "{{ translate_string('', 'Encounter end date') }}",
    to_char(encounter_start_datetime, '{{ var("time_format") }}') as "{{ translate_string('', 'Encounter start time') }}",
    to_char(first_note_datetime, '{{ var("time_format") }}') as "{{ translate_string('', 'Notes start time') }}",
    to_char(last_note_datetime, '{{ var("time_format") }}') as "{{ translate_string('', 'Notes end time') }}",
    is_discharged as "{{ translate_string('', 'Discharges (has the patient been discharged)') }}",
    non_discharge_by_clinicians as "{{ translate_string('', 'Non-discharge by clinicians') }}"
from {{ ref('ds__user_audit') }}
where case
        when {{ parameter('departmentId') }} is null then true
        else department_id ={{ parameter('departmentId') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id ={{ parameter('locationGroupId') }}
    end

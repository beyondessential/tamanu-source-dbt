select
    user_name as "{{ translate_string('userName', 'User name') }}",
    user_role as "{{ translate_string('userRole', 'User role') }}",
    display_id as "{{ translate_string('patientDisplayId','Patient ID') }}",
    patient_category as "{{ translate_string('patientCategory', 'Patient category') }}",
    triage_category as "{{ translate_string('triageCategory', 'Triage category') }}",
    facility as "{{ translate_string('facilityName', 'Facility') }}",
    department as "{{ translate_string('departmentName', 'Department') }}",
    location_group as "{{ translate_string('locationGroupName', 'Area') }}",
    location as "{{ translate_string('locationName', 'Location') }}",
    encounter_start_datetime as "{{ translate_string('encounterStartDate', 'Encounter start date and time') }}",
    encounter_end_datetime as "{{ translate_string('encounterEndDate', 'Encounter end date and time') }}",
    first_note_datetime as "{{ translate_string('noteStartTime', 'Notes start date and time') }}",
    last_note_datetime as "{{ translate_string('noteEndTime', 'Notes end date and time') }}",
    is_discharged as "{{ translate_string('encounterIsDischarged', 'Discharges (has the patient been discharged)') }}",
    non_discharge_by_clinicians as "{{ translate_string('encounterNonDischargeClinician', 'Non-discharge by clinicians') }}"
from {{ ref('ds__user_audit') }}
where
    case
        when {{ parameter('departmentId') }} is null then true
        else department_id = {{ parameter('departmentId') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id = {{ parameter('locationGroupId') }}
    end

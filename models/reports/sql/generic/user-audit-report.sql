select
    user_name as "{{ translate_string('userName', 'User name') }}",
    user_role as "{{ translate_string('userRole', 'User role') }}",
    display_id as "{{ translate_string('patientDisplayId','Patient ID') }}",
    patient_category as "{{ translate_string('patientCategory', 'Patient category') }}",
    triage_category as "{{ translate_string('triageCategory', 'Triage category') }}",
    facility as "{{ translate_string('facilityName', 'Facility') }}",
    department as "{{ translate_string('departmentName', 'Department') }}",
    location_group as "{{ translate_string('areaName', 'Area') }}",
    location as "{{ translate_string('locationName', 'Location') }}",
    to_char(encounter_start_datetime, '{{ var("date_format") }}') as "{{ translate_string('encounterStartDate', 'Encounter start date') }}",
    to_char(encounter_end_datetime, '{{ var("date_format") }}') as "{{ translate_string('encounterEndDate', 'Encounter end date') }}",
    to_char(encounter_start_datetime, '{{ var("time_format") }}') as "{{ translate_string('encounterStartTime', 'Encounter start time') }}",
    to_char(first_note_datetime, '{{ var("time_format") }}') as "{{ translate_string('noteStartTime', 'Notes start time') }}",
    to_char(last_note_datetime, '{{ var("time_format") }}') as "{{ translate_string('noteEndTime', 'Notes end time') }}",
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

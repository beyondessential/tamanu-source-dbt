select
    user_name as "{{ translate_label('userName', 'User name') }}",
    user_role as "{{ translate_label('userRole', 'User role') }}",
    display_id as "{{ translate_label('patientDisplayId','Patient ID') }}",
    patient_category as "{{ translate_label('patientCategory', 'Patient category') }}",
    triage_category as "{{ translate_label('triageCategory', 'Triage category') }}",
    facility as "{{ translate_label('facility', 'Facility') }}",
    department as "{{ translate_label('department', 'Department') }}",
    location_group as "{{ translate_label('locationGroup', 'Area') }}",
    location as "{{ translate_label('location', 'Location') }}",
    encounter_start_datetime as "{{ translate_label('encounterStartDateTime', 'Encounter start date and time') }}",
    encounter_end_datetime as "{{ translate_label('encounterEndDateTime', 'Encounter end date and time') }}",
    first_note_datetime as "{{ translate_label('noteStartDateTime', 'Notes start date and time') }}",
    last_note_datetime as "{{ translate_label('noteEndDateTime', 'Notes end date and time') }}",
    is_discharged as "{{ translate_label('encounterIsDischarged', 'Discharges (has the patient been discharged)') }}",
    non_discharge_by_clinicians as "{{ translate_label('encounterNonDischargeClinician', 'Non-discharge by clinicians') }}"
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
order by encounter_start_datetime

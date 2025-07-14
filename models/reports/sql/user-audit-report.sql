select
    user_name as "{{ translate_label('userName') }}",
    user_role as "{{ translate_label('userRole') }}",
    display_id as "{{ translate_label('patientDisplayId') }}",
    patient_category as "{{ translate_label('patientCategory') }}",
    triage_category as "{{ translate_label('triageCategory') }}",
    facility as "{{ translate_label('facility') }}",
    department as "{{ translate_label('department') }}",
    location_group as "{{ translate_label('locationGroup') }}",
    location as "{{ translate_label('location') }}",
    encounter_start_datetime as "{{ translate_label('encounterStartDateTime') }}",
    encounter_end_datetime as "{{ translate_label('encounterEndDateTime') }}",
    first_note_datetime as "{{ translate_label('noteStartDateTime') }}",
    last_note_datetime as "{{ translate_label('noteEndDateTime') }}",
    is_discharged as "{{ translate_label('encounterIsDischarged') }}",
    non_discharge_by_clinicians as "{{ translate_label('encounterNonDischargeClinician') }}"
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

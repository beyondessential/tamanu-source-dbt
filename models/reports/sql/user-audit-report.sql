select
    user_name as "{{ translate_label_from_seed('userName') }}",
    user_role as "{{ translate_label_from_seed('userRole') }}",
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    patient_category as "{{ translate_label_from_seed('patientCategory') }}",
    triage_category as "{{ translate_label_from_seed('triageCategory') }}",
    facility as "{{ translate_label_from_seed('facility') }}",
    department as "{{ translate_label_from_seed('department') }}",
    location_group as "{{ translate_label_from_seed('locationGroup') }}",
    location as "{{ translate_label_from_seed('location') }}",
    to_char(encounter_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('encounterStartDateTime') }}",
    to_char(encounter_end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('encounterEndDateTime') }}",
    to_char(first_note_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('noteStartDateTime') }}",
    to_char(last_note_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('noteEndDateTime') }}",
    is_discharged as "{{ translate_label_from_seed('encounterIsDischarged') }}",
    non_discharge_by_clinicians as "{{ translate_label_from_seed('encounterNonDischargeClinician') }}"
from {{ ref('ds__user_audit') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else encounter_start_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else encounter_start_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
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

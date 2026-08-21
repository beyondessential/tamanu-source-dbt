{% macro audit_discharge_line_list_report(is_sensitive=false) %}

{% set dataset = 'ds__sensitive_discharge_audit' if is_sensitive else 'ds__discharge_audit' %}

-- Discharge Audit Line List
-- One row per discharged encounter, filtered on when the discharge was recorded in
-- Tamanu rather than the discharge date entered on the form.

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    {{ translate_column_value('ENCOUNTER_TYPE_LABELS', 'encounter_type') }} as "{{ translate_label('encounterType') }}",
    facility as "{{ translate_label('facility') }}",
    department as "{{ translate_label('department') }}",
    location as "{{ translate_label('location') }}",
    to_char({{ to_user_selected_timezone('admission_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char({{ to_user_selected_timezone('discharge_datetime_entered') }}, '{{ var("datetime_format") }}') as "{{ translate_label('dischargeDateTime') }}",
    to_char({{ to_user_selected_timezone('discharge_recorded_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('dischargeRecordedDateTime') }}",
    days_between_discharge_and_recording as "{{ translate_label('dischargeRecordingDelayDays') }}",
    discharge_disposition as "{{ translate_label('dischargeDisposition') }}",
    discharger_on_form as "{{ translate_label('dischargeClinician') }}",
    recorded_by_user as "{{ translate_label('dischargeRecordedBy') }}",
    case when is_auto_discharge then 'Yes' else 'No' end as "{{ translate_label('dischargeIsAutomatic') }}",
    later_edit_count as "{{ translate_label('dischargeLaterEditCount') }}",
    primary_diagnoses as "{{ translate_label('diagnosesPrimary') }}",
    primary_diagnoses_codes as "{{ translate_label('diagnosesPrimaryCodes') }}",
    secondary_diagnoses as "{{ translate_label('diagnosesSecondary') }}",
    secondary_diagnoses_codes as "{{ translate_label('diagnosesSecondaryCodes') }}"
from {{ ref(dataset) }}
where
    -- BL-007: the date range filters on when the discharge was recorded, not on the
    -- discharge date entered on the form
    {{ to_user_selected_timezone('discharge_recorded_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    -- the whole of toDate is in scope, because the recorded time of day matters here
    and {{ to_user_selected_timezone('discharge_recorded_datetime') }} < ({{ parameter('toDate', default_value='2024-01-31', data_type='date') }})::date + interval '1 day'
    and case when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case when {{ parameter('departmentId') }} is null then true
        else department_id = {{ parameter('departmentId') }}
    end
    and case when coalesce({{ parameter('encounterType') }}) is null then true
        else encounter_type in ({{ parameter('encounterType') }})
    end
    and case when {{ parameter('dischargeType') }} is null then true
        when {{ parameter('dischargeType') }} = 'automatic' then is_auto_discharge
        else not is_auto_discharge
    end
order by discharge_recorded_datetime desc, display_id

{% endmacro %}

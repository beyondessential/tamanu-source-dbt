{% macro emergency_triage_line_list_report(is_sensitive=false) %}

{%- set dataset = 'ds__sensitive_emergency_triage' if is_sensitive else 'ds__emergency_triage' -%}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    age as "{{ translate_label('patientAge') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    to_char(
        {{ to_user_selected_timezone('triage_datetime') }}, '{{ var("datetime_without_seconds_format") }}'
    ) as "{{ translate_label('triageDateTime') }}",
    triage_category as "{{ translate_label('triageCategory') }}",
    arrival_mode as "{{ translate_label('triageArrivalMode') }}",
    chief_complaint as "{{ translate_label('triageChiefComplaint') }}",
    secondary_complaint as "{{ translate_label('triageSecondaryComplaint') }}",
    diagnoses as "{{ translate_label('diagnoses') }}",
    medications as "{{ translate_label('medications') }}",
    to_char(
        {{ to_user_selected_timezone('active_care_datetime') }}, '{{ var("datetime_without_seconds_format") }}'
    ) as "{{ translate_label('triageActiveCareDateTime') }}",
    {{ duration_hms('triage_datetime', 'active_care_datetime') }}
        as "{{ translate_label('triageWaitingTimeToActiveCare') }}",
    target_time_met as "{{ translate_label('triageTargetTimeMet') }}",
    ed_outcome as "{{ translate_label('triageEdOutcome') }}",
    discharge_disposition as "{{ translate_label('dischargeDisposition') }}",
    to_char(
        {{ to_user_selected_timezone('discharge_datetime') }}, '{{ var("datetime_without_seconds_format") }}'
    ) as "{{ translate_label('dischargeDateTime') }}",
    {{ duration_hms('triage_datetime', 'discharge_datetime') }}
        as "{{ translate_label('triageTotalLengthOfStay') }}"
from {{ ref(dataset) }}
where
    -- BL-011: the facility and department the patient was triaged in are selectable, and
    -- Tamanu scopes the department suggester to the selected facility
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case
        when {{ parameter('departmentId') }} is null then true
        else department_id = {{ parameter('departmentId') }}
    end
    -- BL-014: the triage category is selectable
    and case
        when {{ parameter('triageScore') }} is null then true
        else score = {{ parameter('triageScore') }}
    end
    -- BL-012: the date range filters on the date of triage, inclusive of both bounds
    and {{ to_user_selected_timezone('triage_datetime') }}::date
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('triage_datetime') }}::date
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
order by triage_datetime

{% endmacro %}

{% macro audit_discharge_line_list_report(is_sensitive=false) %}

-- Discharge Audit Line List
-- One row per discharged encounter, filtered on when the discharge was recorded in
-- Tamanu rather than the discharge date entered on the form.
--
-- BL-013: candidate discharges are those with a logged change between fromDate less two days
-- and toDate plus three days, deployment-local time -- read from the thin, window-free
-- discharges_change_events base so the predicate reaches the (table_name, record_id) index
-- rather than forcing discharge_audit_dataset's change-log aggregation to run over the whole
-- change log. The window is widened because the candidate compares deployment time while
-- BL-007's exact filter compares the viewer's selected timezone, up to 26 hours apart. BL-007
-- re-applies the exact filter below, so correctness never depends on the candidate step being
-- exact.

{%- set from_bound = date_param_bound('fromDate', default_value='2024-01-01') -%}
{%- set to_bound = date_param_bound('toDate', default_value='2024-01-31') -%}

{%- set candidate_filter -%}
c.discharge_id in (
    select c2.discharge_id
    from {{ ref('discharges_change_events') }} c2
    where c2.logged_at >= {{ candidate_window_from(from_bound) }}
        and c2.logged_at < {{ candidate_window_to(to_bound) }}
)
{%- endset %}

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
from (
    {{ discharge_audit_dataset(is_sensitive=is_sensitive, record_id_filter=candidate_filter) }}
) audit
where
    -- BL-007: the date range filters on when the discharge was recorded, not on the
    -- discharge date entered on the form. getReportQueryReplacements binds :fromDate to the
    -- start of its day and :toDate to the end of its, so a plain range covers the whole of
    -- toDate and a discharge recorded at any time on it
    {{ to_user_selected_timezone('discharge_recorded_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('discharge_recorded_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
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

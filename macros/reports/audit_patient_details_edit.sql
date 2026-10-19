{% macro audit_patient_details_edit_report() %}

-- Patient Details Edit Audit Report
-- One row per patient per minute of edit activity across patients and patient_additional_data.
--
-- BL-014: candidate patients are those with a patients or patient_additional_data change
-- logged between fromDate less two days and toDate plus three days, deployment-local time --
-- read from the thin, aggregation-free change-log bases so the predicate reaches the
-- (table_name, record_id) index rather than forcing a full scan. The window is widened
-- because the candidate compares deployment time while the final WHERE below compares the
-- viewer's selected timezone, which can sit up to 26 hours apart. BL-004's exact filter then
-- trims the result to the range, so correctness never depends on the candidate step being
-- exact.

{%- set from_bound = date_param_bound('fromDate', default_value='2024-01-01') -%}
{%- set to_bound = date_param_bound('toDate', default_value='2024-01-31') -%}

{%- set candidate_patients -%}
select id as patient_id
from {{ ref('patients_change_logs') }}
where logged_at >= {{ candidate_window_from(from_bound) }}
    and logged_at < {{ candidate_window_to(to_bound) }}

union

select patient_id
from {{ ref('patient_additional_data_change_logs') }}
where logged_at >= {{ candidate_window_from(from_bound) }}
    and logged_at < {{ candidate_window_to(to_bound) }}
{%- endset %}

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    edited_by_user as "{{ translate_label('logChangeBy') }}",
    user_email as "{{ translate_label('userEmail') }}",
    user_role as "{{ translate_label('userRole') }}",
    to_char({{ to_user_selected_timezone('edited_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('logChangeDateTime') }}"
from (
    {{ patients_change_logs_core(candidate_patient_ids=candidate_patients) }}
) edits
where
    -- BL-004: the candidate predicate's exact-filter safety net (see header)
    {{ to_user_selected_timezone('edited_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('edited_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    and
    case
        when {{ parameter('patientId') }} is null then true
        else patient_id = {{ parameter('patientId') }}
    end
    and
    case
        when {{ parameter('userId') }} is null then true
        else edited_by_user = {{ parameter('userId') }}
    end
order by edited_datetime

{% endmacro %}

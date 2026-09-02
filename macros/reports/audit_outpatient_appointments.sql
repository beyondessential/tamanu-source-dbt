{% macro audit_outpatient_appointments_report(is_sensitive=false) %}

-- Outpatient Appointment Audit Report
-- One row per change event, with current and previous appointment details.
--
-- BL-029: the date range bounds when the edit was made, not the appointment's scheduled
-- time, so an administrator sees who edited appointments recently (MAUI-6183).
--
-- BL-030: the date range is applied before the change-log window functions, which would
-- otherwise block predicate pushdown and force a full change-log scan on every run. The
-- candidate filter below uses no window functions so the predicate reaches the scan, and it
-- compares a bare logged_at against constant bounds, which leaves it BRIN-prunable --
-- logged_at is BRIN-only after Tamanu migration #10639. The final WHERE re-applies the same
-- filter, so correctness never depends on the early filter being exact. The facility
-- partition (BL-033) and facilityId are applied in the candidate filter too: an event
-- surviving the final WHERE satisfies the date and the facility predicate on its own row,
-- so its appointment is still a candidate.
--
-- Business logic lives in outpatient_appointments_audit_core() alongside the dataset; this
-- macro only filters and formats.

{%- set from_bound = parameter('fromDate', default_value='2025-01-01', data_type='date') -%}
{#- BL-029: cast before the interval arithmetic. At compile time parameter() emits a bare
    untyped placeholder, and `unknown + interval` does not resolve to date arithmetic --
    same reason audit_discharge_line_list casts. -#}
{%- set to_bound = "(" ~ parameter('toDate', default_value='2025-01-31', data_type='date') | trim ~ ")::date" -%}

{%- set candidate_filter -%}
c.record_id in (
    select c2.record_id
    from {{ ref('outpatient_appointments_change_events') }} c2
    -- BL-028: mirrors the core's inner joins, so this drops only events the core would
    -- have dropped anyway
    join {{ ref('location_groups') }} lg2
        on lg2.id = c2.record_data ->> 'location_group_id'
    join {{ ref('facilities') }} f2
        on f2.id = lg2.facility_id
        and f2.is_sensitive = {{ is_sensitive }}
    where c2.logged_at >= {{ from_user_selected_timezone(from_bound) }}
        and c2.logged_at < {{ from_user_selected_timezone(to_bound ~ " + interval '1 day'") }}
        and case
            when {{ parameter('facilityId') }} is null then true
            else f2.id = {{ parameter('facilityId') }}
        end
)
{%- endset %}


select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    change_number as "{{ translate_label('auditChangeNumber') }}",
    to_char({{ to_user_selected_timezone('start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('appointmentDateTime') }}",
    appointment_type as "{{ translate_label('appointmentType') }}",
    clinician as "{{ translate_label('appointmentClinician') }}",
    location_group as "{{ translate_label('appointmentLocationGroup') }}",
    case when is_high_priority then 'Yes' else 'No' end as "{{ translate_label('appointmentPriority') }}",
    case when schedule_id is not null then 'Yes' else 'No' end as "{{ translate_label('appointmentIsRepeating') }}",
    created_by as "{{ translate_label('auditCreatedBy') }}",
    modified_by as "{{ translate_label('auditModifiedBy') }}",
    to_char({{ to_user_selected_timezone('modified_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('auditModifiedDateTime') }}",
    case when status = 'Cancelled' then 'Yes' else 'No' end as "{{ translate_label('appointmentIsCancelled') }}",
    to_char({{ to_user_selected_timezone('prev_start_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('auditPrevAppointmentDateTime') }}",
    prev_appointment_type as "{{ translate_label('auditPrevAppointmentType') }}",
    prev_clinician as "{{ translate_label('auditPrevClinician') }}",
    prev_location_group as "{{ translate_label('auditPrevLocationGroup') }}",
    case
        when prev_is_high_priority then 'Yes'
        when prev_is_high_priority is false then 'No'
    end as "{{ translate_label('auditPrevPriority') }}"
from (
    {{ outpatient_appointments_audit_core(
        is_sensitive=is_sensitive,
        record_id_filter=candidate_filter
    ) }}
) core
where
    -- BL-029: filters when the edit was made, not the appointment's scheduled time.
    -- Also the BL-030 safety net -- see header. The whole of toDate is in scope, because
    -- the time of day an edit was recorded matters here, as in audit_discharge_line_list.
    {{ to_user_selected_timezone('modified_datetime') }}
        >= {{ from_bound }}
    and
    {{ to_user_selected_timezone('modified_datetime') }}
        < {{ to_bound }} + interval '1 day'
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
order by display_id, appointment_id, change_number

{% endmacro %}

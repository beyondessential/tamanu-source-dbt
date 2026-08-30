{% macro outpatient_appointments_audit_dataset(is_sensitive=false) %}

{{
    config(
        materialized='incremental' if target.name.startswith('analytics') else 'view',
        incremental_strategy='delete+insert',
        unique_key='appointment_id',
        enabled=(var('has_sensitive_facility', false) if is_sensitive else true)
    )
}}

-- Outpatient Appointments Audit Dataset
-- One row per meaningful modification to an appointment, excluding creation and status-only
-- changes. Full, unfiltered history -- the report applies its own date range. BL-023, BL-025.
--
-- BL-034: delete+insert keyed on appointment_id, not append. change_number and the prev_*
-- columns come from window functions partitioned by appointment_id, so a new event
-- invalidates that appointment's LATER rows, whose own cursor never moves; append would
-- leave them stale.
--
-- BL-035: a refresh is not self-healing. dbt deletes only ids present in the new result, and
-- candidates come from the change log alone -- so a zero-row recompute, a soft-delete, a
-- sensitivity flip or a renamed join target all leave stale rows behind.
--
-- BL-038: the sensitive variant is disabled unless the deployment has sensitive facilities.
-- A permanently empty incremental table has watermark 0, so every run would rescan the whole
-- change log to emit nothing -- worse than the view it replaced.

{%- set candidate_filter -%}
c.record_id in (
    select distinct c2.record_id
    from {{ ref('outpatient_appointments_change_events') }} c2
    where c2.updated_at_sync_tick >= (select coalesce(max(updated_at_sync_tick), 0) from {{ this }})
)
{%- endset %}


select
    change_id,
    appointment_id,
    change_number,
    patient_id,
    display_id,
    first_name,
    last_name,
    date_of_birth,
    start_datetime as appointment_start_datetime,
    end_datetime as appointment_end_datetime,
    appointment_type,
    appointment_type_id,
    clinician,
    clinician_id,
    location_group,
    location_group_id,
    case when is_high_priority then 'Yes' else 'No' end as priority,
    schedule_id,
    case when schedule_id is not null then 'Yes' else 'No' end as is_repeating,
    created_by,
    created_by_user_id,
    modified_by,
    modified_by_user_id,
    modified_datetime,
    -- BL-032: persisted so a later run can read the watermark back from it. The comparison
    -- above is >= not >: a sync tick is shared by every row written in that session, so a
    -- strict one would permanently skip rows landing on the boundary tick after the last run
    -- read it. Reprocessing that tick is free -- BL-034 is idempotent per appointment.
    updated_at_sync_tick,
    case when status = 'Cancelled' then 'Yes' else 'No' end as is_cancelled,
    prev_start_datetime,
    prev_end_datetime,
    prev_appointment_type,
    prev_appointment_type_id,
    prev_clinician,
    prev_clinician_id,
    prev_location_group,
    prev_location_group_id,
    case
        when prev_is_high_priority then 'Yes'
        when prev_is_high_priority is false then 'No'
    end as prev_priority,
    facility_id,
    facility
from (
    {{ outpatient_appointments_audit_core(
        is_sensitive=is_sensitive,
        record_id_filter=candidate_filter if is_incremental() else none
    ) }}
) core
-- BL-034: no tail filter on the cursor, deliberately. delete+insert removes all of a
-- candidate's existing rows, so this must re-emit its full history, not just changed rows.

{% endmacro %}

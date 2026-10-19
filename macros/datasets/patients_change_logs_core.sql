{% macro patients_change_logs_core(candidate_patient_ids=none) %}
-- BL-013: shared patient-edit history aggregation (see
-- specs/reports/audit-patient-details-edit.md). candidate_patient_ids is a subquery of
-- candidate patient ids (not a full predicate -- unlike discharges_change_log_events()'s and
-- outpatient_appointments_change_log_events()'s record_id_filter, which splice in a complete
-- boolean expression, this is spliced inside an `in (...)` the macro supplies itself, since the
-- two source tables key on different columns: `lcp.id in (candidate_patient_ids)` and
-- `lcpad.patient_id in (candidate_patient_ids)`). It runs before the grouping below, which --
-- like a window function -- blocks Postgres from pushing a predicate down into the change-log
-- scan on its own. Used unfiltered by ds__patients_change_logs and candidate-filtered by the
-- audit report.
with patient_edits as (
    -- Patient details edits
    select
        lcp.id as patient_id,
        lcp.display_id,
        lcp.first_name,
        lcp.last_name,
        lcp.date_of_birth,
        lcp.sex,
        lcp.village_id,
        lcp.updated_by_user_id,
        lcp.logged_at
    from {{ ref('patients_change_logs') }} lcp
    {%- if candidate_patient_ids %}
    where lcp.id in ({{ candidate_patient_ids }})
    {%- endif %}

    union all

    -- Patient additional data edits
    select
        lcpad.patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.date_of_birth,
        p.sex,
        p.village_id,
        lcpad.updated_by_user_id,
        lcpad.logged_at
    from {{ ref('patient_additional_data_change_logs') }} lcpad
    left join {{ ref('patients') }} p on p.id = lcpad.patient_id
    {%- if candidate_patient_ids %}
    where lcpad.patient_id in ({{ candidate_patient_ids }})
    {%- endif %}
),

grouped_edits as (
    select
        pe.patient_id,
        pe.display_id,
        pe.first_name,
        pe.last_name,
        pe.date_of_birth,
        pe.sex,
        pe.village_id,
        pe.updated_by_user_id,
        date_trunc('minute', pe.logged_at) as edited_datetime
    from patient_edits pe
    group by
        pe.patient_id,
        pe.display_id,
        pe.first_name,
        pe.last_name,
        pe.date_of_birth,
        pe.sex,
        pe.village_id,
        pe.updated_by_user_id,
        date_trunc('minute', pe.logged_at)
)

select
    ge.patient_id,
    ge.display_id,
    ge.first_name,
    ge.last_name,
    ge.date_of_birth,
    ge.sex,
    ge.village_id,
    village.name as village,
    ge.updated_by_user_id as edited_by_user_id,
    u.display_name as edited_by_user,
    u.email as user_email,
    u.role as user_role,
    ge.edited_datetime
from grouped_edits ge
left join {{ ref('users') }} u on u.id = ge.updated_by_user_id
left join {{ ref('reference_data') }} village on village.id = ge.village_id
{% endmacro %}

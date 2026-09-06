{% macro task_followup_dataset(is_sensitive=false) %}

-- Task Follow-up Dataset
-- One row per designation-assigned task, with the encounter, discharge and follow-up
-- context needed to chase up work that was not done. Backs the task follow-up register
-- report -- see specs/reports/task-followup-register.md.

with scoped_encounters as not materialized (
    -- BL-001: every encounter type is in scope, at a non-sensitive facility -- the report
    -- layer narrows by type
    select
        e.id as encounter_id,
        e.patient_id,
        e.encounter_type,
        e.start_datetime,
        e.end_datetime,
        l.location_group_id,
        lg.name as location_group_name,
        f.id as facility_id,
        f.name as facility_name
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l on l.id = e.location_id
    join {{ ref('facilities') }} f on f.id = l.facility_id
    left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
    where f.is_sensitive = {{ is_sensitive }}
),

-- BL-003: a task carries one row per designation it is assigned to, collapsed here so the
-- dataset keeps one row per task
task_designation_agg as (
    select
        td.task_id,
        array_agg(distinct td.designation_id::text) as designation_ids,
        -- BL-003: a designation with no resolvable reference data row shows as its raw ID
        -- rather than dropping the task out of the register
        string_agg(
            distinct coalesce(designation.name, td.designation_id),
            ', '
            order by coalesce(designation.name, td.designation_id)
        ) as designations
    from {{ ref('task_designations') }} td
    left join {{ ref('reference_data') }} designation on designation.id = td.designation_id
    group by td.task_id
),

-- BL-009: the first non-cancelled outpatient appointment falling on or after the end of the
-- encounter -- or after its start, while the encounter is still open
followup_appointments as (
    select distinct on (ae.encounter_id)
        ae.encounter_id,
        a.start_datetime as appointment_datetime,
        lg.name as appointment_location_group
    from scoped_encounters ae
    join {{ ref('outpatient_appointments') }} a
        on a.patient_id = ae.patient_id
        and a.start_datetime >= coalesce(ae.end_datetime, ae.start_datetime)
        -- the appointment this encounter was created from is the visit itself, not a
        -- follow-up -- without this an open clinic encounter reports its own booking
        and a.encounter_id is distinct from ae.encounter_id
    left join {{ ref('location_groups') }} lg on lg.id = a.location_group_id
    where a.status != 'Cancelled'
    order by ae.encounter_id asc, a.start_datetime asc
),

encounter_diagnosis_agg as (
    select
        ed.encounter_id,
        string_agg(diagnosis.name, '; ' order by ed.datetime)
        filter (where ed.is_primary) as primary_diagnoses,
        -- BL-016: is_primary is nullable, so an unclassified diagnosis reads as secondary
        -- rather than falling out of both columns
        string_agg(diagnosis.name, '; ' order by ed.datetime)
        filter (where not coalesce(ed.is_primary, false)) as secondary_diagnoses
    from {{ ref('encounter_diagnoses') }} ed
    join {{ ref('reference_data') }} diagnosis on diagnosis.id = ed.diagnosis_id
    group by ed.encounter_id
)

select
    t.id as task_id,
    ae.encounter_id,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.sex,
    p.date_of_birth,
    date_part('year', age(ae.start_datetime, p.date_of_birth)) as age,
    village.id as village_id,
    village.name as village,
    ae.facility_id,
    ae.facility_name as facility,
    ae.location_group_id,
    ae.location_group_name as location_group,
    ae.encounter_type,
    ae.start_datetime as encounter_start_datetime,
    ae.end_datetime as encounter_end_datetime,
    case
        when ae.end_datetime is not null
            then round(
                    (extract(epoch from (ae.end_datetime - ae.start_datetime)) / 86400.0)::numeric, 1
                )
    end as length_of_stay_days,
    diagnoses.primary_diagnoses,
    diagnoses.secondary_diagnoses,
    tda.designation_ids,
    tda.designations,
    t.name as task_name,
    t.status as task_status,
    -- BL-005: the register's four outcomes over Tamanu's three statuses -- a repeating task
    -- the system marked overdue reads as missed, a clinician's own non-completion as not
    -- completed
    case
        when t.status = 'completed' then 'Completed'
        when t.status = 'todo' then 'Outstanding'
        when t.not_completed_reason_id = 'tasknotcompletedreason-taskoverdue' then 'Missed'
        else 'Not completed'
    end as task_outcome,
    not_completed_reason.name as not_completed_reason,
    case when t.high_priority then 'Yes' else 'No' end as high_priority,
    requester.display_name as requested_by,
    t.request_datetime as task_requested_datetime,
    t.due_datetime as task_due_datetime,
    t.completed_datetime as task_completed_datetime,
    -- BL-006: hours between the task being requested and being marked complete
    case
        when t.completed_datetime is not null
            then round(
                    (extract(epoch from (t.completed_datetime - t.request_datetime)) / 3600.0)::numeric,
                    1
                )
    end as hours_to_completion,
    coalesce(t.completed_note, t.todo_note, t.note) as task_note,
    -- BL-008: a note counts towards the designation when its author, or the clinician it was
    -- recorded on behalf of, currently holds that designation
    case
        when exists (
                select 1
                from {{ ref('notes') }} n
                join {{ ref('user_designations') }} ud
                    on ud.user_id in (n.authored_by_id, n.on_behalf_of_id)
                where n.record_type = 'Encounter'
                    and n.record_id = ae.encounter_id
                    and ud.designation_id::text = any(tda.designation_ids)
            ) then 'Yes'
        else 'No'
    end as designation_notes_recorded,
    disposition.name as discharge_disposition,
    case when fa.encounter_id is not null then 'Yes' else 'No' end as followup_appointment_booked,
    fa.appointment_datetime as followup_appointment_datetime,
    fa.appointment_location_group as followup_appointment_location_group
from {{ ref('tasks') }} t
-- BL-003: an inner join drops tasks assigned to nobody -- the register is about work handed
-- to a designation
join task_designation_agg tda on tda.task_id = t.id
join scoped_encounters ae on ae.encounter_id = t.encounter_id
join {{ ref('patients') }} p on p.id = ae.patient_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('reference_data') }} not_completed_reason
    on not_completed_reason.id = t.not_completed_reason_id
left join {{ ref('users') }} requester on requester.id = t.requested_by_user_id
left join {{ ref('discharges') }} d on d.encounter_id = ae.encounter_id
left join {{ ref('reference_data') }} disposition on disposition.id = d.disposition_id
left join encounter_diagnosis_agg diagnoses on diagnoses.encounter_id = ae.encounter_id
left join followup_appointments fa on fa.encounter_id = ae.encounter_id
-- BL-002: medication_due_task rows exist only to drive the ward dashboard
where t.task_type = 'normal_task'

{% endmacro %}

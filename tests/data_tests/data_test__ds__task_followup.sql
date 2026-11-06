-- Cross-model invariants for ds__task_followup.
-- Returns violating rows (a passing test returns none).
-- AC-001 (one row per task), AC-002 (stored status values), AC-003 (register outcome values)
-- and AC-004 (encounter type values) are asserted as schema tests in ds__task_followup.yml.

with model as (
    select * from {{ ref('ds__task_followup') }}
),

-- AC-005 / BL-002: medication due tasks drive the ward dashboard and never reach the register
ac_005_medication_due_task_included as (
    select
        m.task_id,
        'AC-005' as failed_ac
    from model m
    join {{ ref('tasks') }} t on t.id = m.task_id
    where t.task_type != 'normal_task'
),

-- AC-006 / BL-003: every row's task is assigned to at least one designation and carries a
-- name for it -- an unresolvable designation falls back to its raw ID, so this is never
-- blank while designation_ids is populated
ac_006_designations_incomplete as (
    select
        m.task_id,
        'AC-006' as failed_ac
    from model m
    where coalesce(array_length(m.designation_ids, 1), 0) = 0
        or nullif(trim(m.designations), '') is null
),

-- AC-007 / BL-005: the four register outcomes follow from the stored status and, for a
-- non-completion, whether the reason is the system's overdue reason
ac_007_outcome_does_not_follow_status as (
    select
        m.task_id,
        'AC-007' as failed_ac
    from model m
    join {{ ref('tasks') }} t on t.id = m.task_id
    where m.task_outcome != case
            when t.status = 'completed' then 'Completed'
            when t.status = 'todo' then 'Outstanding'
            when t.not_completed_reason_id = 'tasknotcompletedreason-taskoverdue' then 'Missed'
            else 'Not completed'
        end
),

-- AC-008 / BL-006: time to completion is present exactly when the task was completed, and a
-- task is never completed before it was raised
ac_008_time_to_completion_inconsistent as (
    select
        task_id,
        'AC-008' as failed_ac
    from model
    where (task_completed_datetime is null) != (hours_to_completion is null)
        or hours_to_completion < 0
),

-- AC-009 / BL-009: a follow-up appointment falls on or after the encounter ends, or after it
-- starts while the encounter is still open
ac_009_followup_appointment_precedes_encounter as (
    select
        task_id,
        'AC-009' as failed_ac
    from model
    where followup_appointment_datetime
        < coalesce(encounter_end_datetime, encounter_start_datetime)
        or (followup_appointment_booked = 'Yes') != (followup_appointment_datetime is not null)
),

-- AC-010 / BL-001: length of stay is present exactly when the encounter ended, and is never
-- negative
ac_010_length_of_stay_inconsistent as (
    select
        task_id,
        'AC-010' as failed_ac
    from model
    where (encounter_end_datetime is null) != (length_of_stay_days is null)
        or length_of_stay_days < 0
)

select * from ac_005_medication_due_task_included
union all
select * from ac_006_designations_incomplete
union all
select * from ac_007_outcome_does_not_follow_status
union all
select * from ac_008_time_to_completion_inconsistent
union all
select * from ac_009_followup_appointment_precedes_encounter
union all
select * from ac_010_length_of_stay_inconsistent

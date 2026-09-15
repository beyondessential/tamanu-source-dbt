-- Cross-model invariants for ds__emergency_triage.
-- Returns violating rows (a passing test returns none).

with model as (
    select * from {{ ref('ds__emergency_triage') }}
),

-- AC-002 / BL-005, BL-013: waiting time is never negative and is never present without a
-- recorded active care time.
ac_002_waiting_time_inconsistent as (
    select
        triage_id,
        'AC-002' as failed_ac
    from model
    where waiting_time_seconds < 0
        or (active_care_datetime is null and waiting_time_seconds is not null)
),

-- AC-003 / BL-008: every triage score Tamanu can record maps to a target waiting time. The
-- score list is deliberately literal rather than derived from var('triage_target_minutes') --
-- deriving it would make this test vacuous, since a category missing from the var would also
-- be missing from the list it is checked against.
ac_003_target_missing_for_scored_triage as (
    select
        triage_id,
        'AC-003' as failed_ac
    from model
    where score in ('1', '2', '3', '4', '5')
        and target_wait_minutes is null
),

-- AC-004 / BL-008: target_time_met agrees with the waiting time and the category target.
ac_004_target_time_met_inconsistent as (
    select
        triage_id,
        'AC-004' as failed_ac
    from model
    where (
        target_time_met = 'Yes'
        and waiting_time_seconds > target_wait_minutes * 60
    )
    or (
        target_time_met = 'No'
        and waiting_time_seconds <= target_wait_minutes * 60
    )
),

-- AC-005 / BL-010, BL-013: length of stay is never negative and is never present without a
-- recorded encounter end.
ac_005_length_of_stay_inconsistent as (
    select
        triage_id,
        'AC-005' as failed_ac
    from model
    where length_of_stay_seconds < 0
        or (discharge_datetime is null and length_of_stay_seconds is not null)
),

-- AC-006 / BL-009: an admitted outcome always agrees with the encounter's OMOP visit
-- concept, and a presentation with no admission and no encounter end has no outcome.
ac_006_ed_outcome_inconsistent as (
    select
        triage_id,
        'AC-006' as failed_ac
    from model
    where (ed_outcome = 'Admitted') != coalesce(is_admitted_from_ed, false)
        or (
            ed_outcome is null
            and (coalesce(is_admitted_from_ed, false) or discharge_datetime is not null)
        )
),

-- AC-008 / BL-009: every presentation resolves an OMOP visit concept, so a blank outcome
-- always means an open encounter -- never an encounter type that clinical__visit_occurrence
-- dropped because map__omop_visit_type has no entry for it.
ac_008_visit_concept_unresolved as (
    select
        triage_id,
        'AC-008' as failed_ac
    from model
    where is_admitted_from_ed is null
)

select * from ac_002_waiting_time_inconsistent
union all
select * from ac_003_target_missing_for_scored_triage
union all
select * from ac_004_target_time_met_inconsistent
union all
select * from ac_005_length_of_stay_inconsistent
union all
select * from ac_006_ed_outcome_inconsistent
union all
select * from ac_008_visit_concept_unresolved

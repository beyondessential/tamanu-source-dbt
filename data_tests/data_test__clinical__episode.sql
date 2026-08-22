-- Singular tests for clinical__episode and int__registration_status_history. One row per
-- violation, tagged with the acceptance criterion it breaks.
-- See specs/dbt-model/clinical__episode.md.

with episode as (
    select * from {{ ref('clinical__episode') }}
),

registrations as (
    select * from {{ ref('patient_program_registrations') }}
),

program_registries as (
    select * from {{ ref('program_registries') }}
),

history as (
    select * from {{ ref('int__registration_status_history') }}
),

-- AC-005: episode_end_source names the rule that closed the episode, so it is
-- 'deactivation' exactly when a deactivation datetime was recorded, and 'status change'
-- exactly when the end came from the logged transition instead (BL-004)
ac_005 as (
    select
        e.episode_id,
        'AC-005' as failed_ac
    from episode e
    join registrations r on r.id = e.episode_id
    where (r.deactivated_datetime is not null) != (e.episode_end_source = 'deactivation')
        or (
            e.episode_end_source = 'status change'
            and r.deactivated_datetime is not null
        )
),

-- AC-006: the two end columns are derived from one value, so they are null together (BL-004)
ac_006 as (
    select
        episode_id,
        'AC-006' as failed_ac
    from episode
    where (episode_end_date is null) != (episode_end_datetime is null)
),

-- AC-007: an active enrolment has not ended (BL-005)
ac_007 as (
    select
        episode_id,
        'AC-007' as failed_ac
    from episode
    where registration_status = 'active'
        and (episode_end_datetime is not null or episode_end_source is not null)
),

-- AC-008: currently-at is only meaningful where the registry configures it (BL-007)
ac_008 as (
    select
        episode_id,
        'AC-008' as failed_ac
    from episode
    where currently_at_type is null
        and (currently_at_id is not null or currently_at_name is not null)
),

-- AC-012: every enrolment that is not recorded-in-error reaches the model (BL-001, BL-002)
ac_012 as (
    select
        'row count' as episode_id,
        'AC-012' as failed_ac
    from (
        select
            (select count(*) from episode) as modelled,
            (
                select count(*) from registrations
                where registration_status != 'recordedInError'
            ) as expected
    ) counts
    where modelled != expected
),

-- AC-016: an inactive enrolment with no deactivation datetime has an end exactly when the
-- history offers a transition to draw it from (BL-004, BL-006)
ac_016 as (
    select
        e.episode_id,
        'AC-016' as failed_ac
    from episode e
    join registrations r on r.id = e.episode_id
    left join (
        select episode_id from history where registration_status = 'inactive' group by episode_id
    ) h on h.episode_id = e.episode_id
    where r.registration_status = 'inactive'
        and r.deactivated_datetime is null
        and (h.episode_id is not null) != (e.episode_end_datetime is not null)
),

-- AC-018: the columns the model hardcodes to NULL, asserted directly rather than left to be
-- rediscovered by a consumer (BL-009, BL-010)
ac_018 as (
    select
        episode_id,
        'AC-018' as failed_ac
    from episode
    where episode_concept_id is not null
        or episode_object_concept_id is not null
        or episode_parent_id is not null
        or episode_number is not null
),

-- AC-013: one history row per registration per logged moment (BL-012)
ac_013 as (
    select
        episode_id,
        'AC-013' as failed_ac
    from history
    group by episode_id, logged_at
    having count(*) > 1
),

-- AC-014: history belongs to a modelled episode (BL-012). Recorded-in-error enrolments are
-- excluded from the episode model, so they are excluded here too
ac_014 as (
    select
        h.episode_id,
        'AC-014' as failed_ac
    from history h
    join registrations r on r.id = h.episode_id
    left join episode e on e.episode_id = h.episode_id
    where r.registration_status != 'recordedInError'
        and e.episode_id is null
),

-- AC-015: the last thing the history says about a registration is what the episode reports
-- as current (BL-014)
ac_015 as (
    select
        e.episode_id,
        'AC-015' as failed_ac
    from episode e
    join (
        select distinct on (episode_id)
            episode_id,
            registration_status,
            clinical_status_id
        from history
        order by episode_id, change_number desc
    ) latest on latest.episode_id = e.episode_id
    join registrations r on r.id = e.episode_id
    where latest.registration_status != e.registration_status
        or coalesce(latest.clinical_status_id, '') != coalesce(r.clinical_status_id, '')
),

-- AC-009 as a cross-check on the source rather than the accepted_values list: the model must
-- take currently_at_type from the registry, not invent one (BL-007)
ac_009 as (
    select
        e.episode_id,
        'AC-009' as failed_ac
    from episode e
    join registrations r on r.id = e.episode_id
    left join program_registries pr on pr.id = r.program_registry_id
    where coalesce(e.currently_at_type, '') != coalesce(pr.currently_at_type, '')
)

select episode_id, failed_ac from ac_005
union all select episode_id, failed_ac from ac_006
union all select episode_id, failed_ac from ac_007
union all select episode_id, failed_ac from ac_008
union all select episode_id, failed_ac from ac_009
union all select episode_id, failed_ac from ac_012
union all select episode_id, failed_ac from ac_013
union all select episode_id, failed_ac from ac_014
union all select episode_id, failed_ac from ac_015
union all select episode_id, failed_ac from ac_016
union all select episode_id, failed_ac from ac_018

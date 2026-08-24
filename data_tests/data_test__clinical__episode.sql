-- Singular tests for clinical__episode and int__registration_status_history. One row per
-- violation, tagged with the acceptance criterion it breaks.
-- See specs/dbt-model/clinical__episode.md.

with episode as (
    select * from {{ ref('clinical__episode') }}
),

registrations as (
    select * from {{ ref('patient_program_registrations') }}
),

patients as (
    select * from {{ ref('patients') }}
),

program_registries as (
    select * from {{ ref('program_registries') }}
),

history as (
    select * from {{ ref('int__registration_status_history') }}
),

-- the only kind of history entry that may close an episode: a logged transition to inactive.
-- The synthetic current-state row is stamped at the enrolment datetime where nothing was
-- logged, so drawing an end from it would close the episode at its own start (BL-004, BL-006)
logged_inactive as (
    select episode_id
    from history
    where registration_status = 'inactive'
        and history_source = 'change log'
    group by episode_id
),

-- AC-005: episode_end_source names the rule that closed the episode. Only an inactive
-- registration ends (BL-005), and within one it is 'deactivation' exactly when a deactivation
-- datetime was recorded and 'status change' exactly when the end came from the logged
-- transition instead (BL-004). Compared with `is distinct from` so a NULL source is judged
-- rather than skipped by three-valued logic
expected_end_source as (
    select
        e.episode_id,
        case
            when r.registration_status != 'inactive' then null
            when r.deactivated_datetime is not null then 'deactivation'
            when h.episode_id is not null then 'status change'
        end as expected_source
    from episode e
    join registrations r on r.id = e.episode_id
    left join logged_inactive h on h.episode_id = e.episode_id
),

ac_005 as (
    select
        e.episode_id,
        'AC-005' as failed_ac
    from episode e
    join expected_end_source x on x.episode_id = e.episode_id
    where e.episode_end_source is distinct from x.expected_source
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

-- AC-012: every enrolment in the modelled population reaches the model -- not recorded in
-- error, on a patient clinical__person carries, and in a registry that still exists, the
-- registry join being inner because an enrolment is an enrolment *in a registry*
-- (BL-001, BL-002, BL-011)
ac_012 as (
    select
        'row count' as episode_id,
        'AC-012' as failed_ac
    from (
        select
            (select count(*) from episode) as modelled,
            (
                select count(*)
                from registrations r
                join patients p on p.id = r.patient_id
                join program_registries pr on pr.id = r.program_registry_id
                where r.registration_status != 'recordedInError'
            ) as expected
    ) counts
    where modelled != expected
),

-- AC-016: an inactive enrolment with no deactivation datetime has an end exactly when the
-- history offers a *logged* transition to draw it from. Without one the change predates the
-- log's coverage floor and the episode reads as open (BL-004, BL-006)
ac_016 as (
    select
        e.episode_id,
        'AC-016' as failed_ac
    from episode e
    join registrations r on r.id = e.episode_id
    left join logged_inactive h on h.episode_id = e.episode_id
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

-- AC-013: the history carries one row per change-log entry, keyed by the log's own
-- changelog_id, so entries sharing an instant are told apart rather than collapsed (BL-012)
ac_013_logged as (
    select
        min(episode_id) as episode_id,
        'AC-013' as failed_ac
    from history
    where changelog_id is not null
    group by changelog_id
    having count(*) > 1
),

-- AC-013: and one synthetic current-state row per registration at most, identified by a null
-- changelog_id -- it is kept only where nothing logged at the last instant matches current
-- state (BL-014)
ac_013_current as (
    select
        episode_id,
        'AC-013' as failed_ac
    from history
    where changelog_id is null
    group by episode_id
    having count(*) > 1
),

-- AC-014: every history row belongs to a modelled episode (BL-012). The history is built over
-- the same population the episode is, recorded-in-error enrolments excluded from both, so this
-- holds without exception
ac_014 as (
    select
        h.episode_id,
        'AC-014' as failed_ac
    from history h
    left join episode e on e.episode_id = h.episode_id
    where e.episode_id is null
),

-- AC-015: at a registration's latest history instant, something says what the episode reports
-- as current -- either a logged entry that already agrees, or the synthetic row kept because
-- none did (BL-014). Asked of the instant rather than of the single last row, because the log
-- may have written two entries at that instant and their order is not knowable (BL-012)
ac_015 as (
    select
        e.episode_id,
        'AC-015' as failed_ac
    from episode e
    where not exists (
            select 1
            from history h
            where h.episode_id = e.episode_id
                and h.logged_at = (
                    select max(latest.logged_at)
                    from history latest
                    where latest.episode_id = e.episode_id
                )
                and h.registration_status is not distinct from e.registration_status
                and h.clinical_status_id is not distinct from e.clinical_status_id
        )
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

select
    episode_id,
    failed_ac
from ac_005
union all
select
    episode_id,
    failed_ac
from ac_006
union all
select
    episode_id,
    failed_ac
from ac_007
union all
select
    episode_id,
    failed_ac
from ac_008
union all
select
    episode_id,
    failed_ac
from ac_009
union all
select
    episode_id,
    failed_ac
from ac_012
union all
select
    episode_id,
    failed_ac
from ac_013_logged
union all
select
    episode_id,
    failed_ac
from ac_013_current
union all
select
    episode_id,
    failed_ac
from ac_014
union all
select
    episode_id,
    failed_ac
from ac_015
union all
select
    episode_id,
    failed_ac
from ac_016
union all
select
    episode_id,
    failed_ac
from ac_018

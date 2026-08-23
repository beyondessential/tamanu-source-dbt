-- int__registration_status_history -- one row per recorded change to a program registration,
-- carrying the registration and clinical status as at that change (BL-012, BL-013).
--
-- patient_program_registrations is updated in place: its id is a deterministic composite of
-- patient and registry, so the table holds current state and a patient's passage through the
-- clinical status list survives only in the change log. Retention and loss-to-follow-up are
-- questions about transitions, so the history has to be modelled for them to be answerable.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Spec: specs/dbt-model/clinical__episode.md, BL-012..BL-016.

with change_logs as (
    select * from {{ ref('patient_program_registrations_change_logs') }}
),

-- the population clinical__episode models, read from where it is defined rather than rebuilt
-- (BL-001, BL-002, BL-026, AC-014). An enrolment recorded in error is a data-entry mistake, and
-- so is the passage through the statuses that led to it; merged-away patients are already
-- excluded upstream
enrolments as (
    select
        enrolment_id as id,
        person_id as patient_id,
        program_registry_id,
        enrolment_datetime as datetime,
        registration_status,
        clinical_status_id,
        registered_by_id
    from {{ ref('int__program_enrolments') }}
    where registration_status != 'recordedInError'
),

-- every logged change, valued as at the change (BL-013). The base model already excludes the
-- test patient and floors coverage at Tamanu 2.33.0 (BL-015, BL-016)
logged as (
    select
        cl.id as episode_id,
        cl.patient_id as person_id,
        cl.program_registry_id,
        cl.logged_at,
        cl.registration_status,
        cl.clinical_status_id,
        cl.updated_by_user_id as changed_by_provider_id,
        'change log' as history_source
    from change_logs cl
    join enrolments e on e.id = cl.id
),

last_logged as (
    select distinct on (episode_id)
        episode_id,
        logged_at as last_logged_at,
        registration_status as last_logged_status,
        clinical_status_id as last_logged_clinical_status_id
    from logged
    order by episode_id asc, logged_at desc
),

-- current state, so a registration whose changes predate the log's coverage floor still has
-- history (BL-014, BL-015). Stamped at or after the last logged change so it sorts last.
--
-- Where nothing was logged this falls back to the enrolment datetime, which is a placement
-- rather than an observed change: nothing is known about when the registration reached this
-- state. A consumer asking *when* a transition happened must filter on
-- history_source = 'change log' -- clinical__episode does, for BL-004/BL-006
current_state as (
    select
        r.id as episode_id,
        r.patient_id as person_id,
        r.program_registry_id,
        greatest(r.datetime, coalesce(l.last_logged_at, r.datetime)) as logged_at,
        r.registration_status,
        r.clinical_status_id,
        r.registered_by_id as changed_by_provider_id,
        'current' as history_source,
        -- the log's latest snapshot should already be current state, since the log is written on
        -- update. Where it is not, the table is what the registration says it is now
        (
            r.registration_status is distinct from l.last_logged_status
            or r.clinical_status_id is distinct from l.last_logged_clinical_status_id
        ) as diverges_from_log
    from enrolments r
    left join last_logged l on l.episode_id = r.id
),

combined as (
    select
        *,
        false as diverges_from_log
    from logged
    union all
    select * from current_state
),

-- A registration with logged changes has current state already represented by its latest logged
-- row -- that change is what produced it -- so the two collide on logged_at and the logged row
-- wins: it names the user who acted. Current state survives as its own row where nothing was
-- logged, and where the log's latest snapshot disagrees with it: a log that has lost a row would
-- otherwise make the history's last word a stale one, and AC-015 a build failure rather than
-- something a consumer can see. One row per collision either way, which is what keeps AC-013
-- true (BL-012, BL-014)
deduplicated as (
    select distinct on (episode_id, logged_at)
        episode_id,
        person_id,
        program_registry_id,
        logged_at,
        registration_status,
        clinical_status_id,
        changed_by_provider_id,
        history_source
    from combined
    order by
        episode_id,
        logged_at,
        case
            when history_source = 'current' and diverges_from_log then 0
            when history_source = 'change log' then 1
            else 2
        end
)

select
    episode_id,
    person_id,
    program_registry_id,
    logged_at,
    registration_status,
    clinical_status_id,
    changed_by_provider_id,
    history_source,
    row_number() over (partition by episode_id order by logged_at) as change_number
from deduplicated

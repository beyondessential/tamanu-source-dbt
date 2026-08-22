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

registrations as (
    select * from {{ ref('patient_program_registrations') }}
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
),

last_logged as (
    select
        episode_id,
        max(logged_at) as last_logged_at
    from logged
    group by episode_id
),

-- current state, so a registration whose changes predate the log's coverage floor still has
-- history (BL-014, BL-015). Stamped at or after the last logged change so it sorts last
current_state as (
    select
        r.id as episode_id,
        r.patient_id as person_id,
        r.program_registry_id,
        greatest(r.datetime, coalesce(l.last_logged_at, r.datetime)) as logged_at,
        r.registration_status,
        r.clinical_status_id,
        r.registered_by_id as changed_by_provider_id,
        'current' as history_source
    from registrations r
    left join last_logged l on l.episode_id = r.id
),

combined as (
    select * from logged
    union all
    select * from current_state
),

-- A registration with logged changes has current state already represented by its latest
-- logged row -- that change is what produced it -- so the two collide on logged_at and the
-- logged row wins: it names the user who acted. Current state survives as its own row only
-- where nothing was logged, which is what keeps AC-013 true (BL-012, BL-014)
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
    order by episode_id, logged_at, case history_source when 'change log' then 0 else 1 end
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

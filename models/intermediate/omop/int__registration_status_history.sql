-- int__registration_status_history -- one row per recorded change to a program registration,
-- carrying the registration and clinical status as at that change.
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

-- BL-012: entries are scoped to the registrations clinical__episode models, read from the
-- model that defines that population rather than rebuilt here (BL-026). An enrolment recorded
-- in error is a data-entry mistake, and so is the passage through the statuses that led to it;
-- merged-away patients are already excluded upstream
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

-- BL-012: one row per change-log entry, kept as the log wrote it. Entries sharing an instant
-- are not collapsed: the log has no intra-instant order to collapse them by -- its id is a
-- uuid, so there is no last-write-wins to appeal to -- and picking one arbitrarily would let
-- the losing row take a transition with it, an exit BL-004 needed to see. changelog_id is the
-- log's own key, and is what AC-013 is keyed on instead.
--
-- BL-013: every logged change, valued as at the change, read from the logged record snapshot.
-- BL-015: the base model floors coverage at Tamanu 2.33.0, so a registration changed before
-- that release has no history for the change.
-- BL-016: sourced only from bases/, which also excludes the test patient
logged as (
    select
        cl.changelog_id,
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

-- BL-014: the registration's last logged instant. Divergence is asked of that whole instant
-- below rather than of one row picked out of it, so a second entry sharing it cannot change
-- the answer
last_logged as (
    select
        episode_id,
        max(logged_at) as last_logged_at
    from logged
    group by episode_id
),

-- BL-014: current state, so a status held now is visible without joining back to
-- clinical__episode -- and so a registration whose changes predate the log's coverage floor
-- still has history (BL-015). Stamped at or after the last logged change so it sorts last.
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
        l.last_logged_at,
        -- the log's latest snapshot should already be current state, since the log is written
        -- on update. Where nothing logged at that instant says so, the table is what the
        -- registration says it is now
        not exists (
            select 1
            from logged agreeing
            where agreeing.episode_id = r.id
                and agreeing.logged_at = l.last_logged_at
                and agreeing.registration_status is not distinct from r.registration_status
                and agreeing.clinical_status_id is not distinct from r.clinical_status_id
        ) as diverges_from_log
    from enrolments r
    left join last_logged l on l.episode_id = r.id
),

-- BL-014: where an entry at the last logged instant already says what the registration says
-- now, that entry *is* current state and names the user who acted, so the synthetic row is
-- redundant and dropped. Where none does -- a log that has lost an entry -- it is kept
-- alongside them: the logged changes are real, attributed changes that BL-004 may need to draw
-- an episode end from, and the synthetic row carries the divergence so it shows in the history
-- rather than making AC-015 a build failure. It shares their logged_at and is told apart by a
-- null changelog_id, which is what AC-013 is keyed on
retained_current_state as (
    select
        null::varchar as changelog_id,
        episode_id,
        person_id,
        program_registry_id,
        logged_at,
        registration_status,
        clinical_status_id,
        changed_by_provider_id,
        history_source
    from current_state
    where
        diverges_from_log
        or last_logged_at is null
        or logged_at != last_logged_at
),

combined as (
    select * from logged
    union all
    select * from retained_current_state
)

select
    -- BL-012: the log's own key, null on the synthetic current-state row. AC-013 keys on it, so
    -- entries sharing an instant are told apart without one of them having to be dropped
    changelog_id,
    episode_id,
    person_id,
    program_registry_id,
    logged_at,
    registration_status,
    clinical_status_id,
    changed_by_provider_id,
    history_source,
    -- current state sorts after the logged changes it shares an instant with, so the history's
    -- last word is what the registration says now (BL-014, AC-015). changelog_id breaks any
    -- remaining tie, so change_number is stable from run to run even where the log wrote two
    -- entries at one instant and their order is not knowable
    row_number() over (
        partition by episode_id
        order by
            logged_at,
            case when history_source = 'current' then 1 else 0 end,
            changelog_id nulls last
    ) as change_number
from combined

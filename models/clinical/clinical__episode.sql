-- clinical__episode -- OMOP-lite EPISODE domain. The clinical layer's first longitudinal
-- subject: every other clinical__ table hangs off an encounter, where an enrolment spans them.
--
-- OMOP categorises EPISODE as a derived element, but these rows are asserted -- one per source
-- record, nothing computed -- so the model sits in clinical__ on the same grounds as
-- observation_period. An assembled episode (an ART regimen line) belongs in derived__.
--
-- BL-001: one row per patient enrolment in a program registry, on a patient bases/patients
-- carries. The enrolment facts are resolved once in int__program_enrolments and shared with
-- ds__patient_program_registrations (BL-026); this model filters that population to the
-- clinical one and adds the episode boundaries and OMOP shaping.
--
-- Sources only from bases/ and intermediate (D10).
-- See specs/dbt-model/clinical__episode.md for BL-001..BL-011.

with all_enrolments as (
    select * from {{ ref('int__program_enrolments') }}
),

status_history as (
    select * from {{ ref('int__registration_status_history') }}
),

-- BL-004: when the registration became inactive, for an episode closed by a status change
-- rather than a deactivation. Earliest such change, so a registration reactivated and closed
-- again reports the first close rather than the latest.
--
-- BL-006: logged changes only. The history also carries a synthetic current-state row, stamped
-- at the enrolment datetime where nothing was logged; drawing an end from that would close
-- every pre-2.33.0 inactive registration at its own start instead of leaving it open
became_inactive as (
    select
        episode_id,
        min(logged_at) as inactive_at
    from status_history
    where registration_status = 'inactive'
        and history_source = 'change log'
    group by episode_id
),

-- BL-002: an enrolment recorded in error is a data-entry mistake, not a clinical fact. The
-- merged-patient exclusion is already applied upstream (BL-001, BL-026)
enrolments as (
    select * from all_enrolments
    where registration_status != 'recordedInError'
),

resolved as (
    select
        e.enrolment_id as episode_id,
        e.person_id,
        -- BL-003: the registration datetime, never null
        e.enrolment_datetime as episode_start_datetime,

        -- BL-005: only an inactive registration has ended -- an active one is open whatever
        -- else the record carries, so a deactivation stamp left behind by a reactivation
        -- cannot close it.
        -- BL-004: within an inactive registration deactivation wins, and failing that the
        -- logged transition to inactive does.
        -- BL-006: with neither the episode reads as open, which happens when the change
        -- predates the log's coverage floor
        case
            when e.registration_status != 'inactive' then null
            else coalesce(e.deactivated_datetime, bi.inactive_at)
        end as episode_end_datetime,
        case
            when e.registration_status != 'inactive' then null
            when e.deactivated_datetime is not null then 'deactivation'
            when bi.inactive_at is not null then 'status change'
        end as episode_end_source,

        e.registration_status,
        e.deactivated_datetime,
        e.program_registry_id,
        e.clinical_status_id,
        e.registry_code as episode_source_value,
        e.registry_name as episode_source_name,
        e.program_id,
        -- BL-008: the status currently held. A status the patient passed through is visible
        -- only in int__registration_status_history
        e.clinical_status_code as clinical_status_source_value,
        e.clinical_status_name as clinical_status_source_name,
        e.currently_at_type,
        e.currently_at_id,
        e.currently_at_name,
        e.registering_facility_id as care_site_id,
        e.registered_by_id as provider_id,
        e.deactivated_by_id as deactivated_by_provider_id

    from enrolments e
    left join became_inactive bi on bi.episode_id = e.enrolment_id
)

select
    -- BL-001: identity. The source id is a composite of patient and registry, so it is
    -- already unique and needs no remap to an OMOP integer id (D1)
    episode_id,
    person_id,

    -- BL-009: concept ids deferred to vocab__
    null::int as episode_concept_id,
    null::int as episode_object_concept_id,

    episode_start_datetime::date as episode_start_date,
    episode_start_datetime,
    episode_end_datetime::date as episode_end_date,
    episode_end_datetime,
    episode_end_source,

    -- provenance and union discriminator, for a second episode source
    'program registry' as episode_type_source_value,
    episode_source_value,
    episode_source_name,
    program_registry_id,
    program_id,

    -- BL-010: no parent and no sequence -- the composite key admits one episode per patient
    -- per registry. Both columns are present for schema conformance
    null::text as episode_parent_id,
    null::int as episode_number,

    registration_status,
    clinical_status_id,
    clinical_status_source_value,
    clinical_status_source_name,
    currently_at_type,
    currently_at_id,
    currently_at_name,
    care_site_id,
    provider_id,
    deactivated_datetime,
    deactivated_by_provider_id

from resolved

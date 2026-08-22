-- clinical__episode -- OMOP-lite EPISODE domain. One row per patient enrolment in a program
-- registry (BL-001), the clinical layer's first longitudinal subject: every other clinical__
-- table hangs off an encounter, where an enrolment spans them.
--
-- OMOP categorises EPISODE as a derived element, but these rows are asserted -- one per source
-- record, nothing computed -- so the model sits in clinical__ on the same grounds as
-- observation_period. An assembled episode (an ART regimen line) belongs in derived__.
--
-- Sources only from bases/ and intermediate (D10). *_concept_id deferred to the future vocab__
-- layer (BL-009).
-- See specs/dbt-model/clinical__episode.md for BL-001..BL-011.

with registrations as (
    select * from {{ ref('patient_program_registrations') }}
),

program_registries as (
    select * from {{ ref('program_registries') }}
),

clinical_statuses as (
    select * from {{ ref('program_registry_clinical_statuses') }}
),

facilities as (
    select * from {{ ref('facilities') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

patients as (
    select * from {{ ref('patients') }}
),

status_history as (
    select * from {{ ref('int__registration_status_history') }}
),

-- when the registration became inactive, for an episode closed by a status change rather than
-- a deactivation (BL-004). Earliest such change, so a registration reactivated and closed
-- again reports the first close rather than the latest.
--
-- Logged changes only. The history also carries a synthetic current-state row, stamped at the
-- enrolment datetime where nothing was logged; drawing an end from that would close every
-- pre-2.33.0 inactive registration at its own start instead of leaving it open (BL-006)
became_inactive as (
    select
        episode_id,
        min(logged_at) as inactive_at
    from status_history
    where registration_status = 'inactive'
        and history_source = 'change log'
    group by episode_id
),

-- the modelled population (BL-001). An enrolment recorded in error is a data-entry mistake
-- rather than a clinical fact (BL-002), and an enrolment left on a patient record that has
-- been merged away belongs to a person clinical__person does not carry, so neither reaches
-- the model. int__registration_status_history scopes itself identically -- it cannot read
-- this model without a cycle -- so that the two agree row for row (AC-014)
enrolments as (
    select r.*
    from registrations r
    join patients p on p.id = r.patient_id
    where r.registration_status != 'recordedInError'
),

resolved as (
    select
        e.id as episode_id,
        e.patient_id as person_id,
        e.datetime as episode_start_datetime,

        -- only an inactive registration has ended: an active one is open whatever else the
        -- record carries, so a deactivation stamp left behind by a reactivation cannot close
        -- it (BL-005). Within an inactive registration deactivation wins, and failing that the
        -- logged transition to inactive does. With neither the episode reads as open, which
        -- happens when the change predates the log's coverage floor (BL-004, BL-006)
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
        pr.code as episode_source_value,
        pr.name as episode_source_name,
        pr.program_id,
        cs.code as clinical_status_source_value,
        cs.name as clinical_status_source_name,

        -- only the column the registry is configured for is maintained, so the other is
        -- ignored even when populated (BL-007)
        pr.currently_at_type,
        case pr.currently_at_type
            when 'facility' then e.facility_id
            when 'village' then e.village_id
        end as currently_at_id,
        case pr.currently_at_type
            when 'facility' then currently_at_facility.name
            when 'village' then currently_at_village.name
        end as currently_at_name,

        e.registering_facility_id as care_site_id,
        e.registered_by_id as provider_id,
        e.deactivated_by_id as deactivated_by_provider_id

    from enrolments e
    -- every lookup is left-joined: an enrolment with no clinical status set, or no registering
    -- facility, is still a valid enrolment (BL-011)
    left join program_registries pr on pr.id = e.program_registry_id
    left join clinical_statuses cs on cs.id = e.clinical_status_id
    left join became_inactive bi on bi.episode_id = e.id
    left join facilities currently_at_facility on currently_at_facility.id = e.facility_id
    left join reference_data currently_at_village on currently_at_village.id = e.village_id
)

select
    -- identity: the source id is a composite of patient and registry, so it is already unique
    -- and needs no remap to an OMOP integer id (BL-001, D1)
    episode_id,
    person_id,

    -- concept ids deferred to vocab__ (BL-009)
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

    -- no parent and no sequence: the composite key admits one episode per patient per
    -- registry. Both columns are present for schema conformance (BL-010)
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

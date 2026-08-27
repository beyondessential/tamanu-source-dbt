-- clinical__procedure_occurrence -- OMOP-lite PROCEDURE_OCCURRENCE domain. One row per recorded
-- procedure. procedure_concept_id is deferred to the future vocab__ layer, the same convention
-- clinical__condition_occurrence uses for condition_concept_id.
--
-- bases/procedures carries free-text note/completed_note, which is why that model is
-- classification: restricted -- this model excludes both, the same split
-- clinical__visit_occurrence draws against encounters.reason_for_encounter, so it can stay
-- unrestricted. Sources only from bases/ (D10).

with procedures as (
    select * from {{ ref('procedures') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
)

select
    p.id as procedure_occurrence_id,

    -- person is reached through the encounter: bases/procedures carries encounter_id, not
    -- patient_id, directly
    e.patient_id as person_id,

    p.date as procedure_date,
    -- combines the date and time-of-day columns bases/procedures keeps separate; falls back to
    -- midnight where start_time was never recorded
    coalesce(p.date + p.start_time, p.date::timestamp) as procedure_datetime,

    -- provenance: constant EHR administrative record, the same convention
    -- clinical__visit_occurrence uses for visit_type_concept_id
    32817 as procedure_type_concept_id,

    p.clinician_id as provider_id,
    p.encounter_id as visit_occurrence_id,

    -- the procedure's own location, not the encounter's care_site_id -- a procedure can be
    -- performed somewhere other than the ward the patient is admitted to (e.g. a theatre)
    p.location_id,

    -- procedure code and name, concept_id deferred to vocab__ per BL above
    rd.code as procedure_source_value,
    rd.name as procedure_source_name,

    coalesce(p.is_completed, false) as is_completed

from procedures p
join encounters e on e.id = p.encounter_id
left join reference_data rd on rd.id = p.procedure_type_id

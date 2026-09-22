-- clinical__procedure_occurrence -- OMOP-lite PROCEDURE_OCCURRENCE domain. Two sources,
-- unioned: recorded procedures (bases/procedures) and imaging requests
-- (bases/imaging_requests). OMOP has no dedicated domain for medical imaging -- the CDM
-- describes PROCEDURE_OCCURRENCE as covering "activities or processes ordered by, or
-- carried out by, a healthcare provider on the patient with a diagnostic or therapeutic
-- purpose," and by the Standardized Vocabulary's own domain assignment an imaging study
-- (e.g. a SNOMED "Computed tomography of chest" concept) is classified under Procedure, not
-- a separate domain -- confirmed by OHDSI's own Medical Imaging Working Group: "the OMOP
-- CDM currently represents images as only imaging procedures." It carries no quantitative
-- result, so it does not belong in MEASUREMENT either.
-- BL-001: procedure_type_source_value is the branch discriminator, so imaging and
-- procedures stay distinguishable in one shared table.
--
-- BL-002: the imaging branch does not join imaging_results -- procedure_datetime is the
-- request's own timestamp, not a completion event, and is_completed is read straight off
-- imaging_requests.status. procedure_concept_id is deferred to the future vocab__ layer, the
-- same convention clinical__condition_occurrence uses for condition_concept_id.
--
-- BL-005: visit_detail_id is the segment the event happened in -- the CDM carries both
-- visit_occurrence_id and visit_detail_id on PROCEDURE_OCCURRENCE, and its own field
-- description gives this exact case ("if the Person was in the ICU at the time of the
-- Procedure the VISIT_OCCURRENCE record would reflect the overall hospital stay and the
-- VISIT_DETAIL record would reflect the ICU stay"). Resolved here, once, so every consumer
-- reads the segment off an FK rather than re-deriving it -- see that clause for the as-of
-- rule and the first-segment clamp. Nullable, as the CDM specifies.
--
-- bases/procedures carries free-text note/completed_note, which is why that model is
-- classification: restricted -- this model excludes both, the same split
-- clinical__visit_occurrence draws against encounters.reason_for_encounter, so it can stay
-- unrestricted. Sources from bases/ plus clinical__visit_detail for BL-005's FK, the same
-- clinical-on-clinical dependency clinical__observation_period already takes.
-- See specs/dbt-model/clinical__procedure_occurrence.md for BL-001..BL-005.

with procedures as (
    select * from {{ ref('procedures') }}
),

imaging_requests as (
    select * from {{ ref('imaging_requests') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

-- recorded procedures
procedure_branch as (
    select
        p.id as procedure_occurrence_id,

        -- person is reached through the encounter: bases/procedures carries encounter_id,
        -- not patient_id, directly
        e.patient_id as person_id,

        p.date as procedure_date,
        -- combines the date and time-of-day columns bases/procedures keeps separate; falls
        -- back to midnight where start_time was never recorded
        coalesce(p.date + p.start_time, p.date::timestamp) as procedure_datetime,

        -- provenance: constant EHR administrative record, the same convention
        -- clinical__visit_occurrence uses for visit_type_concept_id
        32817 as procedure_type_concept_id,
        -- BL-001: branch discriminator
        'procedure' as procedure_type_source_value,

        p.clinician_id as provider_id,
        p.encounter_id as visit_occurrence_id,

        -- BL-004: the procedure's own location, not the encounter's care_site_id -- a
        -- procedure can be performed somewhere other than the ward the patient is admitted
        -- to (e.g. a theatre)
        p.location_id,

        -- procedure code and name, concept_id deferred to vocab__ per header comment above
        rd.code as procedure_source_value,
        rd.name as procedure_source_name,

        coalesce(p.is_completed, false) as is_completed

    from procedures p
    join encounters e on e.id = p.encounter_id
    left join reference_data rd on rd.id = p.procedure_type_id
),

-- imaging requests -- OMOP classifies imaging under the Procedure domain (see header
-- comment above; the CDM has no dedicated imaging domain). BL-002: deleted and
-- entered_in_error are excluded -- entered_in_error in particular asserts the event never
-- happened, so it doesn't belong as a procedure occurrence, the same reasoning
-- clinical__drug_exposure's vaccination branch excludes RECORDED_IN_ERROR. cancelled is
-- kept: a cancelled request was genuinely ordered, so it still belongs here. No join to
-- imaging_results: procedure_datetime is when the study was requested, not completed, and
-- is_completed is the request's own recorded status, not a fact derived from a result.
imaging_branch as (
    select
        ir.id as procedure_occurrence_id,

        e.patient_id as person_id,

        -- BL-002: request time, not completion time -- no join to imaging_results
        ir.datetime::date as procedure_date,
        ir.datetime as procedure_datetime,

        32817 as procedure_type_concept_id,
        -- BL-001: branch discriminator
        'imaging request' as procedure_type_source_value,

        -- BL-003: the requesting clinician, not who (if anyone) completed it -- this branch
        -- carries no completion-side fact
        ir.requested_by_id as provider_id,
        ir.encounter_id as visit_occurrence_id,

        -- BL-004: imaging_requests' own location -- carried raw like the procedure
        -- branch's, though it is deprecated in Tamanu and effectively unpopulated;
        -- resolving facility is a consumer-layer concern either way
        ir.location_id,

        -- modality code + readable label. concept_id deferred to vocab__ per header comment
        -- above; the label mapping itself is shared with macros/datasets/imaging_requests.sql
        -- via imaging_type__label, not duplicated
        ir.imaging_type as procedure_source_value,
        {{ imaging_type__label('ir.imaging_type') }} as procedure_source_name,

        -- BL-002: the request's own status, never NULL -- imaging_requests.status is a
        -- mandatory lifecycle field, but this stays defensive on the same basis as the
        -- procedure branch's coalesce above. Covers pending/in_progress/cancelled alike as
        -- false, not just "not yet done".
        coalesce(ir.status = 'completed', false) as is_completed

    from imaging_requests ir
    join encounters e on e.id = ir.encounter_id
    -- BL-002: excludes deleted/entered_in_error; cancelled stays
    where ir.status not in ('deleted', 'entered_in_error')
),

-- BL-001: columns listed explicitly per branch so reordering one branch cannot silently
-- mis-map, the same convention clinical__condition_occurrence/clinical__drug_exposure use.
occurrences as (
    select
        procedure_occurrence_id,
        person_id,
        procedure_date,
        procedure_datetime,
        procedure_type_concept_id,
        procedure_type_source_value,
        provider_id,
        visit_occurrence_id,
        location_id,
        procedure_source_value,
        procedure_source_name,
        is_completed
    from procedure_branch

    union all

    select
        procedure_occurrence_id,
        person_id,
        procedure_date,
        procedure_datetime,
        procedure_type_concept_id,
        procedure_type_source_value,
        provider_id,
        visit_occurrence_id,
        location_id,
        procedure_source_value,
        procedure_source_name,
        is_completed
    from imaging_branch
),

-- BL-005: the segment active at the event's own timestamp -- the latest segment that had
-- already started by procedure_datetime. Both branches resolve the same way: a procedure
-- and an imaging request are each a point-in-time event, so exactly one segment holds them
-- (contrast clinical__condition_occurrence, where a diagnosis stays valid for the rest of
-- the encounter and so has no single segment to name).
--
-- Clamped to the earliest segment when the event predates every segment -- an event
-- genuinely belongs to its own encounter, so a segment recorded as starting after it (a
-- data-timing artifact, not a real ordering issue) should not leave it unattributed. The
-- join carries no timestamp condition: the order by picks the correct as-of segment where
-- one qualifies and falls back to the earliest otherwise.
--
-- The visit_detail_id tie-breaks are split by branch on purpose: among segments sharing a
-- start datetime, the as-of branch wants the last of them and the clamp branch the first,
-- matching the (start_datetime, visit_detail_id) order clinical__visit_detail chains its
-- own segments by. One shared direction would be right for only one of the two.
active_segment as (
    select distinct on (o.procedure_occurrence_id)
        o.procedure_occurrence_id,
        vd.visit_detail_id
    from occurrences o
    join visit_detail vd
        on vd.visit_occurrence_id = o.visit_occurrence_id
    order by
        o.procedure_occurrence_id,
        (vd.visit_detail_start_datetime <= o.procedure_datetime) desc,
        case when vd.visit_detail_start_datetime <= o.procedure_datetime
                then vd.visit_detail_start_datetime
        end desc,
        case when vd.visit_detail_start_datetime > o.procedure_datetime
                then vd.visit_detail_start_datetime
        end asc,
        case when vd.visit_detail_start_datetime <= o.procedure_datetime
                then vd.visit_detail_id
        end desc,
        case when vd.visit_detail_start_datetime > o.procedure_datetime
                then vd.visit_detail_id
        end asc
)

select
    o.procedure_occurrence_id,
    o.person_id,
    o.procedure_date,
    o.procedure_datetime,
    o.procedure_type_concept_id,
    o.procedure_type_source_value,
    o.provider_id,
    o.visit_occurrence_id,
    -- BL-005: left join -- clinical__visit_detail drops an encounter whose encounter_type
    -- is absent from map__omop_visit_type (its own BL-003), so the segment can genuinely
    -- fail to resolve. The CDM makes visit_detail_id optional for exactly this reason, so
    -- the event is emitted with a NULL FK rather than dropped from the domain table.
    seg.visit_detail_id,
    o.location_id,
    o.procedure_source_value,
    o.procedure_source_name,
    o.is_completed
from occurrences o
left join active_segment seg
    on seg.procedure_occurrence_id = o.procedure_occurrence_id

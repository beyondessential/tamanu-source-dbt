-- clinical__visit_detail -- OMOP-lite VISIT_DETAIL domain. One row per encounter segment
-- (BL-001): a phase within a single encounter over which the whole encounter_history
-- snapshot -- department, location, encounter_type AND clinician -- was stable. A
-- clinician handover in the same ward opens a new segment, so a segment is not a
-- contiguous ward stay; a consumer wanting that must collapse on the dimensions it
-- cares about. Segments walk the unified encounter_history timeline (BL-002); encounters
-- with no history at all get one synthesized whole-visit segment (BL-005). Per-segment
-- visit concept from map__omop_visit_type (BL-003, inner join -- see BL-003 for the
-- consequence of an unmapped encounter_type); segments chained via
-- preceding_visit_detail_id (BL-004). care_site_id is the segment's location_id (BL-006);
-- department carried as an attribute (BL-007). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__visit_detail.md for BL-001..BL-007.

with encounters as (
    select * from {{ ref('encounters') }}
),

encounter_history as (
    select * from {{ ref('encounter_history') }}
),

visit_map as (
    select * from {{ ref('map__omop_visit_type') }}
),

-- each encounter_history row is one segment start (BL-002). encounter_history is already
-- a single timeline carrying department, location, type and clinician per event, so no
-- separate department/location streams need merging
history_segments as (
    select
        -- encounter_history.id is uuid; cast to match encounters.id (varchar) for the
        -- union with synthesized_segments and the varchar visit_detail_id contract
        eh.id::varchar    as visit_detail_id,
        eh.encounter_id   as visit_occurrence_id,
        eh.datetime       as visit_detail_start_datetime,
        eh.department_id  as department_id,
        eh.location_id    as location_id,
        eh.clinician_id   as provider_id,
        eh.encounter_type as visit_detail_source_value
    from encounter_history eh
),

-- an encounter with no encounter_history rows gets one segment covering the whole visit,
-- taken from the encounter record itself, so every visit has at least one detail (BL-005)
synthesized_segments as (
    select
        e.id::varchar    as visit_detail_id,
        e.id             as visit_occurrence_id,
        e.start_datetime as visit_detail_start_datetime,
        e.department_id  as department_id,
        e.location_id    as location_id,
        e.clinician_id   as provider_id,
        e.encounter_type as visit_detail_source_value
    from encounters e
    where not exists (
        select 1 from encounter_history eh where eh.encounter_id = e.id
    )
),

-- columns listed explicitly (by name from each branch) so reordering either CTE can't
-- silently mis-map the union
segments as (
    select
        visit_detail_id,
        visit_occurrence_id,
        visit_detail_start_datetime,
        department_id,
        location_id,
        provider_id,
        visit_detail_source_value
    from history_segments
    union all
    select
        visit_detail_id,
        visit_occurrence_id,
        visit_detail_start_datetime,
        department_id,
        location_id,
        provider_id,
        visit_detail_source_value
    from synthesized_segments
),

-- close each segment at the next segment's start, falling back to the encounter end for
-- the final (open) segment; chain segments within an encounter (BL-002, BL-004)
bounded as (
    select
        s.visit_detail_id,
        s.visit_occurrence_id,
        e.patient_id as person_id,
        s.visit_detail_start_datetime,
        coalesce(
            lead(s.visit_detail_start_datetime) over w,
            -- final (open) segment closes at the encounter end; greatest() guards the case
            -- where a history row's datetime is later than e.end_datetime, which would
            -- otherwise give the last segment end < start and fail ac_006 (BL-002)
            greatest(e.end_datetime, s.visit_detail_start_datetime)
        ) as visit_detail_end_datetime,
        s.department_id,
        s.location_id,
        s.provider_id,
        s.visit_detail_source_value,
        lag(s.visit_detail_id) over w as preceding_visit_detail_id
    from segments s
    join encounters e on e.id = s.visit_occurrence_id
    window w as (
        partition by s.visit_occurrence_id
        order by s.visit_detail_start_datetime, s.visit_detail_id
    )
)

select
    b.visit_detail_id,
    b.visit_occurrence_id,
    b.person_id,

    -- per-segment visit concept (BL-003)
    vm.concept_id as visit_detail_concept_id,

    -- date + datetime pair, mirroring clinical__visit_occurrence (BL-002)
    b.visit_detail_start_datetime::date as visit_detail_start_date,
    b.visit_detail_start_datetime,
    b.visit_detail_end_datetime::date   as visit_detail_end_date,
    b.visit_detail_end_datetime,

    -- care site is the segment's location. FK to ref__care_site (location-type rows) (BL-006)
    b.location_id as care_site_id,

    -- department (organizational unit) carried as an attribute. FKs to ref__care_site
    -- (department-type rows) (BL-007)
    b.department_id,

    b.provider_id,

    -- source value retained alongside concept (D1)
    b.visit_detail_source_value,

    -- intra-visit ordering (BL-004)
    b.preceding_visit_detail_id

from bounded b
join visit_map vm on vm.local_code = b.visit_detail_source_value

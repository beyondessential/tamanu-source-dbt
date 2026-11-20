-- ref__care_site -- OMOP CARE_SITE wrapper. Heterogeneous by design: one row per Tamanu
-- department (the organizational care unit, care_site_type = 'department'), one row per
-- location (the physical room/bed, care_site_type = 'location') and one row per facility
-- (the site as a whole, care_site_type = 'facility'). Locations feed both
-- clinical__visit_occurrence.care_site_id and clinical__visit_detail.care_site_id;
-- facilities feed clinical__episode.care_site_id, an enrolment being registered at a
-- facility and never at a room. Each care site is denormalised with its parent facility.
-- Native UUID PK (D1). Sources only from bases/ (D10), with the location grain built in
-- ref__care_site_location (BL-009); OMOP column naming applied (D2).
-- See specs/dbt-model/ref__care_site.md for BL-001..BL-009.

with departments as (
    select * from {{ ref('departments') }}
),

facilities as (
    select * from {{ ref('facilities') }}
),

-- organizational care unit (BL-001, BL-005)
department_sites as (
    select
        -- identity (BL-001) -- native UUID PK, no remap to OMOP integer IDs (D1)
        d.id::varchar as care_site_id,
        'department' as care_site_type,
        d.name as care_site_name,
        d.code as care_site_source_value,
        -- place of service: source value only. No place_of_service_concept_id — OMOP's Place
        -- of Service vocabulary has no standard concepts, so there is nothing domain-correct to
        -- populate; the source value is retained for deployments that map it downstream (BL-002)
        f.type as place_of_service_source_value,
        -- parent facility, denormalised onto the care site (BL-003)
        d.facility_id,
        f.name as facility_name
    from departments d
    -- left join so a department whose facility is missing/soft-deleted is still emitted (BL-003)
    left join facilities f on f.id = d.facility_id
),

-- physical care unit: individual location (room/bed), with its facility (BL-006, BL-008, BL-009)
location_sites as (
    select * from {{ ref('ref__care_site_location') }}
),

-- BL-007: the site as a whole. Its parent facility is itself, so it carries its own name and type
-- as the facility's, and facility-level aggregation over facility_id works uniformly across all
-- three grains (BL-001)
facility_sites as (
    select
        f.id::varchar as care_site_id,
        'facility' as care_site_type,
        f.name as care_site_name,
        f.code as care_site_source_value,
        f.type as place_of_service_source_value,
        f.id as facility_id,
        f.name as facility_name
    from facilities f
)

select * from department_sites
union all
select * from location_sites
union all
select * from facility_sites

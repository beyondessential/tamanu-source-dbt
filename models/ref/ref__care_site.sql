-- ref__care_site -- OMOP CARE_SITE wrapper. Heterogeneous by design: one row per Tamanu
-- department (the organizational care unit, care_site_type = 'department'), one row per
-- location (the physical room/bed, care_site_type = 'location') and one row per facility
-- (the site as a whole, care_site_type = 'facility'). Locations feed both
-- clinical__visit_occurrence.care_site_id and clinical__visit_detail.care_site_id;
-- facilities feed clinical__episode.care_site_id, an enrolment being registered at a
-- facility and never at a room. Each care site is denormalised with its parent facility.
-- Native UUID PK (D1). Sources only from bases/ (D10); OMOP column naming applied (D2).
-- See specs/dbt-model/ref__care_site.md for BL-001..BL-007.

with departments as (
    select * from {{ ref('departments') }}
),

locations as (
    select * from {{ ref('locations') }}
),

facilities as (
    select * from {{ ref('facilities') }}
),

-- organizational care unit (BL-001, BL-005)
department_sites as (
    select
        'department'   as care_site_type,
        d.id::varchar  as care_site_id,
        d.name         as care_site_name,
        d.code         as care_site_source_value,
        d.facility_id  as facility_id
    from departments d
),

-- physical care unit: individual location (room/bed) (BL-001, BL-006)
location_sites as (
    select
        'location'      as care_site_type,
        loc.id::varchar as care_site_id,
        loc.name        as care_site_name,
        loc.code        as care_site_source_value,
        loc.facility_id as facility_id
    from locations loc
),

-- the site as a whole (BL-001, BL-007). Its parent facility is itself, so the join below
-- denormalises the facility's own name and type onto it
facility_sites as (
    select
        'facility'    as care_site_type,
        f.id::varchar as care_site_id,
        f.name        as care_site_name,
        f.code        as care_site_source_value,
        f.id          as facility_id
    from facilities f
),

care_sites as (
    select * from department_sites
    union all
    select * from location_sites
    union all
    select * from facility_sites
)

select
    -- identity (BL-001) -- native UUID PK, no remap to OMOP integer IDs (D1)
    cs.care_site_id,
    cs.care_site_type,
    cs.care_site_name,
    cs.care_site_source_value,

    -- place of service: source value only. No place_of_service_concept_id — OMOP's Place
    -- of Service vocabulary has no standard concepts, so there is nothing domain-correct to
    -- populate; the source value is retained for deployments that map it downstream (BL-002)
    f.type as place_of_service_source_value,

    -- parent facility, denormalised onto the care site (BL-003)
    cs.facility_id as facility_id,
    f.name         as facility_name

from care_sites cs
-- left join so a care site whose facility is missing/soft-deleted is still emitted (BL-003)
left join facilities f on f.id = cs.facility_id

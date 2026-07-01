-- ref__care_site -- OMOP CARE_SITE wrapper. Heterogeneous by design: one row per Tamanu
-- department (the organizational care unit, care_site_type = 'department') AND one row per
-- location_group (the physical ward/area, care_site_type = 'ward'). Departments feed
-- clinical__visit_occurrence.care_site_id (always populated); wards feed
-- clinical__visit_detail.care_site_id (per-segment, and sparse — most Tamanu locations have
-- no ward). Each care site is denormalised with its parent facility. Native UUID PK (D1).
-- Sources only from bases/ (D10); OMOP column naming applied (D2).
-- See specs/dbt-model/ref__care_site.md for BL-001..BL-005.

with departments as (
    select * from {{ ref('departments') }}
),

location_groups as (
    select * from {{ ref('location_groups') }}
),

facilities as (
    select * from {{ ref('facilities') }}
),

place_of_service_map as (
    select * from {{ ref('map__omop_place_of_service') }}
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

-- physical care unit: ward/area (BL-001, BL-005)
ward_sites as (
    select
        'ward'          as care_site_type,
        lg.id::varchar  as care_site_id,
        lg.name         as care_site_name,
        lg.code         as care_site_source_value,
        lg.facility_id  as facility_id
    from location_groups lg
),

care_sites as (
    select * from department_sites
    union all
    select * from ward_sites
)

select
    -- identity (BL-001) -- native UUID PK, no remap to OMOP integer IDs (D1)
    cs.care_site_id,
    cs.care_site_type,
    cs.care_site_name,
    cs.care_site_source_value,

    -- place of service: concept shadow + retained source value (BL-002). Concept comes
    -- from the baseline map__omop_place_of_service (deployment-overridable); an unmapped
    -- facility type yields a NULL concept, never a wrong one
    pos.concept_id as place_of_service_concept_id,
    f.type         as place_of_service_source_value,

    -- parent facility, denormalised onto the care site (BL-003)
    cs.facility_id as facility_id,
    f.name         as facility_name

from care_sites cs
-- left join so a care site whose facility is missing/soft-deleted is still emitted (BL-003)
left join facilities f on f.id = cs.facility_id
left join place_of_service_map pos on pos.local_code = f.type

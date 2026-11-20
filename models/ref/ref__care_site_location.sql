-- ref__care_site_location -- the location grain of ref__care_site: one row per Tamanu location
-- (the physical room/bed) as a care site, denormalised with its parent facility, in
-- ref__care_site's columns. ref__care_site unions it with its other grains, and a consumer that
-- needs only location care sites, such as a visit's, reads it directly.
-- Keep it one select over the base models, with no with clause and no union: the planner then
-- folds it into the consumer's query and estimates a join on care_site_id from the locations
-- table, as one care site per row (BL-009).
-- See specs/dbt-model/ref__care_site.md for the BL clauses this model implements.

-- BL-006: every Tamanu location is a care site
select
    -- identity (BL-001) -- native UUID PK, no remap to OMOP integer IDs (D1)
    loc.id::varchar as care_site_id,
    'location' as care_site_type,
    loc.name as care_site_name,
    loc.code as care_site_source_value,
    -- BL-002: place of service as a source value only
    f.type as place_of_service_source_value,
    -- BL-008: the location's own facility, else its location group's facility
    coalesce(loc.facility_id, lg.facility_id) as facility_id,
    f.name as facility_name
from {{ ref('locations') }} loc
left join {{ ref('location_groups') }} lg on lg.id = loc.location_group_id
-- BL-003: left join so a location whose facility is missing or soft-deleted is still emitted
left join {{ ref('facilities') }} f on f.id = coalesce(loc.facility_id, lg.facility_id)

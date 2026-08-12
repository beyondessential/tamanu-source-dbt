-- ds__outpatient_visit -- Outpatient visits aggregated to (visit_detail_start_date,
-- yearmonth, facility, area, sex, age_group). An encounter is outpatient when its first
-- history segment's OMOP visit concept is 9202 (Outpatient Visit) -- covers clinic,
-- vaccination, and imaging (BL-002); visit_detail_start_date and area come from that
-- segment. Facility and area are resolved via bases/locations (inner) +
-- bases/location_groups (left) (BL-003). Additive count only, so it can be aggregated to
-- any period. See specs/dbt-model/ds__outpatient_visit.md for BL-001..BL-007.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

location_groups as (
    select * from {{ ref('location_groups') }}
),

-- outpatient intake encounters: the first history segment of each encounter whose OMOP
-- visit concept is 9202/Outpatient Visit (BL-002), enriched with facility from the
-- visit's location (BL-003), area name from the location's location_group (BL-003),
-- sex, and age at the visit (BL-004)
outpatient_encounters as (
    select
        vd.visit_detail_start_date,
        loc.facility_id as tamanu_facility_id,
        -- both sentinels trigger off the same location_group-lookup miss (no
        -- location_group assigned, or it was soft-deleted and no longer resolves in
        -- location_groups), so a real id never pairs with an 'Unknown' name or vice versa
        coalesce(lg.id, 'locationgroup-unknown') as location_group_id,
        coalesce(lg.name, 'Unknown') as location_group_name,
        pr.gender_source_value as sex,
        -- age in whole years at the visit; null year_of_birth -> null (Unknown age band).
        -- month_of_birth/day_of_birth are extracted from the same date_of_birth column in
        -- clinical__person, so they're populated whenever year_of_birth is.
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    join person pr
        on pr.person_id = vd.person_id
    -- inner join: encounters always carry a location_id in practice, so a failure to
    -- match here (the segment's location has since been soft-deleted) is a genuine
    -- anomaly, not an expected case -- excluded from the dataset rather than surfacing
    -- with a NULL tamanu_facility_id
    join locations loc
        on loc.id = vd.care_site_id
    -- left join: areas are sparse -- most locations have none -- so a missing
    -- location_group is the expected common case, handled by the sentinel pair below
    left join location_groups lg
        on lg.id = loc.location_group_id
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9202 -- OMOP 'Outpatient Visit'
),

-- band age once so the group-by keys on a plain column (BL-004)
outpatient_encounters_banded as (
    select
        visit_detail_start_date,
        -- visit's calendar month, 'YYYY-MM' (BL-007)
        to_char(visit_detail_start_date, 'YYYY-MM') as yearmonth,
        tamanu_facility_id,
        location_group_id,
        location_group_name,
        sex,
        {{ age_group__who_primary_classification('age_years') }} as age_group
    from outpatient_encounters
)

select
    b.visit_detail_start_date,
    b.yearmonth,
    b.tamanu_facility_id,
    -- BL-006: facility is emitted as the Tamanu id only. Translating it to a consumer's
    -- own identifier is a consumer-layer concern and is done there, not here.
    b.location_group_id,
    b.location_group_name,
    b.sex,
    b.age_group,
    count(*) as total_outpatient_visits
from outpatient_encounters_banded b
group by
    b.visit_detail_start_date,
    b.yearmonth,
    b.tamanu_facility_id,
    b.location_group_id,
    b.location_group_name,
    b.sex,
    b.age_group

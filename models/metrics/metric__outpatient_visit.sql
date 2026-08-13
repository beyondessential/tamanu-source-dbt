-- metric__outpatient_visit -- D5 metric view for the outpatient visit indicator registered in
-- documentations/metrics/*.yml: opd_visit.
--
-- Per-visit (subject) grain: one row per outpatient visit, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).

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

-- BL-003: an outpatient visit is the first history segment of an encounter whose OMOP
-- visit concept is 9202/Outpatient Visit -- covering clinic, vaccination, and imaging.
-- Facility, area and demographics are resolved off that same segment.
outpatient_visits as (
    select
        vd.visit_occurrence_id,
        vd.visit_detail_start_date,
        loc.facility_id,
        -- BL-007: both sentinels trigger off the same location_group-lookup miss (no
        -- location_group assigned, or it was soft-deleted and no longer resolves in
        -- location_groups), so a real id never pairs with an 'Unknown' name or vice versa
        coalesce(lg.id, 'locationgroup-unknown') as location_group_id,
        coalesce(lg.name, 'Unknown') as location_group_name,
        pr.gender_source_value as sex,
        -- age in whole years at the visit; null year_of_birth -> null
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    -- inner join: a visit whose patient bases/patients excludes (soft-deleted or merged
    -- away) is excluded from the metric entirely, not counted with blank demographics
    join person pr
        on pr.person_id = vd.person_id
    -- inner join: encounters always carry a location in practice, so a failure to match
    -- here (the segment's location has since been soft-deleted) is a genuine anomaly --
    -- excluded from the metric rather than surfacing with a NULL facility_id
    join locations loc
        on loc.id = vd.care_site_id
    -- left join: areas are sparse -- most locations have none -- so a missing
    -- location_group is the expected common case, handled by the sentinel pair above
    left join location_groups lg
        on lg.id = loc.location_group_id
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9202 -- OMOP 'Outpatient Visit'
)

-- D5 wide format: value_boolean is unused by this metric. period_end is NULL and
-- period_granularity is 'day' -- Tamanu tracks the visit date only, no arrival/departure
-- timestamps the way ED does (BL-002).
--
-- BL-008: facility is emitted as the Tamanu facility_id only. Translating it to a
-- consumer's own identifier is a consumer-layer concern and is done there (for Tupaia, in
-- the data table).
select
    'opd_visit'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    visit_detail_start_date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-003: one visit per row, so the count contribution is always 1. Additive, so
    -- a data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    location_group_id,
    location_group_name,
    sex,
    -- BL-004: age in whole years at the visit. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the consumer's data table
    -- bands it.
    age_years
from outpatient_visits

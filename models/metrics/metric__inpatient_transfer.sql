-- metric__inpatient_transfer -- D5 metric view for the inpatient transfer indicator registered
-- in documentations/metrics/*.yml: inpatient_transfer.
--
-- Per-transfer (subject) grain: one row per location change between two inpatient segments of
-- an encounter, value_numeric 1, so a consumer aggregates at whatever grain it needs.
--
-- See specs/dbt-model/metric__inpatient_transfer.md for the BL clauses this model implements.

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

-- BL-001: a segment moved into, paired with the segment before it in the same encounter. Both
-- are inpatient segments (concept 9201), so the move from an ED segment into the admission is
-- not a transfer, and an encounter's first segment has no preceding one. A clinician handover
-- opens a segment in the same location, which the location comparison below drops.
moves as (
    select
        cur.visit_detail_id,
        cur.visit_occurrence_id,
        cur.person_id,
        cur.visit_detail_start_datetime as moved__datetime,
        prev.care_site_id as from_location_id,
        cur.care_site_id as to_location_id,
        prev.department_id as from_department_id,
        cur.department_id as to_department_id
    from visit_detail cur
    join visit_detail prev
        on prev.visit_detail_id = cur.preceding_visit_detail_id
    where cur.visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
        and prev.visit_detail_concept_id = 9201
        and cur.care_site_id <> prev.care_site_id
),

transfers as (
    select
        m.visit_detail_id,
        m.visit_occurrence_id,
        m.moved__datetime,
        -- BL-004
        to_loc.facility_id,
        pr.gender_source_value as sex,
        -- BL-005: unbanded -- banding is the consumer's.
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    m.moved__datetime::date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years,
        -- BL-007
        m.from_location_id,
        m.to_location_id,
        from_loc.name as from_location_name,
        to_loc.name as to_location_name,
        coalesce(from_lg.name, 'Not recorded') as from_location_group_name,
        coalesce(to_lg.name, 'Not recorded') as to_location_group_name,
        -- BL-008
        m.from_department_id,
        m.to_department_id,
        -- BL-009: a location in no group against one in a group is a change of group.
        (from_loc.location_group_id is distinct from to_loc.location_group_id)
            as is_location_group_change,
        (m.from_department_id is distinct from m.to_department_id) as is_department_change
    from moves m
    join person pr
        on pr.person_id = m.person_id
    -- BL-001: both locations must resolve -- inner joins.
    join locations from_loc
        on from_loc.id = m.from_location_id
    join locations to_loc
        on to_loc.id = m.to_location_id
    left join location_groups from_lg
        on from_lg.id = from_loc.location_group_id
    left join location_groups to_lg
        on to_lg.id = to_loc.location_group_id
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'inpatient_transfer'::text as metric_id,
    null::text as variant_id,
    visit_detail_id::varchar as subject_id,
    -- BL-002: a move is a point event.
    moved__datetime as period_start,
    moved__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-003
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    age_years,
    -- BL-006
    visit_occurrence_id::varchar as visit_occurrence_id,
    from_location_id,
    to_location_id,
    from_location_name,
    to_location_name,
    from_location_group_name,
    to_location_group_name,
    from_department_id,
    to_department_id,
    is_location_group_change,
    is_department_change
from transfers

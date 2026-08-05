-- ds__opd_visits -- OPD visits aggregated to (date, facility, ward, sex, age_group).
-- An encounter is OPD when its first history segment is clinic or vaccination; date and
-- ward come from that segment. Additive count only, so it can be aggregated to any period.
-- See specs/dbt-model/ds__opd_visits.md for BL-001..BL-005.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

care_site as (
    select * from {{ ref('ref__care_site') }}
),

-- OPD intake encounters: the first history segment of each encounter when it is clinic or
-- vaccination (BL-002), enriched with facility + clinic name from the ward, sex, and age
-- at the visit (BL-003, BL-004)
opd_encounters as (
    select
        vd.visit_detail_start_date as date,
        cs.facility_id,
        coalesce(vd.care_site_id, 'locationgroup-Unknown') as location_group_id,
        coalesce(cs.care_site_name, 'Unknown') as location_group_name,
        pr.gender_source_value as sex,
        -- age in whole years at the visit; null year_of_birth -> null (Unknown age band)
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(
                        pr.year_of_birth,
                        coalesce(pr.month_of_birth, 1),
                        coalesce(pr.day_of_birth, 1)
                    )
                ))::int
        end as age_years
    from visit_detail vd
    join person pr
        on pr.person_id = vd.person_id
    left join care_site cs
        on cs.care_site_id = vd.care_site_id
        and cs.care_site_type = 'ward'
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_source_value in ('clinic', 'vaccination')
),

-- band age once so the group-by keys on a plain column (BL-004)
opd_encounters_banded as (
    select
        date,
        facility_id,
        location_group_id,
        location_group_name,
        sex,
        {{ opd_visit_age_group('age_years') }} as age_group
    from opd_encounters
)

select
    date,
    facility_id,
    location_group_id,
    location_group_name,
    sex,
    age_group,
    count(*) as total_opd_visits
from opd_encounters_banded
group by
    date,
    facility_id,
    location_group_id,
    location_group_name,
    sex,
    age_group

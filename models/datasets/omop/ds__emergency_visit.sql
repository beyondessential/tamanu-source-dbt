-- ds__emergency_visit -- Emergency department attendances aggregated to
-- (visit_detail_start_date, facility, area, sex, age_group). An encounter is an ED
-- attendance when its first history segment's OMOP visit concept is 9203 (Emergency Room
-- Visit) -- covers emergency, triage, and observation (BL-002); visit_detail_start_date
-- and area come from that segment. Additive count only, so it can be aggregated to any
-- period. See specs/dbt-model/ds__emergency_visit.md for BL-001..BL-006.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

care_site as (
    select * from {{ ref('ref__care_site') }}
),

-- emergency intake encounters: the first history segment of each encounter whose OMOP
-- visit concept is 9203/Emergency Room Visit (BL-002), enriched with facility from the
-- visit's location (BL-003), area name (BL-003), sex, and age at the attendance (BL-004)
emergency_encounters as (
    select
        vd.visit_detail_start_date,
        loc.facility_id as tamanu_facility_id,
        -- both sentinels trigger off the same area-lookup miss (no area assigned, or the
        -- area was soft-deleted and no longer resolves in ref__care_site), so a real id
        -- never pairs with an 'Unknown' name or vice versa
        coalesce(cs.care_site_id, 'locationgroup-unknown') as location_group_id,
        coalesce(cs.care_site_name, 'Unknown') as location_group_name,
        pr.gender_source_value as sex,
        -- age in whole years at the attendance; null year_of_birth -> null (Unknown age
        -- band). month_of_birth/day_of_birth are extracted from the same date_of_birth
        -- column in clinical__person, so they're populated whenever year_of_birth is.
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
    left join locations loc
        on loc.id = vd.location_id
    -- 'ward' is ref__care_site's label for location_group rows on this line; the entity is
    -- the area shown in Tamanu, hence the location_group_* column names below (BL-003)
    left join care_site cs
        on cs.care_site_id = vd.care_site_id
        and cs.care_site_type = 'ward'
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- band age once so the group-by keys on a plain column (BL-004)
emergency_encounters_banded as (
    select
        visit_detail_start_date,
        tamanu_facility_id,
        location_group_id,
        location_group_name,
        sex,
        {{ age_group__who_primary_classification('age_years') }} as age_group
    from emergency_encounters
)

{% set has_tupaia_mapping = var('integrations', {}).get('tupaia', {}).get('enabled', false) %}

select
    b.visit_detail_start_date,
    b.tamanu_facility_id,
    -- Tupaia facility id crosswalk: only joined when the deployment has set
    -- integrations.tupaia.enabled and supplied its own tupaia_facility_mapping seed
    -- (BL-006). Never referenced when the flag is unset, so this model still builds
    -- standalone in tamanu-source-dbt with no such seed present.
    -- Never NULL: this is the data_table_filter column, and Tupaia's default array filter
    -- (col = any(coalesce(:param, array[col]))) silently drops NULL rows, so an unmapped
    -- or unconfigured facility gets the literal 'Not available' instead.
    {% if has_tupaia_mapping %}
    coalesce(tm.tupaia_facility_id, 'Not available') as tupaia_facility_id,
    {% else %}
        'Not available' as tupaia_facility_id,
    {% endif %}
    b.location_group_id,
    b.location_group_name,
    b.sex,
    b.age_group,
    count(*) as total_emergency_visits
from emergency_encounters_banded b
{% if has_tupaia_mapping %}
left join {{ ref('tupaia_facility_mapping') }} tm
    on tm.tamanu_facility_id = b.tamanu_facility_id
{% endif %}
group by
    b.visit_detail_start_date,
    b.tamanu_facility_id,
    -- a constant needs no grouping, so this only appears here when it's a real column
    {% if has_tupaia_mapping %}
    coalesce(tm.tupaia_facility_id, 'Not available'),
    {% endif %}
    b.location_group_id,
    b.location_group_name,
    b.sex,
    b.age_group

-- ds__outpatient_visit -- Outpatient visits aggregated to (visit_detail_start_date,
-- facility, area, sex, age_group). An encounter is outpatient when its first history
-- segment's OMOP visit concept is 9202 (Outpatient Visit) -- covers clinic, vaccination,
-- and imaging (BL-002); visit_detail_start_date and area come from that segment. Facility
-- and area are resolved via bases/locations (inner) + bases/location_groups (left)
-- (BL-003). Additive count only, so it can be aggregated to any period. See
-- specs/dbt-model/ds__outpatient_visit.md for BL-001..BL-006.

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
        tamanu_facility_id,
        location_group_id,
        location_group_name,
        sex,
        {{ age_group__who_primary_classification('age_years') }} as age_group
    from outpatient_encounters
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
    count(*) as total_outpatient_visits
from outpatient_encounters_banded b
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

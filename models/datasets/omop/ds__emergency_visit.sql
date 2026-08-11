-- ds__emergency_visit -- Emergency department attendances aggregated to
-- (visit_detail_start_date, facility, area, sex, age_group, is_inpatient_admission). An
-- encounter is an ED attendance when its first history segment's OMOP visit concept is
-- 9203 (Emergency Room Visit) -- covers emergency, triage, and observation (BL-002);
-- visit_detail_start_date and area come from that segment. is_inpatient_admission flags
-- attendances whose encounter went on to inpatient admission (visit-level concept 262,
-- BL-007) -- every such encounter's intake segment is already an ED segment, and this
-- dataset's ordinary intake filter already includes it (BL-002). Facility and area are
-- surfaced by joining bases/locations and bases/location_groups directly at this layer
-- (BL-003) -- clinical__visit_detail.care_site_id is location-grained, so this dataset
-- resolves area for itself rather than reading it from the clinical layer. Additive count
-- only, so it can be aggregated to any period. See specs/dbt-model/ds__emergency_visit.md
-- for BL-001..BL-008.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
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

-- ED intake encounters: the first history segment of each encounter whose OMOP visit
-- concept is 9203/Emergency Room Visit (BL-002), enriched with facility and area name from
-- the segment's location (BL-003), sex, age at the attendance (BL-004), and the
-- inpatient-admission flag (BL-007)
emergency_encounters as (
    select
        vd.visit_detail_start_date,
        -- string period column at month grain, for Tupaia data tables: the transform layer
        -- runs alasql, which cannot bucket a date to a month, and the generator's date-range
        -- params key on string period columns (BL-008)
        to_char(vd.visit_detail_start_date, 'YYYY-MM') as yearmonth,
        loc.facility_id as tamanu_facility_id,
        -- both sentinels trigger off the same location_groups-lookup miss (the segment's
        -- location has no location_group, or that location_group was soft-deleted), so a
        -- real id never pairs with an 'Unknown' name or vice versa
        coalesce(lg.id, 'locationgroup-unknown') as location_group_id,
        coalesce(lg.name, 'Unknown') as location_group_name,
        pr.gender_source_value as sex,
        -- visit-level concept 262 is 'Emergency Room and Inpatient Visit': an admission
        -- encounter that passed through an ER phase. It is the only place 262 exists --
        -- clinical__visit_detail never carries it, since it is not an encounter_type
        -- lookup. No coalesce needed: clinical__visit_occurrence's own inner join to
        -- map__omop_visit_type means visit_concept_id is never NULL for any row that
        -- survives there, and the inner join below drops the whole row here if no such
        -- row exists at all -- see BL-006/BL-007.
        vo.visit_concept_id = 262 as is_inpatient_admission,
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
    -- inner join: clinical__visit_occurrence's own inner join to map__omop_visit_type
    -- (its BL-002) means a vo row exists only if the encounter's current encounter_type is
    -- mapped -- the same schema-drift risk as everywhere else this map is used, guarded by
    -- clinical__visit_occurrence's own completeness test, not a guarantee unique to this
    -- join
    join visit_occurrence vo
        on vo.visit_occurrence_id = vd.visit_occurrence_id
    -- vd.care_site_id is the segment's location itself (clinical__visit_detail BL-006);
    -- rejoin locations here to reach that location's location_group (BL-003). Inner join:
    -- encounters always have a location_id, so this only fails to match if the location was
    -- since soft-deleted -- a genuine anomaly worth excluding, unlike a missing area, which
    -- is the expected common case (hence left join below)
    join locations loc
        on loc.id = vd.care_site_id
    -- left join: areas are sparse -- most locations have none -- so a missing location_group
    -- is expected, not anomalous, and is handled by the sentinel pair above instead of
    -- dropping the row
    left join location_groups lg
        on lg.id = loc.location_group_id
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- band age once so the group-by keys on a plain column (BL-004)
emergency_encounters_banded as (
    select
        visit_detail_start_date,
        yearmonth,
        tamanu_facility_id,
        location_group_id,
        location_group_name,
        sex,
        is_inpatient_admission,
        {{ age_group__who_primary_classification('age_years') }} as age_group
    from emergency_encounters
)

{% set has_tupaia_mapping = var('integrations', {}).get('tupaia', {}).get('enabled', false) %}

select
    b.visit_detail_start_date,
    b.yearmonth,
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
    b.is_inpatient_admission,
    count(*) as total_emergency_visits
from emergency_encounters_banded b
{% if has_tupaia_mapping %}
left join {{ ref('tupaia_facility_mapping') }} tm
    on tm.tamanu_facility_id = b.tamanu_facility_id
{% endif %}
group by
    b.visit_detail_start_date,
    b.yearmonth,
    b.tamanu_facility_id,
    -- a constant needs no grouping, so this only appears here when it's a real column
    {% if has_tupaia_mapping %}
    coalesce(tm.tupaia_facility_id, 'Not available'),
    {% endif %}
    b.location_group_id,
    b.location_group_name,
    b.sex,
    b.age_group,
    b.is_inpatient_admission

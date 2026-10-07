-- metric__encounter -- D5 metric view for the encounter indicator registered in
-- documentations/metrics/*.yml: encounter.
--
-- Per-encounter (subject) grain: one row per encounter, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards.
--
-- Every attribute is the encounter's own, as clinical__visit_occurrence carries it -- the
-- location, department, encounter type and clinician on the encounter record, which Tamanu
-- updates as the patient moves -- plus the clinician's designations and the location's group. This is the attribution the report-layer datasets use
-- (encounters_core and the dataset macros). Counts match the encounter summary report except
-- where that report narrows its own population: it excludes sensitive facilities and drops
-- encounters with no history or no department, which are counted here.
--
-- The registry carries the definition and this model is its implementation.
-- See specs/dbt-model/metric__encounter.md for BL-001..BL-009.

with visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- BL-005: OMOP PROVIDER wrapper over bases/users. One row per user, so the join below cannot
-- fan out.
provider as (
    select * from {{ ref('ref__provider') }}
),

departments as (
    select * from {{ ref('departments') }}
),

location_groups as (
    select * from {{ ref('location_groups') }}
),

-- BL-008: each user's current designations, collapsed to one row per user before the join so
-- an encounter whose clinician holds several cannot fan out. Tamanu keeps no designation history,
-- so these are the designations held now, not at the encounter.
clinician_designations as (
    {{ user_designation_names() }}
),

encounters as (
    select
        vo.visit_occurrence_id,
        vo.visit_start_date,
        -- BL-003
        loc.facility_id,
        -- BL-004: the encounter's own type, and its department resolved to a name -- never
        -- NULL, so an array filter cannot drop the row
        vo.visit_source_value as encounter_type,
        -- BL-007: the encounter's OMOP Visit concept and its name, as
        -- clinical__visit_occurrence carries them
        vo.visit_concept_id,
        vo.visit_concept_name,
        coalesce(dept.name, 'Not recorded') as department,
        -- BL-005
        coalesce(prov.provider_name, 'Not recorded') as clinician,
        -- BL-008: the clinician's designations, comma-separated -- never NULL, so an array
        -- filter cannot drop the row
        coalesce(cd.designations, 'Not recorded') as clinician_designation,
        -- BL-009: the location group (area) of the encounter's location -- the same location
        -- the facility comes from. The id is NULL and the name 'Not recorded' where the location
        -- has no group
        lg.id as location_group_id,
        coalesce(lg.name, 'Not recorded') as location_group_name,
        pr.gender_source_value as sex,
        -- age in whole years at the encounter start, and the NULL rule lives in the macro
        {{ age_years('vo.visit_start_date', 'pr') }} as age_years
    from visit_occurrence vo
    -- BL-003: inner join -- an encounter whose location does not resolve is excluded rather
    -- than attributed to a NULL facility
    join locations loc
        on loc.id = vo.care_site_id
    join person pr
        on pr.person_id = vo.person_id
    left join provider prov
        on prov.provider_id = vo.provider_id
    left join clinician_designations cd
        on cd.user_id = prov.provider_id
    left join location_groups lg
        on lg.id = loc.location_group_id
    left join departments dept
        on dept.id = vo.department_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day'.
select
    -- BL-006
    'encounter'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002
    visit_start_date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-006: one encounter per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    visit_concept_id,
    visit_concept_name,
    department,
    clinician,
    clinician_designation,
    location_group_id,
    location_group_name,
    sex,
    age_years
from encounters

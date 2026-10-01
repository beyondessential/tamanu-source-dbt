-- metric__encounter -- D5 metric view for the encounter indicator registered in
-- documentations/metrics/*.yml: encounter.
--
-- Per-encounter (subject) grain: one row per encounter, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards.
--
-- Every attribute is the encounter's own, as clinical__visit_occurrence carries it -- the
-- location, department, encounter type and clinician on the encounter record, which Tamanu
-- updates as the patient moves. This is the attribution the report-layer datasets use
-- (encounters_core and the dataset macros). Counts match the encounter summary report except
-- where that report narrows its own population: it excludes sensitive facilities and drops
-- encounters with no history or no department, which are counted here.
--
-- The registry carries the definition and this model is its implementation.
-- See specs/dbt-model/metric__encounter.md for BL-001..BL-006.

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

encounters as (
    select
        vo.visit_occurrence_id,
        vo.visit_start_date,
        -- BL-003
        loc.facility_id,
        -- BL-004: the encounter's own type, and its department resolved to a name -- never
        -- NULL, so an array filter cannot drop the row
        vo.visit_source_value as encounter_type,
        coalesce(dept.name, 'Not recorded') as department,
        -- BL-005
        coalesce(prov.provider_name, 'Not recorded') as clinician,
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
    department,
    clinician,
    sex,
    age_years
from encounters

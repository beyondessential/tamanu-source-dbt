-- metric__encounter -- D5 metric view for the encounter indicator registered in
-- documentations/metrics/*.yml: encounter.
--
-- Per-encounter (subject) grain: one row per encounter, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards.
--
-- Every attribute is read off the encounter's first segment, the same intake segment
-- metric__outpatient_visit and metric__emergency_visit attribute a visit to. An encounter
-- that moves between settings is still one row, at the setting it started in, so a consumer
-- counts encounters once however many phases they pass through.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__encounter.md for BL-001..BL-007.

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- BL-006: OMOP PROVIDER wrapper over bases/users. One row per user, so the join below cannot
-- fan out.
provider as (
    select * from {{ ref('ref__provider') }}
),

departments as (
    select * from {{ ref('departments') }}
),

-- BL-002: the first segment of every encounter. clinical__visit_detail chains an encounter's
-- segments by preceding_visit_detail_id, and synthesises a whole-visit segment for an
-- encounter with no history, so every encounter has exactly one first segment.
first_segments as (
    select
        visit_occurrence_id,
        person_id,
        visit_detail_start_date,
        visit_detail_concept_id,
        visit_detail_source_value,
        care_site_id,
        provider_id,
        department_id
    from visit_detail
    where preceding_visit_detail_id is null
),

encounters as (
    select
        f.visit_occurrence_id,
        f.visit_detail_start_date,
        -- BL-004
        loc.facility_id,
        -- BL-005: the first segment's own encounter type, and the setting it groups to
        f.visit_detail_source_value as encounter_type,
        case f.visit_detail_concept_id
            when 9201 then 'Inpatient'
            when 9202 then 'Outpatient'
            when 9203 then 'Emergency'
            else 'Other'
        end as encounter_setting,
        -- BL-005: never NULL, so an array filter cannot drop the row
        coalesce(dept.name, 'Not recorded') as department,
        -- BL-006
        coalesce(prov.provider_name, 'Not recorded') as clinician,
        pr.gender_source_value as sex,
        -- age in whole years at the encounter start; the NULL rule lives in the macro
        {{ age_years('f.visit_detail_start_date', 'pr') }} as age_years
    from first_segments f
    -- BL-004: inner join -- a segment whose location does not resolve is excluded rather than
    -- attributed to a NULL facility
    join locations loc
        on loc.id = f.care_site_id
    join person pr
        on pr.person_id = f.person_id
    left join provider prov
        on prov.provider_id = f.provider_id
    left join departments dept
        on dept.id = f.department_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day'.
select
    -- BL-007
    'encounter'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-003
    visit_detail_start_date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-007: one encounter per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    encounter_setting,
    department,
    clinician,
    sex,
    age_years
from encounters

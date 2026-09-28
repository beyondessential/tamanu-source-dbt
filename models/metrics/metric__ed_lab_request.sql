-- metric__ed_lab_request -- D5 metric view for the ED-scoped lab test indicator registered in
-- documentations/metrics/emergency.yml: ed_lab_request (MAUI-6907).
--
-- Per-lab-test (subject) grain: one row per lab test requested while the patient's active
-- clinical__visit_detail segment was an emergency phase, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs. Sibling of metric__ed_imaging_request and
-- metric__ed_procedure. See specs/dbt-model/metric__ed_lab_request.md for BL-001..BL-008.
--
-- The registry carries the definition; this model is its implementation.

with lab_requests as (
    select * from {{ ref('lab_requests') }}
),

lab_tests as (
    select * from {{ ref('lab_tests') }}
),

lab_test_types as (
    select * from {{ ref('lab_test_types') }}
),

visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

departments as (
    select * from {{ ref('departments') }}
),

-- BL-001: one row per lab test on a request that was not deleted or entered in error,
-- including a request with no status
tests as (
    select
        lt.id as lab_test_id,
        lr.encounter_id as visit_occurrence_id,
        lr.requested_datetime,
        -- BL-003: completion is the request's publication
        coalesce(lr.status = 'published', false) as is_completed,
        lr.published_datetime,
        lt.lab_test_type_id
    from lab_tests lt
    join lab_requests lr
        on lr.id = lt.lab_request_id
    where lr.status is null
        or lr.status not in ('deleted', 'entered-in-error')
),

-- BL-002: the segment active at the request's own time, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('tests', 'lab_test_id', 'requested_datetime') }}
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'ed_lab_request'::text as metric_id,
    null::text as variant_id,
    t.lab_test_id::varchar as subject_id,
    -- BL-003
    t.requested_datetime as period_start,
    case when t.is_completed then t.published_datetime end as period_end,
    'minute'::text as period_granularity,
    -- BL-008
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    -- BL-005
    loc.facility_id,
    pr.gender_source_value as sex,
    t.is_completed,
    -- BL-006
    coalesce(ltt.code, 'Not recorded') as lab_test_code,
    coalesce(ltt.name, ltt.code, 'Not recorded') as lab_test,
    {{ age_years('t.requested_datetime::date', 'pr') }} as age_years,
    -- BL-007
    coalesce(dept.name, 'Not recorded') as department
from tests t
join active_segment s
    on s.lab_test_id = t.lab_test_id
join visit_detail vd
    on vd.visit_detail_id = s.visit_detail_id
-- BL-005: inner joins, so a test whose patient or segment location does not resolve is
-- excluded
join person pr
    on pr.person_id = vd.person_id
join locations loc
    on loc.id = vd.care_site_id
left join lab_test_types ltt
    on ltt.id = t.lab_test_type_id
left join departments dept
    on dept.id = vd.department_id
-- BL-004: the emergency phase only -- a test requested while the patient boards falls in the
-- admission segment and is not counted
where vd.visit_detail_concept_id = 9203

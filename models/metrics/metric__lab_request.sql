-- metric__lab_request -- D5 metric view for the lab_request indicator registered in
-- documentations/metrics/*.yml: lab_request (MAUI-6909).
--
-- Per-lab-test (subject) grain: one row per completed lab test carrying a reading,
-- value_numeric 1, so a consumer aggregates at whatever grain it needs. A lab request can
-- bundle several tests (e.g. a panel), so the grain is the individual test, not the request --
-- the same "bundle vs. line" distinction metric__pharmacy_order draws against pharmacy orders.
--
-- BL-001: sourced from clinical__measurement's lab branch, filtered to
-- measurement_type_source_value = 'lab' -- the same clinical-layer convention
-- metric__opd_procedure/metric__opd_imaging_request use over clinical__procedure_occurrence,
-- rather than reading bases/lab_requests directly. clinical__measurement already restricts
-- this branch to tests carrying a reading, under a request that was not withdrawn (its own
-- BL-009/BL-011), so every row here is a completed, resulted test -- there is no separate
-- is_completed column to emit.
--
-- The registry carries the definition; this model is its implementation.

with measurement as (
    select * from {{ ref('clinical__measurement') }}
    where measurement_type_source_value = 'lab'
),

encounters as (
    select * from {{ ref('encounters') }}
),

locations as (
    select * from {{ ref('locations') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

-- BL-002: department is the encounter's own department_id, not a request-specific one --
-- the same encounter-level (not segment-level) attribution metric__pharmacy_order uses,
-- since a lab request's department does not move mid-encounter the way a procedure's
-- location can.
departments as (
    select * from {{ ref('departments') }}
),

lab_tests as (
    select
        m.measurement_id,
        m.person_id,
        m.measurement_date,
        m.measurement_source_value,
        m.measurement_source_name,
        loc.facility_id,
        pr.gender_source_value as sex,
        {{ age_years('m.measurement_date', 'pr') }} as age_years,
        -- BL-002
        coalesce(dept.name, 'Not recorded') as department
    from measurement m
    -- inner join: a lab test whose encounter does not resolve is a genuine anomaly, excluded
    -- rather than attributed to a NULL facility -- the same convention every other metric in
    -- this file uses.
    join encounters e
        on e.id = m.visit_occurrence_id
    join locations loc
        on loc.id = e.location_id
    join person pr
        on pr.person_id = m.person_id
    left join departments dept
        on dept.id = e.department_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- lab test is recorded against a date, not a timestamp with a period to close, the same
-- convention metric__opd_procedure and metric__pharmacy_order use.
select
    'lab_request'::text as metric_id,
    null::text as variant_id,
    measurement_id::varchar as subject_id,
    measurement_date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-001: one test per row, so the count contribution is always 1. Additive, so a data
    -- table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-003: the test type as recorded, coalesced so the column is never NULL -- Tupaia
    -- exposes these as array filters, and an array filter drops a NULL row.
    coalesce(measurement_source_value, 'Not recorded') as lab_test_code,
    coalesce(
        measurement_source_name, measurement_source_value, 'Not recorded'
    ) as lab_test,
    age_years,
    department
from lab_tests

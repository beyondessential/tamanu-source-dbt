-- metric__ed_lab_order -- D5 metric view for the ED-scoped lab order indicator registered in
-- documentations/metrics/emergency.yml: ed_lab_order (MAUI-6907).
--
-- Per-order-line (subject) grain: one row per lab test panel ordered, and one per lab test
-- ordered outside a panel, while the patient's active clinical__visit_detail segment was an
-- emergency phase, value_numeric 1. A panel is one row however many tests it holds. Sibling of
-- metric__ed_imaging_request and metric__ed_pharmacy_order. See
-- specs/dbt-model/metric__ed_lab_order.md for BL-001..BL-009.
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

lab_test_panel_requests as (
    select * from {{ ref('lab_test_panel_requests') }}
),

lab_test_panels as (
    select * from {{ ref('lab_test_panels') }}
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

-- BL-001: a request that was not deleted or entered in error, including one with no status
live_requests as (
    select
        lr.id as lab_request_id,
        lr.encounter_id as visit_occurrence_id,
        lr.requested_datetime,
        -- BL-004: completion is the request's publication
        coalesce(lr.status = 'published', false) as is_completed,
        lr.published_datetime,
        lr.lab_test_panel_request_id
    from lab_requests lr
    where lr.status is null
        or lr.status not in ('deleted', 'entered-in-error')
),

-- BL-002: a request raised from a panel is one order line, labelled with the panel, however
-- many tests it holds
panel_orders as (
    select
        r.lab_request_id as order_id,
        r.visit_occurrence_id,
        r.requested_datetime,
        r.is_completed,
        r.published_datetime,
        true as is_panel,
        -- BL-007
        coalesce(ltp.code, 'Not recorded') as lab_order_code,
        coalesce(ltp.name, ltp.code, 'Not recorded') as lab_order
    from live_requests r
    left join lab_test_panel_requests ltpr
        on ltpr.id = r.lab_test_panel_request_id
    left join lab_test_panels ltp
        on ltp.id = ltpr.lab_test_panel_id
    where r.lab_test_panel_request_id is not null
),

-- BL-003: a request raised without a panel is one order line per test on it
test_orders as (
    select
        lt.id as order_id,
        r.visit_occurrence_id,
        r.requested_datetime,
        r.is_completed,
        r.published_datetime,
        false as is_panel,
        -- BL-007
        coalesce(ltt.code, 'Not recorded') as lab_order_code,
        coalesce(ltt.name, ltt.code, 'Not recorded') as lab_order
    from live_requests r
    join lab_tests lt
        on lt.lab_request_id = r.lab_request_id
    left join lab_test_types ltt
        on ltt.id = lt.lab_test_type_id
    where r.lab_test_panel_request_id is null
),

orders as (
    select * from panel_orders
    union all
    select * from test_orders
),

-- BL-005: the segment active at the request's own time, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('orders', 'order_id', 'requested_datetime') }}
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'ed_lab_order'::text as metric_id,
    null::text as variant_id,
    o.order_id::varchar as subject_id,
    -- BL-004
    o.requested_datetime as period_start,
    case when o.is_completed then o.published_datetime end as period_end,
    'minute'::text as period_granularity,
    -- BL-009
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    -- BL-006
    loc.facility_id,
    pr.gender_source_value as sex,
    o.is_completed,
    o.is_panel,
    o.lab_order_code,
    o.lab_order,
    {{ age_years('o.requested_datetime::date', 'pr') }} as age_years,
    -- BL-008
    coalesce(dept.name, 'Not recorded') as department
from orders o
join active_segment s
    on s.order_id = o.order_id
join visit_detail vd
    on vd.visit_detail_id = s.visit_detail_id
-- BL-006: inner joins, so an order whose patient or segment location does not resolve is
-- excluded
join person pr
    on pr.person_id = vd.person_id
join locations loc
    on loc.id = vd.care_site_id
left join departments dept
    on dept.id = vd.department_id
-- BL-005: the emergency phase only -- an order placed while the patient boards falls in the
-- admission segment and is not counted
where vd.visit_detail_concept_id = 9203

-- metric__lab_order -- D5 metric view for the lab_order indicator registered in
-- documentations/metrics/lab.yml: lab_order (MAUI-6837).
--
-- Per-order-line (subject) grain: one row per lab request raised from a panel, labelled with
-- the panel however many tests it holds, and one row per lab test on a request raised without
-- one. value_numeric 1, so a consumer aggregates at whatever grain it needs. The generic
-- counterpart to metric__ed_lab_order, carrying encounter_setting rather than scoping to a
-- single setting.
--
-- BL-004: the order side is read from bases/lab_requests and bases/lab_tests directly, NOT
-- from a clinical__ model. Decision (Juliana, 2026-09-23): the OMOP clinical models record
-- what has clinically happened, and an order is an intent, not an occurrence -- a test
-- requested and never resulted has no place in the clinical layer. D10-compliant: D10 forbids
-- reading public.*, not bases/.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__lab_order.md for BL-001..BL-012.

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

reference_data as (
    select * from {{ ref('reference_data') }}
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

-- BL-005: every request that was not deleted or entered in error, including one with no
-- status. Those two assert the order never happened. 'cancelled', 'invalidated', 'rejected'
-- and 'sample-not-collected' are KEPT -- each was genuinely ordered, and they are half the
-- requested-versus-completed story. request_status is emitted (BL-006) so a consumer counting
-- delivered results rather than orders placed can exclude them.
live_requests as (
    select
        lr.id as lab_request_id,
        lr.encounter_id,
        lr.requested_datetime,
        -- BL-006: completion is the request's publication. At order-line grain a row can span
        -- several tests, so the test's own completed_datetime cannot describe it.
        coalesce(lr.status = 'published', false) as is_completed,
        lr.published_datetime,
        coalesce(lr.status, 'Not recorded') as request_status,
        lr.lab_test_category_id,
        lr.lab_test_panel_request_id
    from lab_requests lr
    where lr.status is null
        or lr.status not in ('deleted', 'entered-in-error')
),

-- BL-002: a request raised from a panel is one order line, labelled with the panel, however
-- many tests it holds. Keyed on the request rather than the panel request: a panel spanning
-- several categories fans into one request each, and each carries its own status and
-- timestamps, so collapsing them would have no single value to report.
panel_orders as (
    select
        r.lab_request_id as order_id,
        r.lab_request_id,
        r.encounter_id,
        r.requested_datetime,
        r.is_completed,
        r.request_status,
        r.lab_test_category_id,
        true as is_panel,
        -- BL-007: emitted as recorded, coalesced so an array filter cannot drop the row
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
        r.lab_request_id,
        r.encounter_id,
        r.requested_datetime,
        r.is_completed,
        r.request_status,
        r.lab_test_category_id,
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

-- BL-010: the segment the patient was in when the order was placed -- the latest segment that
-- had already started by requested_datetime, clamped to the earliest when the order predates
-- every segment. The join carries no timestamp condition: the order by picks the as-of segment
-- where one qualifies and falls back to the earliest otherwise, and every encounter has at
-- least one segment (clinical__visit_detail BL-005), so it cannot drop a row.
--
-- The tie-breaks are split by direction on purpose: among segments sharing a start datetime
-- the as-of branch wants the last of them and the clamp branch the first, matching the
-- (start_datetime, visit_detail_id) order clinical__visit_detail chains its own segments by.
active_segment as (
    select distinct on (o.order_id)
        o.order_id,
        vd.visit_detail_id
    from orders o
    join visit_detail vd
        on vd.visit_occurrence_id = o.encounter_id
    order by
        o.order_id,
        (vd.visit_detail_start_datetime <= o.requested_datetime) desc,
        case when vd.visit_detail_start_datetime <= o.requested_datetime
                then vd.visit_detail_start_datetime
        end desc,
        case when vd.visit_detail_start_datetime > o.requested_datetime
                then vd.visit_detail_start_datetime
        end asc,
        case when vd.visit_detail_start_datetime <= o.requested_datetime
                then vd.visit_detail_id
        end desc,
        case when vd.visit_detail_start_datetime > o.requested_datetime
                then vd.visit_detail_id
        end asc
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'minute' --
-- an order runs from being placed to being published, so there is a period to close (BL-002).
select
    'lab_order'::text as metric_id,
    null::text as variant_id,
    o.order_id::varchar as subject_id,
    -- BL-002: when the order was placed
    o.requested_datetime as period_start,
    -- BL-002, BL-006: NULL until the request publishes
    case when o.is_completed then r.published_datetime end as period_end,
    'minute'::text as period_granularity,
    -- BL-001: one order line per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    loc.facility_id,
    -- BL-010: the segment's own encounter_type, finer than encounter_setting
    vd.visit_detail_source_value as encounter_type,
    -- BL-010: Outpatient covers the full OMOP 9202 -- clinic, imaging and vaccination. No
    -- emergency value: emergency lab ordering is metric__ed_lab_order's population, and a
    -- value here would let an emergency card be drawn from this metric.
    case vd.visit_detail_concept_id
        when 9201 then 'Inpatient'
        when 9202 then 'Outpatient'
        else 'Other'
    end as encounter_setting,
    pr.gender_source_value as sex,
    o.is_completed,
    -- BL-006: the request's lifecycle status as recorded. is_completed says the request
    -- published, not that its results still stand -- a request published and later invalidated
    -- reads completed here, so a card counting delivered results filters this.
    o.request_status,
    o.lab_request_id,
    -- BL-002: whether this line is a panel or a single test
    o.is_panel,
    coalesce(dept.name, 'Not recorded') as department,
    -- BL-007: the panel's identity for a panel line, the test type's for a single, as
    -- recorded and ungrouped
    o.lab_order_code,
    o.lab_order,
    -- BL-008: the request's category, one per request, as recorded
    coalesce(cat.name, 'Not recorded') as lab_test_category,
    -- BL-011: age in whole years at the order, unbanded -- the classification is the
    -- consumer's
    {{ age_years('o.requested_datetime::date', 'pr') }} as age_years
from orders o
join live_requests r
    on r.lab_request_id = o.lab_request_id
-- BL-010: inner join -- an order whose encounter resolves to no segment is excluded rather
-- than attributed to a NULL facility. An encounter_type missing from map__omop_visit_type
-- loses its segments entirely (clinical__visit_detail BL-003), which would drop the order;
-- guarded at source by data_test__map__omop_visit_type_coverage.
join active_segment s
    on s.order_id = o.order_id
join visit_detail vd
    on vd.visit_detail_id = s.visit_detail_id
join person pr
    on pr.person_id = vd.person_id
join locations loc
    on loc.id = vd.care_site_id
left join departments dept
    on dept.id = vd.department_id
left join reference_data cat
    on cat.id = o.lab_test_category_id

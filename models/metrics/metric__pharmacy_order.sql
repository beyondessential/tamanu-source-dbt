-- metric__pharmacy_order -- D5 metric view for the pharmacy order indicator registered in
-- documentations/metrics/*.yml: pharmacy_order.
--
-- Per-ordered-drug-line grain (subject_id = pharmacy_order_prescriptions.id), not per pharmacy
-- order and not per physical dispense event: one pharmacy order can bundle several drug lines,
-- and one drug line can be dispensed across 0..n medication_dispenses rows (partial fills). The
-- ordered line is the unit the pharmacy queue is actually worked against (MAUI-6807), so it is
-- the grain here.
--
-- is_completed splits the total into dispensed vs still-pending, so a consumer forms a
-- dispensing rate as sum(value_numeric) filter (where is_completed) / sum(value_numeric) at
-- whatever grain it groups to -- additive counts only, the ratio formed downstream, never
-- stored 0-100 (the metric__emergency_visit / MAUI-6787 convention).
--
-- Facility, department and setting are those of the clinical__visit_detail segment active when
-- the order was placed, not the encounter's current values -- the same attribution
-- metric__procedure and metric__lab_test use. A consumer scopes to one setting via a filter on
-- this one metric rather than needing a separate metric per setting.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__pharmacy_order.md for BL-001..BL-010.

with pharmacy_order_prescriptions as (
    select * from {{ ref('pharmacy_order_prescriptions') }}
),

pharmacy_orders as (
    select * from {{ ref('pharmacy_orders') }}
),

-- BL-001: drug identity is resolved from prescriptions/reference_data directly, not from
-- clinical__drug_exposure. That model's prescription branch keys drug_exposure_id off
-- encounter_prescriptions.id, a different id space from pharmacy_order_prescriptions'
-- prescription_id/ongoing_prescription_id (both of which reference prescriptions.id) -- joining
-- through clinical__drug_exposure would need re-deriving the encounter_prescriptions row, and
-- would silently lose drug identity for the ongoing-prescription branch, which has no
-- encounter_prescriptions row against *this* pharmacy order's encounter at all. Reading
-- prescriptions/reference_data directly is what clinical__drug_exposure's own branches do
-- underneath, and sidesteps both problems.
prescriptions as (
    select * from {{ ref('prescriptions') }}
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

-- BL-007: the segment's department, resolved to a name for metric_filters scoping.
departments as (
    select * from {{ ref('departments') }}
),

-- BL-002: one row per ordered drug line. Inner join to pharmacy_orders -- every
-- pharmacy_order_prescriptions row has one by construction (bases/pharmacy_order_prescriptions
-- already requires it to resolve), and bases/pharmacy_orders already requires a live encounter.
--
-- BL-003: prescription_id (encounter-based orders) and ongoing_prescription_id (send-to-
-- pharmacy orders) are mutually exclusive per pharmacy_order_prescriptions' own contract --
-- coalesce takes whichever is set.
drug_lines as (
    select
        pop.id as pharmacy_order_prescription_id,
        po.encounter_id as visit_occurrence_id,
        po.datetime as ordered_datetime,
        pop.is_completed,
        coalesce(pop.prescription_id, pop.ongoing_prescription_id) as prescription_id
    from pharmacy_order_prescriptions pop
    join pharmacy_orders po
        on po.id = pop.pharmacy_order_id
),

-- BL-008: the segment active at the order's own time, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('drug_lines', 'pharmacy_order_prescription_id', 'ordered_datetime') }}
),

orders as (
    select
        d.pharmacy_order_prescription_id,
        d.ordered_datetime,
        loc.facility_id,
        -- BL-010: the setting the order was placed in, from the resolved segment's OMOP Visit
        -- concept. 'Outpatient' is wider than encounter_type = 'clinic' -- 9202 also covers
        -- imaging- and vaccination-typed encounters. Scope a setting by this column and the
        -- scope holds when map__omop_visit_type gains an encounter type.
        --
        -- Do not add an emergency value here: emergency reporting reads
        -- metric__ed_pharmacy_order, and a value would let an emergency card be drawn from this
        -- one. Emergency-phase orders fall in 'Other'.
        case vd.visit_detail_concept_id
            when 9201 then 'Inpatient'
            when 9202 then 'Outpatient'
            else 'Other'
        end as encounter_setting,
        -- BL-010: the segment's own encounter_type, finer than the setting above
        vd.visit_detail_source_value as encounter_type,
        -- BL-006
        d.is_completed,
        pr.gender_source_value as sex,
        -- BL-004: a drug line whose prescription or medication reference does not resolve
        -- keeps its row on the 'Not recorded' fallback rather than disappearing
        coalesce(rd.code, 'Not recorded') as drug_source_value,
        coalesce(rd.name, 'Not recorded') as drug_source_name,
        -- BL-007
        coalesce(dept.name, 'Not recorded') as department
    from drug_lines d
    -- BL-008: inner join -- a drug line whose encounter does not resolve to a segment is
    -- excluded rather than attributed to a NULL facility. An encounter whose encounter_type is
    -- missing from map__omop_visit_type loses its segments entirely (clinical__visit_detail
    -- BL-003), guarded at source by data_test__map__omop_visit_type_coverage.
    join active_segment s
        on s.pharmacy_order_prescription_id = d.pharmacy_order_prescription_id
    join visit_detail vd
        on vd.visit_detail_id = s.visit_detail_id
    join person pr
        on pr.person_id = vd.person_id
    -- BL-009: facility is the segment's own location, not the pharmacy order's
    join locations loc
        on loc.id = vd.care_site_id
    left join prescriptions p
        on p.id = d.prescription_id
    left join reference_data rd
        on rd.id = p.medication_id
    left join departments dept
        on dept.id = vd.department_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- pharmacy order is placed against a calendar date, not a timestamp with a period to close.
select
    'pharmacy_order'::text as metric_id,
    null::text as variant_id,
    pharmacy_order_prescription_id::varchar as subject_id,
    ordered_datetime::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-005: one drug line per row, so the count contribution is always 1. Additive, so a
    -- consumer summing it is correct at every grain -- including the dispensing-rate ratio's
    -- numerator and denominator alike (BL-006).
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    encounter_setting,
    sex,
    is_completed,
    drug_source_value,
    drug_source_name,
    department
from orders

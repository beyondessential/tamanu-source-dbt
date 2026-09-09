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
-- The registry carries the definition; this model is its implementation.

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

encounters as (
    select * from {{ ref('encounters') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

-- BL-002: one row per ordered drug line. Inner join to pharmacy_orders -- every
-- pharmacy_order_prescriptions row has one by construction (bases/pharmacy_order_prescriptions
-- already requires it to resolve). Inner join to encounters for the same reason: bases/
-- pharmacy_orders already requires a live encounter to exist.
--
-- BL-003: prescription_id (encounter-based orders) and ongoing_prescription_id (send-to-
-- pharmacy orders) are mutually exclusive per pharmacy_order_prescriptions' own contract --
-- coalesce takes whichever is set. Left join to prescriptions/reference_data: a drug line whose
-- underlying prescription or medication reference does not resolve keeps its row rather than
-- disappearing, landing on the 'Not recorded' fallback below (BL-004).
orders as (
    select
        pop.id as pharmacy_order_prescription_id,
        po.datetime,
        po.facility_id,
        pop.is_completed,
        pr.gender_source_value as sex,
        coalesce(rd.code, 'Not recorded') as drug_source_value,
        coalesce(rd.name, 'Not recorded') as drug_source_name
    from pharmacy_order_prescriptions pop
    join pharmacy_orders po
        on po.id = pop.pharmacy_order_id
    join encounters e
        on e.id = po.encounter_id
    join person pr
        on pr.person_id = e.patient_id
    left join prescriptions p
        on p.id = coalesce(pop.prescription_id, pop.ongoing_prescription_id)
    left join reference_data rd
        on rd.id = p.medication_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- pharmacy order is placed against a calendar date, not a timestamp with a period to close.
select
    'pharmacy_order'::text as metric_id,
    null::text as variant_id,
    pharmacy_order_prescription_id::varchar as subject_id,
    datetime::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-005: one drug line per row, so the count contribution is always 1. Additive, so a
    -- consumer summing it is correct at every grain -- including the dispensing-rate ratio's
    -- numerator and denominator alike (BL-006 above).
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    is_completed,
    drug_source_value,
    drug_source_name
from orders

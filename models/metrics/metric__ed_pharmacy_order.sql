-- metric__ed_pharmacy_order -- D5 metric view for the ED-scoped pharmacy order indicator
-- registered in documentations/metrics/emergency.yml: ed_pharmacy_order (MAUI-6907).
--
-- Per-ordered-drug-line (subject) grain: one row per pharmacy order drug line placed while the
-- patient's active clinical__visit_detail segment was an emergency phase, value_numeric 1, so a
-- consumer aggregates at whatever grain it needs. The emergency-side counterpart of
-- metric__pharmacy_order. See specs/dbt-model/metric__ed_pharmacy_order.md for BL-001..BL-008.
--
-- The registry carries the definition; this model is its implementation.

with pharmacy_order_prescriptions as (
    select * from {{ ref('pharmacy_order_prescriptions') }}
),

pharmacy_orders as (
    select * from {{ ref('pharmacy_orders') }}
),

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

departments as (
    select * from {{ ref('departments') }}
),

-- BL-001: one row per ordered drug line
drug_lines as (
    select
        pop.id as pharmacy_order_prescription_id,
        po.encounter_id as visit_occurrence_id,
        po.datetime as ordered_datetime,
        pop.is_completed,
        -- BL-006: an encounter prescription and a send-to-pharmacy ongoing prescription are
        -- mutually exclusive on a drug line
        coalesce(pop.prescription_id, pop.ongoing_prescription_id) as prescription_id
    from pharmacy_order_prescriptions pop
    join pharmacy_orders po
        on po.id = pop.pharmacy_order_id
),

-- BL-002: the segment active at the order's own time, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('drug_lines', 'pharmacy_order_prescription_id', 'ordered_datetime') }}
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'ed_pharmacy_order'::text as metric_id,
    null::text as variant_id,
    d.pharmacy_order_prescription_id::varchar as subject_id,
    -- BL-003
    d.ordered_datetime::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-008
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    -- BL-005
    loc.facility_id,
    pr.gender_source_value as sex,
    d.is_completed,
    -- BL-006
    coalesce(rd.code, 'Not recorded') as drug_source_value,
    coalesce(rd.name, 'Not recorded') as drug_source_name,
    {{ age_years('d.ordered_datetime::date', 'pr') }} as age_years,
    -- BL-007
    coalesce(dept.name, 'Not recorded') as department
from drug_lines d
join active_segment s
    on s.pharmacy_order_prescription_id = d.pharmacy_order_prescription_id
join visit_detail vd
    on vd.visit_detail_id = s.visit_detail_id
-- BL-005: inner joins, so a drug line whose patient or segment location does not resolve
-- is excluded
join person pr
    on pr.person_id = vd.person_id
join locations loc
    on loc.id = vd.care_site_id
left join prescriptions p
    on p.id = d.prescription_id
left join reference_data rd
    on rd.id = p.medication_id
left join departments dept
    on dept.id = vd.department_id
-- BL-004: the emergency phase only -- an order placed while the patient boards falls in the
-- admission segment and is not counted
where vd.visit_detail_concept_id = 9203

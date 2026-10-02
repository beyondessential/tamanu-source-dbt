-- metric__ed_medication_dispense -- D5 metric view for the ed_medication_dispense indicator
-- registered in documentations/metrics/emergency.yml (MAUI-6907).
--
-- Per-dispense grain (subject_id = medication_dispenses.id): one row each time pharmacy hands
-- medication over against a drug line ordered during the emergency phase, dated to the day it was
-- dispensed. The emergency-side counterpart of metric__medication_dispense, and the dispensing
-- counterpart of metric__ed_pharmacy_order, scoped the same way.
--
-- See specs/dbt-model/metric__ed_medication_dispense.md for BL-001..BL-009.

with medication_dispenses as (
    select * from {{ ref('medication_dispenses') }}
),

pharmacy_order_prescriptions as (
    select * from {{ ref('pharmacy_order_prescriptions') }}
),

pharmacy_orders as (
    select * from {{ ref('pharmacy_orders') }}
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

-- BL-007
departments as (
    select * from {{ ref('departments') }}
),

-- BL-001: one row per dispense, carrying its drug line's order for the segment lookup
dispenses as (
    select
        md.id as medication_dispense_id,
        po.encounter_id as visit_occurrence_id,
        po.datetime as ordered_datetime,
        md.dispensed_at,
        md.quantity,
        md.medication_id
    from medication_dispenses md
    join pharmacy_order_prescriptions pop
        on pop.id = md.pharmacy_order_prescription_id
    join pharmacy_orders po
        on po.id = pop.pharmacy_order_id
),

-- BL-003: the segment active at the order's own time, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('dispenses', 'medication_dispense_id', 'ordered_datetime') }}
)

select
    -- BL-008
    'ed_medication_dispense'::text as metric_id,
    null::text as variant_id,
    d.medication_dispense_id::varchar as subject_id,
    -- BL-002: the day the medication was dispensed
    d.dispensed_at::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-008: one dispense per row
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    loc.facility_id,
    pr.gender_source_value as sex,
    -- BL-006: the dispensed medication
    coalesce(rd.code, 'Not recorded') as drug_source_value,
    coalesce(rd.name, 'Not recorded') as drug_source_name,
    {{ age_years('d.dispensed_at::date', 'pr') }} as age_years,
    -- BL-007
    coalesce(dept.name, 'Not recorded') as department,
    -- BL-009
    d.quantity::numeric as quantity
from dispenses d
-- BL-004: inner joins -- a dispense whose order does not resolve to a segment, patient or
-- location is excluded
join active_segment s
    on s.medication_dispense_id = d.medication_dispense_id
join visit_detail vd
    on vd.visit_detail_id = s.visit_detail_id
join person pr
    on pr.person_id = vd.person_id
join locations loc
    on loc.id = vd.care_site_id
left join reference_data rd
    on rd.id = d.medication_id
left join departments dept
    on dept.id = vd.department_id
-- BL-005: the emergency phase only -- a drug line ordered while the patient boards in the
-- admission segment is not counted, however late it is dispensed
where vd.visit_detail_concept_id = 9203

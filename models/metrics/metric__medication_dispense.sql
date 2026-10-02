-- metric__medication_dispense -- D5 metric view for the medication dispense indicator
-- registered in documentations/metrics/*.yml: medication_dispense.
--
-- Per-dispense grain (subject_id = medication_dispenses.id): one row each time pharmacy hands
-- medication over against an ordered drug line, dated to the day it was dispensed. One drug line
-- can be dispensed across several rows (partial fills and repeats), and each counts on its own
-- day. The dispensing counterpart of metric__pharmacy_order, which counts the ordered lines on the
-- day they were ordered.
--
-- Facility, department and setting are those of the clinical__visit_detail segment active when
-- the medication was dispensed, so the date and the place describe the same moment: a line ordered
-- in the emergency department and dispensed after admission is an inpatient dispense.
-- The setting is the segment's OMOP Visit concept, id and name, so an emergency card scopes this
-- model on 9203 rather than reading a separate one.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__medication_dispense.md for BL-001..BL-010.

-- BL-010: indexed for the data tables' reads -- every one ranges period_start, and the scoped
-- ones filter visit_detail_concept_id first. Applied where the model is a table (analytics
-- targets); a view carries none.
{{ config(
    indexes=[
        {'columns': ['visit_detail_concept_id', 'period_start']},
        {'columns': ['period_start']},
    ]
) }}

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

-- BL-007: the segment's department, resolved to a name for metric_filters scoping
departments as (
    select * from {{ ref('departments') }}
),

-- BL-005: the OMOP Visit concept name for the segment's encounter type
visit_types as (
    select * from {{ ref('map__omop_visit_type') }}
),

-- BL-001: one row per live dispense, carrying its encounter for the segment lookup. Inner joins --
-- bases/medication_dispenses already excludes soft-deleted dispenses, drug lines, orders and
-- encounters.
dispenses as (
    select
        md.id as medication_dispense_id,
        po.encounter_id as visit_occurrence_id,
        md.dispensed_at,
        md.quantity,
        md.medication_id
    from medication_dispenses md
    join pharmacy_order_prescriptions pop
        on pop.id = md.pharmacy_order_prescription_id
    join pharmacy_orders po
        on po.id = pop.pharmacy_order_id
),

-- BL-003: the segment active when the medication was dispensed, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('dispenses', 'medication_dispense_id', 'dispensed_at') }}
),

dispense_rows as (
    select
        d.medication_dispense_id,
        d.dispensed_at,
        d.quantity,
        loc.facility_id,
        -- BL-005: the setting at dispensing, as the segment's OMOP Visit concept
        vd.visit_detail_concept_id,
        vt.concept_name as visit_detail_concept_name,
        -- BL-005: the segment's own encounter_type, finer than the setting above
        vd.visit_detail_source_value as encounter_type,
        pr.gender_source_value as sex,
        -- BL-006: the dispensed medication, which differs from the prescribed one when pharmacy
        -- changed it at dispensing
        coalesce(rd.code, 'Not recorded') as drug_source_value,
        coalesce(rd.name, 'Not recorded') as drug_source_name,
        {{ age_years('d.dispensed_at::date', 'pr') }} as age_years,
        -- BL-007
        coalesce(dept.name, 'Not recorded') as department
    from dispenses d
    -- BL-003: inner join -- a dispense whose encounter has no segment is excluded rather than
    -- attributed to a NULL segment
    join active_segment s
        on s.medication_dispense_id = d.medication_dispense_id
    join visit_detail vd
        on vd.visit_detail_id = s.visit_detail_id
    -- BL-004: inner joins -- a dispense whose patient or segment location does not resolve is
    -- excluded rather than attributed to a NULL facility
    join person pr
        on pr.person_id = vd.person_id
    join locations loc
        on loc.id = vd.care_site_id
    left join reference_data rd
        on rd.id = d.medication_id
    -- BL-005: inner join -- clinical__visit_detail already keeps only segments whose
    -- encounter type the map covers, so this drops nothing
    join visit_types vt
        on vt.local_code = vd.visit_detail_source_value
    left join departments dept
        on dept.id = vd.department_id
)

-- D5 wide format: value_boolean is unused by this metric
select
    -- BL-008
    'medication_dispense'::text as metric_id,
    null::text as variant_id,
    medication_dispense_id::varchar as subject_id,
    -- BL-002: the day the medication was dispensed
    dispensed_at::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-008: one dispense per row
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    visit_detail_concept_id,
    visit_detail_concept_name,
    sex,
    drug_source_value,
    drug_source_name,
    age_years,
    department,
    -- BL-009: the dispensed quantity, a measure alongside the count
    quantity::numeric as quantity
from dispense_rows

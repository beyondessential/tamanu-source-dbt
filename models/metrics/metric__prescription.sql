-- metric__prescription -- D5 metric view for the prescription indicator registered in
-- documentations/metrics/pharmacy.yml: prescription.
--
-- Drug prescriptions written against an encounter, one row per encounter prescription, dated to the day the prescription was written.
--
-- Facility, department and setting are those of the clinical__visit_detail segment active at the
-- event's own timestamp -- the same attribution metric__pharmacy_order and
-- metric__medication_dispense use, so the pharmacy cards agree on where an event happened.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__prescription.md for BL-001..BL-008.

-- BL-008: indexed for the data tables' reads. Applied where the model is a table (analytics
-- targets); a view carries none.
{{ config(
    indexes=[
        {'columns': ['visit_detail_concept_id', 'period_start']},
        {'columns': ['period_start']},
    ]
) }}

with encounter_prescriptions as (
    select * from {{ ref('encounter_prescriptions') }}
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

-- BL-007: the segment's department, resolved to a name for scoping
departments as (
    select * from {{ ref('departments') }}
),

-- BL-001: one row per live encounter prescription. bases/encounter_prescriptions already
-- excludes soft-deleted rows, deleted encounters and the test patient, and bases/prescriptions
-- excludes soft-deleted prescriptions. Ongoing prescriptions that only exist on the patient record
-- (no encounter prescription) are out of scope: they have no encounter to take a setting from.
events as (
    select
        ep.id as event_id,
        ep.encounter_id as visit_occurrence_id,
        p.datetime as event_datetime,
        p.medication_id
    from encounter_prescriptions ep
    join prescriptions p
        on p.id = ep.prescription_id
),

-- BL-003: the segment active at the event's own time, with the first-segment clamp
active_segment as (
    {{ visit_detail__active_segment('events', 'event_id', 'event_datetime') }}
),

event_rows as (
    select
        e.event_id,
        e.event_datetime,
        loc.facility_id,
        -- BL-005: the setting, as the segment's OMOP Visit concept
        vd.visit_detail_concept_id,
        vd.visit_detail_concept_name,
        vd.visit_detail_source_value as encounter_type,
        pr.gender_source_value as sex,
        -- BL-006: falls back to 'Not recorded' rather than dropping the row
        coalesce(rd.code, 'Not recorded') as drug_source_value,
        coalesce(rd.name, 'Not recorded') as drug_source_name,
        {{ age_years('e.event_datetime::date', 'pr') }} as age_years,
        coalesce(dept.name, 'Not recorded') as department
    from events e
    -- BL-003: inner join -- an event whose encounter has no segment is excluded rather than
    -- attributed to a NULL segment
    join active_segment s
        on s.event_id = e.event_id
    join visit_detail vd
        on vd.visit_detail_id = s.visit_detail_id
    -- BL-004: inner joins -- an event whose patient or segment location does not resolve is
    -- excluded rather than attributed to a NULL facility
    join person pr
        on pr.person_id = vd.person_id
    join locations loc
        on loc.id = vd.care_site_id
    left join reference_data rd
        on rd.id = e.medication_id
    left join departments dept
        on dept.id = vd.department_id
)

-- D5 wide format: value_boolean is unused by this metric
select
    -- BL-008
    'prescription'::text as metric_id,
    null::text as variant_id,
    event_id::varchar as subject_id,
    -- BL-002: the date the prescription was written (`prescriptions.datetime`).
    event_datetime::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-008: one event per row
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
    department
from event_rows

-- metric__inpatient_admission -- D5 metric view for the inpatient admission and separation
-- indicators registered in documentations/metrics/*.yml: inpatient_admission,
-- inpatient_separation.
-- Spec: specs/dbt-model/metric__inpatient_admission.md (BL-001..BL-024).
--
-- Per-admission (subject) grain: one row per hospital admission or separation, value_numeric
-- 1, so a consumer aggregates at whatever grain it needs -- any subset of the
-- disaggregations, and any time grain from minute upwards (BL-011).
--
-- period_start/period_end bound the admission -- from becoming an inpatient to discharge
-- from hospital -- so a consumer computes length of stay as period_end - period_start
-- (BL-002). Grouping on period_start gives admissions in a period; separations in a period
-- are inpatient_separation (BL-019).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with inpatient_admission as (
    select * from {{ ref('int__inpatient_admission') }}
),

-- BL-024: the columns common to both metric_id's rows for one admission.
common as (
    select
        visit_occurrence_id,
        admission_start__datetime,
        visit_end__datetime,
        facility_id,
        sex,
        -- BL-004: age in whole years at admission.
        -- Unbanded -- an age classification is a presentation choice a deployment may set
        -- differently, so the consumer's data table bands it.
        age_years,
        -- BL-007: the ward (department) the patient was admitted to, as the Tamanu id.
        admission_ward_id,
        -- BL-012
        admission_source,
        -- BL-005: whether the admission arrived via the emergency department is a
        -- disaggregation column, so a consumer groups by it, filters to it, or ignores it.
        is_admitted_via_emergency,
        -- BL-013
        case
            when principal_diagnosis_code is null then 'Not recorded'
            else {{ diagnosis__icd10_chapter('principal_diagnosis_code') }}
        end as principal_diagnosis__icd10_chapter,
        -- BL-014
        discharge_disposition,
        -- BL-015: total length of stay as an inpatient, in minutes. Unbanded, for the same
        -- reason as age.
        length_of_stay__minutes,
        -- BL-016
        is_readmission_within_30_days,
        -- BL-017
        clinician,
        -- BL-018
        clinician_designation
    from inpatient_admission
)

-- BL-006: the model emits counts. A rate -- e.g. the share of admissions arriving via the ED
-- -- is sum(value_numeric) filter (where is_admitted_via_emergency) / sum(value_numeric),
-- formed at whatever grain the consumer groups to.

-- BL-002: every admission is emitted, including today's. A consumer needing whole periods
-- only applies its own date filter.

-- D5 wide format: value_boolean is unused by this metric.
--
-- BL-009: facility and ward are emitted as the Tamanu ids only. Translating them to a
-- consumer's own identifier is a consumer-layer concern and is done there, not here.
select
    'inpatient_admission'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002: minute grain, from becoming an inpatient to discharge from hospital.
    -- period_end is NULL while the encounter is open.
    admission_start__datetime as period_start,
    visit_end__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-011: one admission per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    age_years,
    admission_ward_id,
    admission_source,
    is_admitted_via_emergency,
    principal_diagnosis__icd10_chapter,
    discharge_disposition,
    length_of_stay__minutes,
    is_readmission_within_30_days,
    clinician,
    clinician_designation,
    null::integer as patient_days,
    null::boolean as is_same_day
from common

union all

-- BL-019: one inpatient_separation row for each admission that has closed (period_end not
-- null), value_numeric 1.
select
    'inpatient_separation'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-020: both bounds are the separation datetime -- the admission row's period_end.
    visit_end__datetime as period_start,
    visit_end__datetime as period_end,
    'minute'::text as period_granularity,
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    age_years,
    admission_ward_id,
    admission_source,
    is_admitted_via_emergency,
    principal_diagnosis__icd10_chapter,
    discharge_disposition,
    length_of_stay__minutes,
    is_readmission_within_30_days,
    clinician,
    clinician_designation,
    -- BL-021: whole days between the admission and separation dates, minimum 1 (AIHW METeOR
    -- 270045), both dates taken from the naive local timestamps. A separation date earlier
    -- than the admission date is corrupt data (OQ-005) -- the -1 sentinel surfaces it rather
    -- than a floor silently reading as an ordinary 1-day stay.
    case
        when visit_end__datetime::date < admission_start__datetime::date then -1
        else greatest(visit_end__datetime::date - admission_start__datetime::date, 1)
    end::integer as patient_days,
    -- BL-022: admitted and separated on the same calendar date.
    (visit_end__datetime::date = admission_start__datetime::date) as is_same_day
from common
where visit_end__datetime is not null

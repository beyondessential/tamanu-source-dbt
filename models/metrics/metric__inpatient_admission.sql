-- metric__inpatient_admission -- D5 metric view for the inpatient admission indicator
-- registered in documentations/metrics/*.yml: inpatient_admission.
-- Spec: specs/dbt-model/metric__inpatient_admission.md (BL-001..BL-015).
--
-- Per-admission (subject) grain: one row per hospital admission, value_numeric 1, so a
-- consumer aggregates at whatever grain it needs -- any subset of the disaggregations, and
-- any time grain from minute upwards (BL-011).
--
-- period_start/period_end bound the admission -- from becoming an inpatient to discharge
-- from hospital -- so a consumer computes length of stay as period_end - period_start
-- (BL-002). Grouping on period_start gives admissions in a period; grouping on period_end
-- gives discharges over the same rows -- there is no separate discharge metric_id.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with inpatient_admission as (
    select * from {{ ref('int__inpatient_admission') }}
)

-- BL-005: whether the admission arrived via the emergency department is a disaggregation
-- column, so a consumer groups by it, filters to it, or ignores it.

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
    -- BL-004: age in whole years at admission.
    -- Unbanded -- an age classification is a presentation choice a deployment may set
    -- differently, so the consumer's data table bands it.
    age_years,
    -- BL-007: the ward (department) the patient was admitted to, as the Tamanu id.
    admission_ward_id,
    -- BL-012
    admission_source,
    -- BL-005
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
    is_readmission_within_30_days
from inpatient_admission

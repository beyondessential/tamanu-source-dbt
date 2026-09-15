-- metric__immunisation_refusal -- D5 metric view for the immunisation refusal indicator
-- registered in documentations/metrics/*.yml: immunisation_refusal.
--
-- Per-attempt (subject) grain: one row per vaccination attempt recorded as not given,
-- value_numeric 1, so a consumer aggregates at whatever grain it needs -- any subset of the
-- disaggregations, and any time grain from day upwards (BL-003).
--
-- Sibling of metric__immunisation_dose: same disaggregation shape (antigen, dose position,
-- facility, sex, age cohort, patient village), plus the not-given reason. Out of grain of
-- that metric by design -- a NOT_GIVEN attempt is not a dose, so it cannot be a status
-- disaggregation added there without mixing two different numerators into one value_numeric
-- (see specs/dbt-model/metric__immunisation_dose.md, Open questions).
--
-- Shares its facility/antigen/dose-position/demographic resolution with
-- metric__immunisation_dose via int__vaccine_administration_attributes.
--
-- The registry carries the definition; this model is its implementation.

with observation as (
    select * from {{ ref('clinical__observation') }}
    where observation_type_source_value = 'vaccination not given'
),

vaccine_attributes as (
    select * from {{ ref('int__vaccine_administration_attributes') }}
),

-- BL-001: one row per vaccination attempt recorded as not given -- clinical__observation's
-- not-given branch already filters to status = 'NOT_GIVEN', so no further status filter is
-- needed here. Inner join -- an attempt whose facility or patient fails to resolve in the
-- shared attributes model is excluded rather than attributed to blank disaggregations
-- (BL-004, BL-008 there, same convention as metric__immunisation_dose). ob.observation_id is
-- the not-given branch's own id, the underlying vaccine_administrations id (1:1, so this
-- cannot fan out).
refusals as (
    select
        ob.observation_id,
        ob.observation_date,
        va.facility_id,
        va.disease,
        va.dose_label,
        va.sex,
        va.patient_location_id,
        va.not_given_reason,
        va.age_months
    from observation ob
    join vaccine_attributes va
        on va.administered_vaccine_id = ob.observation_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- not-given attempt is recorded against a calendar date, not a timestamp (BL-002).
--
-- facility_id and patient_location_id are emitted as Tamanu ids, untranslated -- translating
-- them to a consumer's own identifiers is a consumer-layer concern.
select
    'immunisation_refusal'::text as metric_id,
    null::text as variant_id,
    observation_id::varchar as subject_id,
    -- BL-002: a not-given attempt is a single-day point event -- period_start and period_end
    -- are the same date, since there is no span to measure.
    observation_date as period_start,
    observation_date as period_end,
    'day'::text as period_granularity,
    -- BL-003: one attempt per row, so the count contribution is always 1. Additive, so a
    -- consumer summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-005: the antigen the attempt addresses. 'Not recorded' when disease is blank, same
    -- fallback convention metric__immunisation_dose uses.
    coalesce(disease, 'Not recorded') as disease,
    -- BL-006: EPI age cohort, banded in-model, same convention and rationale as
    -- metric__immunisation_dose.
    {{ age_group__who_epi_schedule('age_months') }} as age_group__who_epi_schedule,
    -- BL-007: 'Not recorded' when the attempt carries no schedule (ad hoc/catch-up).
    coalesce(dose_label, 'Not recorded') as dose_label,
    -- BL-008: the patient's home village, not the event's facility. Not coalesced -- same
    -- rationale as metric__immunisation_dose.
    patient_location_id,
    -- BL-009: why the dose was not given. 'Not recorded' when neither a coded reason nor
    -- free-text reason was captured.
    coalesce(not_given_reason, 'Not recorded') as reason
from refusals

-- metric__immunisation_dose -- D5 metric view for the immunisation dose indicator registered
-- in documentations/metrics/*.yml: immunisation_dose.
--
-- Per-dose (subject) grain: one row per vaccine dose given, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards (BL-003). Numerator-only: the coverage percentage this feeds is
-- computed downstream against an externally supplied population estimate (BL-001).
--
-- Shares its facility/antigen/dose-position/demographic resolution with
-- metric__immunisation_refusal via int__vaccine_administration_attributes; the two differ in
-- which vaccine_administrations status they read and which canonical OMOP-lite fact
-- (clinical__drug_exposure vs clinical__observation) they take their identity from.
--
-- The registry carries the definition; this model is its implementation.

with drug_exposure as (
    select * from {{ ref('clinical__drug_exposure') }}
    where drug_exposure_type_source_value = 'vaccination'
),

vaccine_attributes as (
    select * from {{ ref('int__vaccine_administration_attributes') }}
),

-- BL-001: one row per vaccine dose given -- clinical__drug_exposure's vaccination branch
-- already filters to status = 'GIVEN', so no further status filter is needed here. Inner
-- join -- a dose whose facility or patient fails to resolve in the shared attributes model is
-- excluded rather than attributed to blank disaggregations (BL-004, BL-008 there). av.id is
-- the vaccination branch's own drug_exposure_id (1:1, so this cannot fan out).
doses as (
    select
        de.drug_exposure_id,
        de.drug_exposure_start_date,
        va.facility_id,
        va.disease,
        va.dose_label,
        va.sex,
        va.patient_location_id,
        va.age_months
    from drug_exposure de
    join vaccine_attributes va
        on va.administered_vaccine_id = de.drug_exposure_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- dose is recorded against a calendar date, not a timestamp (BL-002).
--
-- facility_id and patient_location_id are emitted as Tamanu ids, untranslated -- translating
-- them to a consumer's own identifiers is a consumer-layer concern.
select
    'immunisation_dose'::text as metric_id,
    null::text as variant_id,
    drug_exposure_id::varchar as subject_id,
    -- BL-002: a dose is a single-day point event -- period_start and period_end are the
    -- same date, since there is no span to measure.
    drug_exposure_start_date as period_start,
    drug_exposure_start_date as period_end,
    'day'::text as period_granularity,
    -- BL-003: one dose per row, so the count contribution is always 1. Additive, so a
    -- consumer summing it is correct at every grain -- the numerator of a coverage ratio,
    -- with the denominator (target population) supplied downstream.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-005: the antigen the dose addresses. 'Not recorded' when disease is blank, same
    -- fallback convention this metric family uses for its other disaggregations.
    coalesce(disease, 'Not recorded') as disease,
    -- BL-006: EPI age cohort, banded in-model -- unlike the unbanded age_years measure other
    -- metric__ models emit, the coverage ratio this numerator feeds is itself age-cohort
    -- specific (e.g. "doses given to children under 1 year"), so the band is part of the
    -- definition here, not a downstream presentation choice.
    {{ age_group__who_epi_schedule('age_months') }} as age_group__who_epi_schedule,
    -- BL-007: 'Not recorded' when the dose carries no schedule (ad hoc/catch-up).
    coalesce(dose_label, 'Not recorded') as dose_label,
    -- BL-008: the patient's home village, not the event's facility. NULL when the patient's
    -- own record carries no village -- deliberately not coalesced to a placeholder text
    -- value, since this is an id column, not a label, and a consumer joining it to
    -- ref__location needs a real id or a real NULL, not a sentinel string.
    patient_location_id
from doses

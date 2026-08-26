-- metric__encounter_diagnosis -- D5 metric view for the morbidity indicator registered in
-- documentations/metrics/*.yml: encounter_diagnosis.
--
-- Per-diagnosis (subject) grain: one row per recorded diagnosis, value_numeric 1, so a
-- consumer aggregates at whatever grain it needs -- any subset of the disaggregations, and
-- any time grain from day upwards (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).
-- See specs/dbt-model/metric__encounter_diagnosis.md for BL-001..BL-009.

with condition_occurrence as (
    select * from {{ ref('clinical__condition_occurrence') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- BL-003: the encounter-diagnosis branch of clinical__condition_occurrence. Certainty
-- 'disproven' and 'error' are already excluded upstream, by bases/encounter_diagnoses, so
-- this model inherits that rule rather than restating it -- a restatement here would drift
-- the day the base changes.
--
-- The program-registry branch is excluded: a condition tracked alongside an enrolment has no
-- encounter (clinical__condition_occurrence BL-008), so it carries neither a facility nor an
-- encounter type, and counting it here would mix comorbidity tracking into a morbidity count.
diagnoses as (
    select
        cco.condition_occurrence_id,
        cco.condition_start_date,
        cco.is_primary,
        loc.facility_id,
        -- BL-005: the encounter's own type -- lets a consumer scope morbidity to emergency,
        -- outpatient or inpatient activity without a separate metric per setting
        vo.visit_source_value as encounter_type,
        pr.gender_source_value as sex,
        -- BL-007: the diagnosis as recorded, coalesced so the column is never NULL. Tupaia
        -- exposes these as array filters, and an array filter drops a NULL row -- an
        -- undiagnosed-but-recorded row would silently disappear rather than show as unknown.
        coalesce(cco.condition_source_value, 'Not recorded') as diagnosis_code,
        coalesce(
            cco.condition_source_name, cco.condition_source_value, 'Not recorded'
        ) as diagnosis,
        coalesce(cco.condition_status_source_value, 'Not recorded') as diagnosis_certainty,
        -- age in whole years at the diagnosis; the NULL rule lives in the macro
        {{ age_years('cco.condition_start_date', 'pr') }} as age_years
    from condition_occurrence cco
    -- inner join: this is what excludes the registry branch, whose visit_occurrence_id is
    -- NULL. It resolves for every encounter diagnosis whose encounter_type is covered by
    -- map__omop_visit_type, which clinical__visit_occurrence inner-joins -- an uncovered
    -- type would drop the diagnosis rather than surface it (OQ-002)
    join visit_occurrence vo
        on vo.visit_occurrence_id = cco.visit_occurrence_id
    -- inner join: a diagnosis whose patient bases/patients excludes (soft-deleted or merged
    -- away) is excluded from the metric entirely, not counted with blank demographics
    join person pr
        on pr.person_id = cco.person_id
    -- BL-005: inner join -- encounters always carry a location in practice, so a failure to
    -- match here (the encounter's location has since been soft-deleted) is a genuine
    -- anomaly, excluded from the metric rather than surfacing with a NULL facility_id
    join locations loc
        on loc.id = vo.care_site_id
    where cco.condition_type_source_value = 'encounter diagnosis'
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' --
-- Tamanu records a diagnosis against a date, and a diagnosis is point-in-time, so there is
-- no period to close (BL-002).
--
-- BL-006: the diagnosis code and name are emitted raw and ungrouped. Classifying either one
-- -- an ICD-10 chapter, a block, a national grouping -- is a presentation choice a
-- deployment may set differently, so it happens at the deployment/data-table layer, the same
-- division as age_years (BL-008). macros/diagnosis__icd10_chapter.sql stays available for a
-- deployment to apply over diagnosis_code there.
select
    'encounter_diagnosis'::text as metric_id,
    null::text as variant_id,
    condition_occurrence_id::varchar as subject_id,
    condition_start_date as period_start,
    -- BL-002: a diagnosis is point-in-time, and neither source records a resolution date
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-004: one diagnosis per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    sex,
    diagnosis_code,
    diagnosis,
    diagnosis_certainty,
    is_primary,
    -- BL-008: age in whole years at the diagnosis. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the consumer's data table
    -- bands it.
    age_years
from diagnoses

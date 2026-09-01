-- metric__opd_diagnosis -- D5 metric view for the OPD-scoped diagnosis indicator registered in
-- documentations/metrics/*.yml: opd_diagnosis.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with condition_occurrence as (
    select * from {{ ref('clinical__condition_occurrence') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
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

-- BL-003
diagnosis_window as (
    select
        cco.condition_occurrence_id,
        cco.visit_occurrence_id,
        greatest(cco.condition_start_datetime, vo.visit_start_datetime) as window_start,
        vo.visit_end_datetime as window_end
    from condition_occurrence cco
    join visit_occurrence vo
        on vo.visit_occurrence_id = cco.visit_occurrence_id
    where cco.condition_type_source_value = 'encounter diagnosis'
),

diagnosis_opd_segment as (
    select distinct on (dw.condition_occurrence_id)
        dw.condition_occurrence_id,
        vd.care_site_id
    from diagnosis_window dw
    join visit_detail vd
        on vd.visit_occurrence_id = dw.visit_occurrence_id
        and vd.visit_detail_concept_id = 9202
        and vd.visit_detail_end_datetime >= dw.window_start
        and (dw.window_end is null or vd.visit_detail_start_datetime <= dw.window_end)
    order by dw.condition_occurrence_id, vd.visit_detail_start_datetime asc, vd.visit_detail_id asc
),

diagnoses as (
    select
        cco.condition_occurrence_id,
        cco.condition_start_date,
        cco.is_primary,
        loc.facility_id,
        pr.gender_source_value as sex,
        coalesce(cco.condition_source_value, 'Not recorded') as diagnosis_code,
        coalesce(
            cco.condition_source_name, cco.condition_source_value, 'Not recorded'
        ) as diagnosis,
        coalesce(cco.condition_status_source_value, 'Not recorded') as diagnosis_certainty,
        {{ age_years('cco.condition_start_date', 'pr') }} as age_years
    from condition_occurrence cco
    join diagnosis_opd_segment dos
        on dos.condition_occurrence_id = cco.condition_occurrence_id
    join person pr
        on pr.person_id = cco.person_id
    join locations loc
        on loc.id = dos.care_site_id
)

select
    'opd_diagnosis'::text as metric_id,
    null::text as variant_id,
    condition_occurrence_id::varchar as subject_id,
    condition_start_date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    diagnosis_code,
    diagnosis,
    diagnosis_certainty,
    is_primary,
    age_years
from diagnoses

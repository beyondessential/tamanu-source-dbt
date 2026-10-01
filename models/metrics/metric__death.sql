-- metric__death -- D5 metric view for the death indicator registered in
-- documentations/metrics/*.yml: death.
--
-- Per-death (subject) grain: one row per deceased patient, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs.
--
-- The population, the death record chosen for each patient, the facility and the encounter
-- the patient died in are those of ds__deaths, the dataset behind the deceased patients line
-- list, so a dashboard count and that report agree.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__death.md for BL-001..BL-007.

with patients as (
    select * from {{ ref('patients') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

departments as (
    select * from {{ ref('departments') }}
),

-- BL-002: the latest current death record per patient, preferring a finalised one -- the
-- same pick ds__deaths makes (its BL-010).
death_data as (
    select distinct on (patient_id) *
    from {{ ref('patient_death_data') }}
    where visibility_status = 'current'
    order by patient_id asc, is_final desc nulls last, id asc
),

-- BL-006: the encounter the patient died in -- the latest one whose span covers the date of
-- death, the same match ds__deaths makes.
encounters_with_death as (
    select distinct on (e.patient_id)
        e.patient_id,
        e.department_id
    from {{ ref('encounters') }} e
    join patients p
        on p.id = e.patient_id
        and p.date_of_death between e.start_datetime and e.end_datetime
    order by e.patient_id asc, e.end_datetime desc
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day'.
select
    -- BL-007
    'death'::text as metric_id,
    null::text as variant_id,
    p.id::varchar as subject_id,
    -- BL-003
    p.date_of_death::date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-007: one death per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    -- BL-004: the death record's facility. NULL where there is no death record or it names
    -- no facility.
    pdd.facility_id,
    pr.gender_source_value as sex,
    -- age in whole years at death; the NULL rule lives in the macro
    {{ age_years('p.date_of_death::date', 'pr') }} as age_years,
    -- BL-005: the death record's primary cause and where the death happened, never NULL
    coalesce(cause.name, 'Not recorded') as primary_cause,
    coalesce(cause.code, 'Not recorded') as primary_cause_code,
    case
        when pdd.id is null then 'Not recorded'
        when pdd.was_outside_health_facility then 'Outside health facility'
        else 'Health facility'
    end as place_of_death,
    coalesce(pdd.manner, 'Not recorded') as manner_of_death,
    -- BL-006
    coalesce(dept.name, 'Not recorded') as department
from patients p
join person pr
    on pr.person_id = p.id
left join death_data pdd
    on pdd.patient_id = p.id
left join reference_data cause
    on cause.id = pdd.primary_cause_condition_id
left join encounters_with_death ewd
    on ewd.patient_id = p.id
left join departments dept
    on dept.id = ewd.department_id
-- BL-001
where p.date_of_death is not null

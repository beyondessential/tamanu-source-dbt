-- metric__patient_condition -- D5 metric view for the patient condition indicator registered
-- in documentations/metrics/*.yml: patient_condition.
--
-- Per-condition-record (subject) grain: one row per patient ongoing condition, value_numeric 1.
-- A consumer counts patients with a distinct count over person_id, and prevalence at a date
-- from rows whose period covers it.
--
-- See specs/dbt-model/metric__patient_condition.md for the BL clauses this model implements.

with patient_conditions as (
    select * from {{ ref('patient_conditions') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

-- BL-001: bases/patient_conditions already drops deleted rows and the test patient. The inner
-- join to clinical__person drops a condition whose patient does not resolve.
conditions as (
    select
        pc.id,
        pc.patient_id,
        pc.recorded_datetime::date as recorded_date,
        pc.condition_id,
        -- BL-009: false when the flag is unset, and a resolution date only on a resolved row.
        coalesce(pc.is_resolved, false) as is_resolved,
        case when pc.is_resolved then pc.resolved_datetime::date end as resolved_date,
        pr.gender_source_value as sex,
        pr.location_id as patient_location_id,
        case
            when pr.year_of_birth is not null then
                make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
        end as date_of_birth,
        -- BL-008: the code only for the ICD-10 diagnosis list.
        case when rd.type = 'diagnosis' then rd.code end as condition_code,
        rd.name as condition_name
    from patient_conditions pc
    join person pr
        on pr.person_id = pc.patient_id
    left join reference_data rd
        on rd.id = pc.condition_id
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'patient_condition'::text as metric_id,
    null::text as variant_id,
    id::varchar as subject_id,
    -- BL-002: from the recorded date to the resolution date, NULL while ongoing.
    recorded_date as period_start,
    resolved_date as period_end,
    'day'::text as period_granularity,
    -- BL-003
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    -- BL-004: an ongoing condition is recorded against the patient, not a facility.
    null::varchar as facility_id,
    sex,
    -- BL-005: unbanded -- banding is the consumer's.
    extract(year from age(recorded_date, date_of_birth))::int as age_years,
    -- BL-006
    patient_location_id,
    -- BL-007
    patient_id as person_id,
    -- BL-008
    condition_id,
    condition_code,
    coalesce(condition_name, 'Not recorded') as condition_name,
    -- BL-009
    is_resolved,
    resolved_date
from conditions

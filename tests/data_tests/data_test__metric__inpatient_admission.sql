-- Singular tests for metric__inpatient_admission. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/metric__inpatient_admission.md.

with inpatient_admission as (
    select * from {{ ref('metric__inpatient_admission') }}
),

admission_rows as (
    select
        subject_id,
        period_end
    from inpatient_admission
    where metric_id = 'inpatient_admission'
),

separation_rows as (
    select
        subject_id,
        period_start,
        period_end,
        patient_days,
        is_same_day
    from inpatient_admission
    where metric_id = 'inpatient_separation'
),

-- AC-020: the separation rows are exactly the closed admissions, one each, by subject_id.
-- AC-001's grain test already guarantees uniqueness within a metric_id, so only membership is
-- checked here.
closed_admissions as (
    select subject_id from admission_rows
    where period_end is not null
),

ac_020 as (
    select
        coalesce(c.subject_id, s.subject_id) as subject_id,
        case
            when s.subject_id is null then 'AC-020 (closed admission missing its separation row)'
            else 'AC-020 (separation row has no closed admission)'
        end as failed_ac
    from closed_admissions c
    full outer join separation_rows s on s.subject_id = c.subject_id
    where c.subject_id is null or s.subject_id is null
),

-- AC-021: on inpatient_separation, period_start = period_end and is not null.
ac_021 as (
    select
        subject_id,
        'AC-021 (period_start and period_end not equal, or null, on a separation row)'
            as failed_ac
    from separation_rows
    where period_start is distinct from period_end or period_start is null
),

-- AC-022: patient_days and is_same_day are populated on every separation row, with
-- patient_days either the -1 corrupt-period sentinel or >= 1 (BL-021); both are NULL on every
-- admission row.
ac_022 as (
    select
        subject_id,
        'AC-022 (patient_days/is_same_day missing or invalid on a separation row)'
            as failed_ac
    from separation_rows
    where patient_days is null
        or is_same_day is null
        or (patient_days != -1 and patient_days < 1)

    union all

    select
        subject_id,
        'AC-022 (patient_days/is_same_day populated on an admission row)'
            as failed_ac
    from inpatient_admission
    where metric_id = 'inpatient_admission'
        and (patient_days is not null or is_same_day is not null)
)

select
    subject_id,
    failed_ac
from ac_020
union all
select
    subject_id,
    failed_ac
from ac_021
union all
select
    subject_id,
    failed_ac
from ac_022

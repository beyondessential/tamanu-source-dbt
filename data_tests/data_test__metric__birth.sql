-- Singular tests for metric__birth. One row per violation, tagged with the acceptance
-- criterion it breaks. See specs/dbt-model/metric__birth.md.

with birth as (
    select * from {{ ref('metric__birth') }}
),

-- AC-013: every subset row (low_birth_weight/preterm_birth/low_apgar_5min) has a
-- corresponding birth row for the same subject -- a subset can never be a birth the
-- population row itself dropped.
ac_013 as (
    select
        subset.subject_id,
        subset.metric_id,
        'AC-013' as failed_ac
    from birth subset
    left join birth pop
        on pop.subject_id = subset.subject_id and pop.metric_id = 'birth'
    where subset.metric_id != 'birth'
        and pop.subject_id is null
)

select
    subject_id,
    metric_id,
    failed_ac
from ac_013

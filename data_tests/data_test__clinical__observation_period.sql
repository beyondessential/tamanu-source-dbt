-- Singular tests for clinical__observation_period. One row per violation, tagged
-- with the acceptance criterion it breaks.
-- See specs/dbt-model/clinical__observation_period.md.

with observation_period as (
    select * from {{ ref('clinical__observation_period') }}
),

-- AC-006: the period must not end before it starts (BL-002)
ac_006 as (
    select
        observation_period_id,
        'AC-006' as failed_ac
    from observation_period
    where observation_period_end_date < observation_period_start_date
)

select observation_period_id, failed_ac from ac_006

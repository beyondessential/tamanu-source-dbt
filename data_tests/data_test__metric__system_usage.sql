-- Singular tests for metric__system_usage. One row per violation, tagged with
-- the acceptance criterion it breaks. See specs/dbt-model/metric__system_usage.md.

with usage as (
    select * from {{ ref('metric__system_usage') }}
),

-- AC-003: no non-positive counts (the no-data contract emits no row, never 0/negative).
ac_003 as (
    select
        metric_id,
        'AC-003' as failed_ac
    from usage
    where value_numeric is null
        or value_numeric <= 0
),

-- AC-005: active_users is national and not disaggregated by sex or facility (BL-003/BL-007).
ac_005 as (
    select
        metric_id,
        'AC-005' as failed_ac
    from usage
    where metric_id = 'active_users'
        and (sex is not null or facility_id is not null)
),

-- AC-007: no user counted without an event -- every month with an active_users
-- row must also have at least one canonical clinical_events row (BL-003).
ac_007 as (
    select
        'active_users' as metric_id,
        'AC-007' as failed_ac
    from usage au
    where au.metric_id = 'active_users'
        and not exists (
            select 1
            from usage ce
            where ce.metric_id = 'clinical_events'
                and ce.period_start = au.period_start
        )
)

select metric_id, failed_ac from ac_003
union all
select metric_id, failed_ac from ac_005
union all
select metric_id, failed_ac from ac_007

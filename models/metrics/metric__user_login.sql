-- metric__user_login -- D5 metric view for the user utilisation indicators registered in
-- documentations/metrics/user.yml: active_user and user_login.
--
-- See specs/dbt-model/metric__user_login.md for BL-001..BL-005.

with users_in_scope as (
    -- BL-001: every user but the system user. Which of the rest to include is the consumer's choice
    -- (the report and the Tupaia data table), using the columns exposed here.
    select
        id as user_id,
        role as role_id,
        visibility_status
    from {{ ref('users') }}
    where id <> '00000000-0000-0000-0000-000000000000'
),

-- BL-002: every designation in reference data. Which ones to show is a consumer choice.
user_designation as (
    select
        ud.user_id,
        ud.designation_id,
        rd.name as designation
    from {{ ref('user_designations') }} ud
    inner join {{ ref('reference_data') }} rd
        on rd.id = ud.designation_id and rd.type = 'designation'
),

-- Grain: one row per user x designation x facility; a consumer counts distinct users (BL-005).
user_scope as (
    select
        us.user_id,
        us.role_id,
        us.visibility_status,
        d.designation_id,
        d.designation,
        uf.facility_id
    from users_in_scope us
    inner join user_designation d on d.user_id = us.user_id
    inner join {{ ref('user_facilities') }} uf on uf.user_id = us.user_id
),

metric_rows as (
    select
        'active_user'::text as metric_id,
        user_id,
        role_id,
        visibility_status,
        null::text as event_id,
        date_trunc('day', current_timestamp)::timestamp as period_start,
        designation_id,
        designation,
        facility_id
    from user_scope

    union all

    select
        'user_login'::text as metric_id,
        s.user_id,
        s.role_id,
        s.visibility_status,
        la.id::text as event_id,
        -- BL-004: login day, in the deployment timezone.
        date_trunc('day', la.created_at at time zone '{{ var("timezone") }}') as period_start,
        s.designation_id,
        s.designation,
        s.facility_id
    from {{ ref('user_login_attempts') }} la
    inner join user_scope s on s.user_id = la.user_id
    where la.outcome = 'succeeded'
)

select
    metric_id,
    null::text as variant_id,
    user_id::varchar as subject_id,
    event_id,
    period_start,
    period_start as period_end,
    'day'::text as period_granularity,
    -- BL-003: one row per user (active_user) or per login (user_login).
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    role_id,
    visibility_status,
    designation_id,
    designation
from metric_rows

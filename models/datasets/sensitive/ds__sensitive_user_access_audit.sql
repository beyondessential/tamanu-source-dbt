with user_designations_agg as (
    select
        ud.user_id,
        string_agg(rd.name, ', ' order by rd.name) as designations
    from {{ source('tamanu', 'user_designations') }} ud
    left join {{ ref('reference_data') }} rd on rd.id = ud.designation_id
    where ud.deleted_at is null
    group by ud.user_id
),

role_permissions_agg as (
    select
        p.role_id,
        string_agg(
            distinct concat(p.verb, ':', p.noun),
            ', '
            order by concat(p.verb, ':', p.noun)
        ) as permissions
    from {{ source('tamanu', 'permissions') }} p
    where p.deleted_at is null
    group by p.role_id
),

sensitive_users as (
    select
        id,
        display_id,
        display_name,
        email,
        role,
        visibility_status
    from {{ source('tamanu', 'users') }}
    where deleted_at is null
)

select
    u.id as user_id,
    u.display_id as user_display_id,
    u.display_name as user_name,
    u.email as user_email,
    r.name as user_role,
    ud.designations as user_designations,
    rp.permissions as role_permissions,
    u.visibility_status
from sensitive_users u
left join {{ ref('roles') }} r on r.id = u.role
left join user_designations_agg ud on ud.user_id = u.id
left join role_permissions_agg rp on rp.role_id = u.role
where u.visibility_status = 'current'
order by u.display_name

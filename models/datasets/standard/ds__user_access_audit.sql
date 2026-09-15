with user_designations_agg as (
    -- BL-003: comma-separated, alphabetically sorted, deduplicated
    -- BL-005: label resolved from reference_data.name
    select
        ud.user_id,
        string_agg(distinct rd.name, ', ' order by rd.name) as designations
    -- BL-004: soft-deleted designation links filtered by base__user_designations
    from {{ ref('user_designations') }} ud
    left join {{ ref('reference_data') }} rd on rd.id = ud.designation_id
    group by ud.user_id
),

role_permissions_agg as (
    -- BL-006: verb:noun tokens, alphabetically sorted, deduplicated
    select
        p.role_id,
        string_agg(
            distinct concat(p.verb, ':', p.noun),
            ', '
            order by concat(p.verb, ':', p.noun)
        ) as permissions
    -- BL-007: soft-deleted permissions filtered by base__permissions
    from {{ ref('permissions') }} p
    group by p.role_id
)

-- BL-001: include only users with visibility_status = 'current'
-- BL-002: soft-deleted users excluded by base__users
select
    u.id as user_id,
    u.display_id as user_display_id,
    u.display_name as user_name,
    u.email as user_email,
    u.role as user_role_id,
    r.name as user_role,
    ud.designations as user_designations,
    rp.permissions as role_permissions,
    u.visibility_status
from {{ ref('users') }} u
left join {{ ref('roles') }} r on r.id = u.role
left join user_designations_agg ud on ud.user_id = u.id
-- BL-008: permissions are role-scoped. no user-level overrides
left join role_permissions_agg rp on rp.role_id = u.role
where u.visibility_status = 'current'

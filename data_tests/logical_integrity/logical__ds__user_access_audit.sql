-- AC-003 (BL-001): only current users are exposed
select 'AC-003' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where visibility_status != 'current'

union all

-- AC-005 (BL-008): if a role has permissions in base__permissions, the dataset must
-- aggregate them, and null role_permissions is only valid when the role itself has none
select 'AC-005' as failed_ac, d.user_id::text as user_id
from {{ ref('ds__user_access_audit') }} d
where d.role_permissions is null
    and exists (
        select 1 from {{ ref('permissions') }} p where p.role_id = d.user_role_id
    )

union all

-- AC-006 (BL-006): role_permissions tokens follow verb:Noun format, comma-space-separated.
-- Permissive on content (digits, hyphens, underscores allowed) but strict on shape.
select 'AC-006' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where role_permissions is not null
    and role_permissions !~ '^[a-z][a-zA-Z0-9_-]*:[A-Z][a-zA-Z0-9_-]*(, [a-z][a-zA-Z0-9_-]*:[A-Z][a-zA-Z0-9_-]*)*$'

union all

-- AC-007 (BL-003): user_designations is alphabetically sorted and deduplicated
select 'AC-007' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where user_designations is not null
    and string_to_array(user_designations, ', ') != (
        select array_agg(distinct elem order by elem)
        from unnest(string_to_array(user_designations, ', ')) as elem
    )

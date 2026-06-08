-- AC-003 (BL-001): only current users are exposed
select 'AC-003' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where visibility_status != 'current'

union all

-- AC-005 (BL-008): role_permissions is null only when user_role is null
select 'AC-005' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where role_permissions is null
    and user_role is not null

union all

-- AC-006 (BL-006): role_permissions matches verb:noun, comma-space-separated
select 'AC-006' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where role_permissions is not null
    and role_permissions !~ '^[a-z]+:[A-Z][A-Za-z]+(, [a-z]+:[A-Z][A-Za-z]+)*$'

union all

-- AC-007 (BL-003): user_designations is alphabetically sorted and deduplicated
select 'AC-007' as failed_ac, user_id::text as user_id
from {{ ref('ds__user_access_audit') }}
where user_designations is not null
    and string_to_array(user_designations, ', ') != (
        select array_agg(distinct elem order by elem)
        from unnest(string_to_array(user_designations, ', ')) as elem
    )

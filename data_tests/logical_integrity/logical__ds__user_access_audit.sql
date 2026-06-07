-- Test that all users in the user access audit have a valid user_id
-- and that the user_id matches a valid user in the users table
select
    uaa.user_id,
    uaa.user_name,
    uaa.user_role
from {{ ref('ds__user_access_audit') }} uaa
left join {{ ref('users') }} u on u.id = uaa.user_id
where
    uaa.user_id is null
    or u.id is null

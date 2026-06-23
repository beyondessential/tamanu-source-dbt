select
    user_name as "{{ translate_label('userName') }}",
    user_display_id as "{{ translate_label('userDisplayId') }}",
    user_email as "{{ translate_label('userEmail') }}",
    user_role as "{{ translate_label('userRole') }}",
    user_designations as "{{ translate_label('userDesignations') }}",
    role_permissions as "{{ translate_label('rolePermissions') }}"
from {{ ref('ds__user_access_audit') }}
-- BL-010: optional roleId parameter, null means no filter
-- BL-011: filter on role FK, not role name, so renames don't break audit history
where
    case
        when {{ parameter('roleId') }} is null then true
        else user_role_id = {{ parameter('roleId') }}
    end
-- BL-009: sort by user display name ascending
order by user_name

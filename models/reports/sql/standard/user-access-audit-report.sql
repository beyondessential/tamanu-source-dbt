select
    user_name as "{{ translate_label('userName') }}",
    user_display_id as "{{ translate_label('userDisplayId') }}",
    user_email as "{{ translate_label('userEmail') }}",
    user_role as "{{ translate_label('userRole') }}",
    user_designations as "{{ translate_label('userDesignations') }}",
    role_permissions as "{{ translate_label('rolePermissions') }}"
from {{ ref('ds__user_access_audit') }}
where
    case
        when {{ parameter('roleId') }} is null then true
        else user_role = (select name from {{ ref('roles') }} where id = {{ parameter('roleId') }})
    end
order by user_name

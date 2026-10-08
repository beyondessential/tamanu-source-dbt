-- See specs/reports/user-login-activity.md for BL-001..BL-009.
with eligible_users as (
    -- BL-002: activated users only. BL-003: no system user.
    select
        u.id as user_id,
        u.display_id,
        u.display_name,
        u.role as role_id,
        r.name as role_name
    from {{ ref('users') }} u
    left join {{ ref('roles') }} r on r.id = u.role
    where
        u.visibility_status = 'current'
        and u.id <> '00000000-0000-0000-0000-000000000000'
),

user_designations_agg as (
    select
        ud.user_id,
        string_agg(distinct rd.name, ', ' order by rd.name) as designations,
        array_agg(distinct ud.designation_id) as designation_ids
    from {{ ref('user_designations') }} ud
    inner join {{ ref('reference_data') }} rd
        on rd.id = ud.designation_id and rd.type = 'designation'
    group by ud.user_id
),

user_facilities_agg as (
    select
        uf.user_id,
        string_agg(distinct f.name, ', ' order by f.name) as facilities,
        array_agg(distinct uf.facility_id) as facility_ids
    from {{ ref('user_facilities') }} uf
    inner join {{ ref('facilities') }} f on f.id = uf.facility_id
    group by uf.user_id
),

logins as (
    -- BL-004: a successful login. BL-005: count within the range. BL-006: last login over all time.
    select
        user_id,
        max(created_at) as last_login,
        count(*) filter (
            where
                {{ to_user_selected_timezone('created_at') }}::date
                >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
                and {{ to_user_selected_timezone('created_at') }}::date
                <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
        ) as login_count
    from {{ ref('user_login_attempts') }}
    where outcome = 'succeeded'
    group by user_id
)

select
    eu.display_id as "{{ translate_label('userDisplayId') }}",
    eu.display_name as "{{ translate_label('userName') }}",
    eu.role_name as "{{ translate_label('userRole') }}",
    ud.designations as "{{ translate_label('userDesignations') }}",
    uf.facilities as "{{ translate_label('userAllowedFacilities') }}",
    to_char({{ to_user_selected_timezone('l.last_login') }}, '{{ var("datetime_format") }}') as "{{ translate_label('userLastLoginDate') }}",
    coalesce(l.login_count, 0) as "{{ translate_label('userNumberLogins') }}"
from eligible_users eu
left join user_designations_agg ud on ud.user_id = eu.user_id
left join user_facilities_agg uf on uf.user_id = eu.user_id
left join logins l on l.user_id = eu.user_id
where
    -- BL-007: facility filter. BL-008: role and designation filters. BL-009: dates never filter users.
    case
        when {{ parameter('facilityId') }} is null then true
        else {{ parameter('facilityId') }} = any(uf.facility_ids)
    end
    and case
        when {{ parameter('roleId') }} is null then true
        else eu.role_id = {{ parameter('roleId') }}
    end
    and case
        when {{ parameter('designationId') }} is null then true
        else {{ parameter('designationId') }} = any(ud.designation_ids)
    end
order by eu.display_name

select
    pal.patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    coalesce(village.name, 'Unknown') as village,
    pal.user_id as viewed_by_user_id,
    u.display_name as viewed_by_user,
    u.email as user_email,
    u.role as user_role,
    coalesce(f.name, 'Unknown') as viewed_at_facility,
    pal.logged_at as date_time_viewed,
    pal.facility_id,
    pal.is_mobile,
    pal.session_id,
    pal.device_id
from {{ ref('patients_access_logs') }} pal
join {{ ref('patients') }} p on p.id = pal.patient_id
join {{ ref('users') }} u on u.id = pal.user_id
left join {{ ref('facilities') }} f on f.id = pal.facility_id
left join {{ ref('reference_data') }} village on village.id = p.village_id and village.type = 'village'

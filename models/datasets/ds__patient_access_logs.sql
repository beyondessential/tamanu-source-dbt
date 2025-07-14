select
    lap.patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    village.name as village,
    lap.user_id as viewed_by_user_id,
    u.display_name as viewed_by_user,
    u.email as user_email,
    u.role as user_role,
    f.name as viewed_at_facility,
    lap.logged_at as date_time_viewed,
    lap.facility_id,
    lap.is_mobile,
    lap.session_id,
    lap.device_id
from {{ ref('patient_access_logs') }} lap
join {{ ref('patients') }} p on p.id = lap.patient_id
left join {{ ref('users') }} u on u.id = lap.user_id
left join {{ ref('facilities') }} f on f.id = lap.facility_id
left join {{ ref('reference_data') }} village on village.id = p.village_id

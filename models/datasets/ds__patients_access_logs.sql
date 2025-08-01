with grouped_access_logs as (
    select
        lap.patient_id,
        lap.user_id,
        lap.facility_id,
        date_trunc('minute', min(lap.logged_at)) as date_time_viewed,
        -- Take the first values for fields that might vary within the same minute
        lap.is_mobile,
        lap.session_id,
        lap.device_id
    from {{ ref('patients_access_logs') }} lap
    group by
        lap.patient_id,
        lap.user_id,
        lap.facility_id,
        lap.is_mobile,
        lap.session_id,
        lap.device_id
)

select
    gal.patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    village.name as village,
    gal.user_id as viewed_by_user_id,
    u.display_name as viewed_by_user,
    u.email as user_email,
    u.role as user_role,
    f.name as viewed_at_facility,
    gal.date_time_viewed,
    gal.facility_id,
    gal.is_mobile,
    gal.session_id,
    gal.device_id
from grouped_access_logs gal
join {{ ref('patients') }} p on p.id = gal.patient_id
left join {{ ref('users') }} u on u.id = gal.user_id
left join {{ ref('facilities') }} f on f.id = gal.facility_id
left join {{ ref('reference_data') }} village on village.id = p.village_id

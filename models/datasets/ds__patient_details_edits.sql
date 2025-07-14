select
    pcl.id as patient_id,
    pcl.display_id,
    pcl.first_name,
    pcl.last_name,
    pcl.date_of_birth,
    pcl.sex,
    pcl.village_id,
    coalesce(village.name, 'Unknown village') as village,
    pcl.updated_by_user_id as edited_by_user_id,
    coalesce(u.display_name, 'Unknown user') as edited_by_user,
    coalesce(u.email, 'Unknown email') as user_email,
    coalesce(u.role, 'Unknown role') as user_role,
    pcl.logged_at as edited_datetime
from {{ ref('patients_change_logs') }} pcl
left join {{ ref('users') }} u on u.id = pcl.updated_by_user_id
left join {{ ref('reference_data') }} village on village.id = pcl.village_id and village.type = 'village'

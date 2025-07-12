-- Patient details edits
select
    lcp.id as patient_id,
    lcp.display_id,
    lcp.first_name,
    lcp.last_name,
    lcp.date_of_birth,
    lcp.sex,
    lcp.village_id,
    coalesce(village.name, 'Unknown village') as village,
    lcp.updated_by_user_id as edited_by_user_id,
    coalesce(u.display_name, 'Unknown user') as edited_by_user,
    coalesce(u.email, 'Unknown email') as user_email,
    coalesce(u.role, 'Unknown role') as user_role,
    lcp.logged_at as edited_datetime
from {{ ref('logs_changes_patients') }} lcp
left join {{ ref('users') }} u on u.id = lcp.updated_by_user_id
left join {{ ref('reference_data') }} village on village.id = lcp.village_id and village.type = 'village'

union all

-- Patient additional data edits
select
    lcpad.patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    coalesce(village.name, 'Unknown village') as village,
    lcpad.updated_by_user_id as edited_by_user_id,
    coalesce(u.display_name, 'Unknown user') as edited_by_user,
    coalesce(u.email, 'Unknown email') as user_email,
    coalesce(u.role, 'Unknown role') as user_role,
    lcpad.logged_at as edited_datetime
from {{ ref('logs_changes_patient_additional_data') }} lcpad
left join {{ ref('patients') }} p on p.id = lcpad.patient_id
left join {{ ref('users') }} u on u.id = lcpad.updated_by_user_id
left join {{ ref('reference_data') }} village on village.id = p.village_id and village.type = 'village'

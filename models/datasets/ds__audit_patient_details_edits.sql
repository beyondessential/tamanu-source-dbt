with patient_edits as (
    -- Patient details edits
    select
        lcp.id as patient_id,
        lcp.display_id,
        lcp.first_name,
        lcp.last_name,
        lcp.date_of_birth,
        lcp.sex,
        lcp.village_id,
        lcp.updated_by_user_id,
        lcp.logged_at
    from {{ ref('logs_changes_patients') }} lcp

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
        lcpad.updated_by_user_id,
        lcpad.logged_at
    from {{ ref('logs_changes_patient_additional_data') }} lcpad
    left join {{ ref('patients') }} p on p.id = lcpad.patient_id
)

select
    pe.patient_id,
    pe.display_id,
    pe.first_name,
    pe.last_name,
    pe.date_of_birth,
    pe.sex,
    pe.village_id,
    village.name as village,
    pe.updated_by_user_id as edited_by_user_id,
    u.display_name as edited_by_user,
    u.email as user_email,
    u.role as user_role,
    pe.logged_at as edited_datetime
from patient_edits pe
left join {{ ref('users') }} u on u.id = pe.updated_by_user_id
left join {{ ref('reference_data') }} village on village.id = pe.village_id and village.type = 'village'
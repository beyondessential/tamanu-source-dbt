with data as (
    select
        pm.created_datetime as registration_date,
        p.id as registration_patient_id,
        pbd.patient_id as birth_patient_id,
        p.date_of_birth,
        age(pm.created_datetime, p.date_of_birth) < interval '6 months' as age_under_6m_at_registration
    from {{ ref("patients") }} p
    join {{ ref("patients_metadata") }} pm on pm.id = p.id
    left join {{ ref("patient_birth_data") }} pbd
        on pbd.patient_id = p.id
)
select
    registration_date,
    count(*) filter (where birth_patient_id is null) as total_patient_registrations,
    count(birth_patient_id) as total_birth_registrations,
    count(*) filter (where birth_patient_id is null and age_under_6m_at_registration) as total_incorrect_registrations_for_patient_under_6mth
from data
group by registration_date
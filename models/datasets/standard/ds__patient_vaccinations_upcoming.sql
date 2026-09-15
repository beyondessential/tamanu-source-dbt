select
    p.display_id,
    p.first_name,
    p.last_name,
    p.id as patient_id,
    p.date_of_birth,
    date_part('year', age(p.date_of_birth)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    pad.country_id,
    pvu.due_date,
    pvu.vaccine_category,
    pvu.vaccine_schedules_id,
    sv.label as vaccine_name,
    sv.dose_label as vaccine_schedule,
    pvu.status as vaccine_status
-- BL-001: one row per outstanding scheduled dose per patient
from {{ ref("patient_vaccinations_upcoming") }} pvu
join {{ ref("patients") }} p on p.id = pvu.patient_id
join {{ ref("vaccine_schedules") }} sv on sv.id = pvu.vaccine_schedules_id
left join {{ ref("reference_data") }} village on village.id = p.village_id
-- BL-003: current country of residence (patient_additional_data is one row per
-- patient, so this join does not fan out the vaccination rows)
left join {{ ref("patient_additional_data") }} pad on pad.patient_id = p.id
-- BL-002: exclude deceased patients
where p.date_of_death is null

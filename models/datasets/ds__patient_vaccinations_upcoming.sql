select
    p.display_id,
    p.first_name,
    p.last_name,
    p.id as patient_id,
    p.date_of_birth,
    date_part('year', age(p.date_of_birth)) as age,
    p.sex,
    pvu.due_date,
    pvu.vaccine_category,
    pvu.vaccine_schedules_id,
    sv.label as vaccine_name,
    sv.dose_label as vaccine_schedule,
    pvu.status as vaccine_status
from {{ ref("patient_vaccinations_upcoming") }} pvu
join {{ ref("patients") }} p on p.id = pvu.patient_id
join {{ ref("vaccine_schedules") }} sv on sv.id = pvu.vaccine_schedules_id
where p.date_of_death is null

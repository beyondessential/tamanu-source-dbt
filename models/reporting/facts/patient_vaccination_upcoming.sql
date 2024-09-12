SELECT
    patient_id,
    scheduled_vaccine_id AS vaccine_schedules_id,
    vaccine_category,
    vaccine_id,
    due_date,
    days_till_due,
    status
FROM {{ source("tamanu", "upcoming_vaccinations") }}

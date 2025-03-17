select
    patient_id,
    scheduled_vaccine_id as vaccine_schedules_id,
    vaccine_category,
    vaccine_id,
    due_date::date,
    days_till_due,
    status
from {{ source("tamanu", "upcoming_vaccinations") }}
where patient_id != '{{ var("test_patient") }}'

select
    s.id,
    s.until_date,
    s.interval,
    s.days_of_week,
    s.frequency,
    s.nth_weekday,
    s.occurrence_count,
    s.is_fully_generated
from {{ source("tamanu", "appointment_schedules") }} s
join {{ source("tamanu", "appointments") }} a on a.schedule_id = s.id
where s.deleted_at is null
    and a.patient_id != '{{ var("test_patient") }}'

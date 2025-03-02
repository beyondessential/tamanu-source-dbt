select
    until_date, 
    interval,
    days_of_week
from {{ source("tamanu", "appointment_schedules") }} s
join {{ source("tamanu", "appointments") }} a on a.schedule_id = s.id
where s.deleted_at is null
    and a.patient_id != '{{ var("test_patient") }}'
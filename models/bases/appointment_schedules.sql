-- May include appointment schedules for the test patient.
select
    s.id,
    s.until_date::date as until_date,
    s.interval,
    s.days_of_week,
    s.frequency,
    s.nth_weekday,
    s.occurrence_count,
    s.is_fully_generated
from {{ source("tamanu", "appointment_schedules") }} s
where s.deleted_at is null

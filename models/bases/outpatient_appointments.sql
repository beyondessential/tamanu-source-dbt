select
    a.id,
    a.start_time::timestamp as start_datetime,
    a.end_time::timestamp as end_datetime,
    a.patient_id,
    a.clinician_id,
    a.encounter_id,
    a.schedule_id,
    a.location_group_id,
    a.appointment_type_id,
    a.is_high_priority,
    a.status,
    s.until_date::date as until_date,
    s.interval,
    s.days_of_week,
    s.frequency,
    s.nth_weekday,
    s.occurrence_count,
    s.is_fully_generated,
    s.generated_until_date,
    s.cancelled_at_date
from {{ source("tamanu", "appointments") }} a
left join {{ source("tamanu", "appointment_schedules") }} s on s.id = a.schedule_id
where a.deleted_at is null
    and a.patient_id != '{{ var("test_patient") }}'
    and a.appointment_type_id notnull

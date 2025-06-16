select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(a.start_datetime::date, p.date_of_birth)) as age,
    p.sex,
    vil.id as village_id,
    vil.name as village,
    billing.id as billing_type_id,
    billing.name as billing_type,
    a.start_datetime as appointment_start_datetime,
    a.end_datetime as appointment_end_datetime,
    a.appointment_type_id,
    at.name as appointment_type,
    a.is_high_priority,
    a.status as appointment_status,
    u.id as clinician_id,
    u.display_name as clinician,
    lg.id as location_group_id,
    lg.name as location_group,
    a.schedule_id,
    a.until_date as until_date,
    a.interval as schedule_interval,
    a.days_of_week as schedule_days_of_week,
    a.frequency as schedule_frequency,
    a.nth_weekday as schedule_nth_weekday,
    a.occurrence_count as schedule_occurrence_count,
    a.is_fully_generated as schedule_is_fully_generated,
    a.generated_until_date as schedule_generated_until_date,
    a.cancelled_at_date as schedule_cancelled_at_date
from {{ ref('outpatient_appointments') }} a
join {{ ref('patients') }} p on p.id = a.patient_id
left join {{ ref('users') }} u on u.id = a.clinician_id
left join {{ ref('location_groups') }} lg on lg.id = a.location_group_id
left join {{ ref('patient_additional_data') }} pd on pd.patient_id = p.id
left join {{ ref('reference_data') }} billing on billing.id = pd.patient_billing_type_id
left join {{ ref('reference_data') }} vil on vil.id = p.village_id
left join {{ ref('reference_data') }} at on at.id = a.appointment_type_id
order by a.start_datetime

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(a.start_datetime, p.date_of_birth)) as age,
    p.sex,
    coalesce(pd.primary_contact_number, pd.secondary_contact_number) as contact_number,
    vil.id as village_id,
    vil.name as village,
    billing.id as billing_type_id,
    billing.name as billing_type,
    a.start_datetime as appointment_start_datetime,
    a.end_datetime as appointment_end_datetime,
    a.appointment_type_id,
    apt.name as appointment_type,
    a.status as appointment_status,
    u.id as clinician_id,
    u.display_name as clinician,
    lg.id as location_group_id,
    lg.name as location_group,
    a.priority,
    a.schedule_id,
    a.until_date,
    a.interval,
    a.days_of_week,
    a.frequency,
    a.nth_weekday
from {{ ref('outpatient_appointments') }} a
join {{ ref('patients') }} p on p.id = a.patient_id
left join {{ ref('users') }} u on u.id = a.clinician_id
left join {{ ref('location_groups') }} lg on lg.id = a.location_group_id
left join {{ ref('patient_additional_data') }} pd on pd.patient_id = p.id
left join {{ ref('reference_data') }} billing on billing.id = pd.patient_billing_type_id
left join {{ ref('reference_data') }} vil on vil.id = p.village_id
left join {{ ref('reference_data') }} apt on apt.id = a.appointment_type_id
where a.appointment_type_id notnull
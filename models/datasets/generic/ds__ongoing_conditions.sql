select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pc.recorded_datetime, p.date_of_birth)) as age,
    initcap(p.sex::text) as sex,
    village.name as village,
    village.id as village_id,
    conditions.name as condition,
    conditions.id as condition_id,
    pc.recorded_datetime,
    clinician.id as clinician_id,
    clinician.display_name as clinician,
    case when pc.is_resolved then pc.resolved_datetime end as date_resolved,
    case when pc.is_resolved then resolving_clinician.display_name end as clinician_resolving
from {{ ref('patient_conditions') }} pc
join {{ ref('patients') }} p on p.id = pc.patient_id
join {{ ref('reference_data') }} conditions on conditions.id = pc.condition_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('users') }} clinician on clinician.id = pc.recorded_by_id
left join {{ ref('users') }} resolving_clinician
    on resolving_clinician.id = pc.resolved_by_id
order by pc.recorded_datetime

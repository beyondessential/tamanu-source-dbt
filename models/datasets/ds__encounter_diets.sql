with diets as (
    select
        ed.encounter_id,
        string_agg(
            rd.name, ', '
            order by rd.name
        ) as diets
    from {{ ref('encounter_diets') }} ed
    join {{ ref('reference_data') }} rd
        on rd.id = ed.diet_id
    group by ed.encounter_id
),

allergies as (
    select
        pa.patient_id,
        string_agg(
            rd.name, ', '
            order by rd.name
        ) as allergies 
    from {{ ref('patient_allergies') }} pa
    join {{ ref('reference_data') }} rd
        on rd.id = pa.allergy_id
    group by pa.patient_id
)

select
    e.id as encounter_id,
    p.id as patient_id,
    p.display_id,
    concat(p.first_name, ' ', p.last_name) as patient_name,
    e.start_datetime,
    case
        when age(current_date, p.date_of_birth) < interval '8 days'
            then concat(extract(day from age(current_date, p.date_of_birth)), ' days')
        when age(current_date, p.date_of_birth) >= interval '8 days'
            and age(current_date, p.date_of_birth) < interval '1 month'
            then concat(extract(week from age(current_date, p.date_of_birth)), ' weeks')
        when age(current_date, p.date_of_birth) >= interval '1 month'
            and age(current_date, p.date_of_birth) < interval '2 years'
            then concat(extract(month from age(current_date, p.date_of_birth)), ' months')
        when age(current_date, p.date_of_birth) >= interval '2 years'
            then concat(extract(year from age(current_date, p.date_of_birth)), ' years')
    end as age,
    l.id as location_id,
    l.name as location,
    lg.id as location_group_id,
    lg.name as location_group,
    d.diets,
    a.allergies
from {{ ref('encounters') }} e
join {{ ref('patients') }} p
    on p.id = e.patient_id
join {{ ref('locations') }} l
    on l.id = e.location_id
join {{ ref('location_groups') }} lg
    on lg.id = l.location_group_id
left join diets d
    on d.encounter_id = e.id
left join allergies a
    on a.patient_id = p.id
where e.end_datetime is null

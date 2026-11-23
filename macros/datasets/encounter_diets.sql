{% macro encounter_diets_dataset(network=none) %}

with diets as (
    select
        ed.encounter_id,
        string_agg(
            rd.name, ', '
            order by rd.name
        ) as diets
    from {{ partition_ref('encounter_diets', network) }} ed
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
        when age({{ get_current_date() }}, p.date_of_birth) < interval '8 days'
            then concat(extract(day from age({{ get_current_date() }}, p.date_of_birth)), ' days')
        when age({{ get_current_date() }}, p.date_of_birth) >= interval '8 days'
            and age({{ get_current_date() }}, p.date_of_birth) < interval '1 month'
            -- whole days / 7, not extract(week from <interval>): Postgres 16 rejects the
            -- week unit on an interval, though 18 accepts it (MAUI-7060)
            then concat(({{ get_current_date() }} - p.date_of_birth) / 7, ' weeks')
        when age({{ get_current_date() }}, p.date_of_birth) >= interval '1 month'
            and age({{ get_current_date() }}, p.date_of_birth) < interval '2 years'
            then concat(extract(month from age({{ get_current_date() }}, p.date_of_birth)), ' months')
        when age({{ get_current_date() }}, p.date_of_birth) >= interval '2 years'
            then concat(extract(year from age({{ get_current_date() }}, p.date_of_birth)), ' years')
    end as age,
    l.id as location_id,
    l.name as location,
    f.id as facility_id,
    lg.id as location_group_id,
    lg.name as location_group,
    d.diets,
    a.allergies
from {{ partition_ref('encounters', network) }} e
join {{ ref('patients') }} p
    on p.id = e.patient_id
join {{ partition_ref('locations', network) }} l
    on l.id = e.location_id
join {{ partition_ref('facilities', network) }} f
    on f.id = l.facility_id
left join {{ partition_ref('location_groups', network) }} lg
    on lg.id = l.location_group_id
left join diets d
    on d.encounter_id = e.id
left join allergies a
    on a.patient_id = p.id
where e.end_datetime is null

{% endmacro %}

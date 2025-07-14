with administered_circumstances as (
    select
        a.id,
        string_agg(rd_cir.name, '; ') as circumstance_name
    from {{ ref("vaccine_administrations") }} a
    cross join lateral unnest(a.circumstance_ids) c (unnest_circumstance_id)
    left join {{ ref("reference_data") }} rd_cir
        on rd_cir.id = c.unnest_circumstance_id
    group by a.id
)

select
    p.display_id,
    p.first_name,
    p.last_name,
    p.id as patient_id,
    p.date_of_birth,
    date_part('year', age(p.date_of_birth)) as age,
    p.sex,
    p.village_id,
    rd_vil.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    case
        when av.is_given_elsewhere = true and av.datetime is null then null
        else av.datetime::date
    end as vaccination_date,
    sv.category as vaccine_category,
    sv.label as vaccine_name,
    case when sv.category = 'Other' then av.vaccine_brand end as vaccine_brand,
    case when sv.category = 'Other' then av.disease end as disease,
    case
        when av.status = 'GIVEN' then 'Given'
        when av.status = 'NOT_GIVEN' then 'Not given'
        when av.status = 'RECORDED_IN_ERROR' then 'Recorded in error'
        when av.status = 'HISTORICAL' then 'Historical'
    end as vaccine_status,
    sv.dose_label as vaccine_schedule,
    av.batch,
    case
        when av.status in ('GIVEN', 'NOT_GIVEN', 'RECORDED_IN_ERROR') then u.display_name
    end as recorded_by,
    case
        when av.is_given_elsewhere = true then ac.circumstance_name
    end as circumstances,
    case
        when av.status = 'NOT_GIVEN' then null
        when av.status = 'GIVEN' and av.is_given_elsewhere = true then null
        when av.status in ('HISTORICAL', 'RECORDED_IN_ERROR') and av.is_given_elsewhere = true then av.given_by
        when av.status = 'GIVEN' then av.given_by
    end as given_by,
    case when av.is_given_elsewhere = true then av.given_by end as given_elsewhere_by,
    case
        when av.status = 'NOT_GIVEN' then av.given_by
    end as not_given_clinician,
    case
        when av.status = 'NOT_GIVEN' then rd_reason.name
    end as not_given_reason,
    case
        when av.status = 'HISTORICAL' then u.display_name
    end as modified_by,
    av.modification_datetime
from {{ ref("vaccine_administrations") }} av
join {{ ref("encounters") }} e on e.id = av.encounter_id
join {{ ref("patients") }} p on p.id = e.patient_id
left join {{ ref("locations") }} l on l.id = av.location_id
left join {{ ref("departments") }} d on d.id = av.department_id
left join {{ ref("location_groups") }} lg on lg.id = l.location_group_id
left join {{ ref("facilities") }} f on f.id = l.facility_id
left join {{ ref("vaccine_schedules") }} sv on sv.id = av.scheduled_vaccine_id
left join {{ ref("users") }} u on u.id = av.recorded_by_id
left join {{ ref("reference_data") }} rd_vil on rd_vil.id = p.village_id
left join {{ ref("reference_data") }} rd_reason on rd_reason.id = av.not_given_reason_id
left join administered_circumstances ac on ac.id = av.id

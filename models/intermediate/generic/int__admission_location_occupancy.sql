with dates as (
    select date::date
    from generate_series(
        concat(left( {{ parameter('fromDate', default_value='1900-01-01', data_type='text') }}, 7), '-01')::date,
        concat(left( {{ parameter('toDate', default_value='9999-01-01', data_type='text') }}, 7), '-01')::date,
        '1 day'::interval
    ) date
),

admission_location_log as (
    select
        da.id,
        da.encounter_id,
        da.start_datetime,
        da.location_id,
        'admission' as type
    from {{ ref('ds__admissions') }} da
    union all
    select
        ddh.id,
        ddh.encounter_id,
        ddh.start_datetime,
        ddh.location_id,
        'transfer-in' as type
    from {{ ref('ds__location_history') }} ddh
    join {{ ref('ds__admissions') }} da
        on da.encounter_id = ddh.encounter_id
        and da.start_datetime < ddh.start_datetime
        and (da.end_datetime > ddh.start_datetime or da.end_datetime is null)
)

select
    d.date,
    l.facility_id,
    f.name as facility,
    l.id as location_id,
    l.name as location,
    lg.id as location_group_id,
    lg.name as location_group,
    count(distinct alg.encounter_id) as occupancy
from dates d
join admission_location_log alg
    on alg.start_datetime::date <= d.date
join {{ ref('encounters') }} e
    on e.id = alg.encounter_id
    and (e.end_datetime::date >= d.date or e.end_datetime is null)
join {{ ref('locations') }} l
    on l.id = alg.location_id
join {{ ref('location_groups') }} lg
    on lg.id = l.location_group_id
join {{ ref('facilities') }} f
    on f.id = l.facility_id
group by d.date, l.facility_id, f.name, lg.id, lg.name, l.id, l.name
order by d.date, l.facility_id, f.name, lg.id, lg.name, l.id, l.name

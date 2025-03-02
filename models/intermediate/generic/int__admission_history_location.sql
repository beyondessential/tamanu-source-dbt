with admission_location_log as (
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
    ll.encounter_id,
    l.location_group_id,
    lg.name as location_group,
    ll.location_id,
    l.name as location,
    l.facility_id,
    f.name as facility,
    ll.start_datetime,
    coalesce(lead(ll.start_datetime) over w, e.end_datetime) as end_datetime,
    case
        when coalesce(lead(ll.start_datetime::date) over w, e.end_datetime::date) - ll.start_datetime::date < 1 then 1
        else coalesce(lead(ll.start_datetime::date) over w, e.end_datetime::date) - ll.start_datetime::date
    end as length_of_stay,
    coalesce(ll.type = 'admission', false) as admission,
    coalesce(lead(ll.location_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(ll.type = 'transfer-in', false) as transfer_in,
    coalesce(lead(ll.location_id) over w notnull, false) as transfer_out,
    coalesce(lead(ll.start_datetime) over w isnull and e.end_datetime::date = p.date_of_death, false) as death
from admission_location_log ll
join {{ ref('encounters') }} e on e.id = ll.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('locations') }} l on l.id = ll.location_id
join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
join {{ ref('facilities') }} f on f.id = l.facility_id
window w as (
    partition by ll.encounter_id
    order by ll.start_datetime
)

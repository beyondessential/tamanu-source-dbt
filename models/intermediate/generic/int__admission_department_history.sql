with admission_department_log as (
    select
        da.id,
        da.encounter_id,
        da.start_datetime,
        da.department_id,
        'admission' as type
    from {{ ref('ds__admissions') }} da
    union all
    select
        ddh.id,
        ddh.encounter_id,
        ddh.start_datetime,
        ddh.department_id,
        'transfer-in' as type
    from {{ ref('ds__department_history') }} ddh
    join {{ ref('ds__admissions') }} da
        on da.encounter_id = ddh.encounter_id
        and da.start_datetime < ddh.start_datetime
        and (da.end_datetime > ddh.start_datetime or da.end_datetime is null)
)

select
    dl.encounter_id,
    dl.department_id,
    d.name as department,
    d.facility_id,
    f.name as facility,
    dl.start_datetime,
    coalesce(lead(dl.start_datetime) over w, e.end_datetime) as end_datetime,
    case
        when coalesce(lead(dl.start_datetime::date) over w, e.end_datetime::date) - dl.start_datetime::date < 1 then 1
        else coalesce(lead(dl.start_datetime::date) over w, e.end_datetime::date) - dl.start_datetime::date
    end as length_of_stay,
    coalesce(dl.type = 'admission', false) as admission,
    coalesce(lead(dl.department_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(dl.type = 'transfer-in', false) as transfer_in,
    coalesce(lead(dl.department_id) over w notnull, false) as transfer_out,
    coalesce(lead(dl.start_datetime) over w isnull and e.end_datetime::date = p.date_of_death, false) as death
from admission_department_log dl
join {{ ref('encounters') }} e on e.id = dl.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('departments') }} d on d.id = dl.department_id
join {{ ref('facilities') }} f on f.id = d.facility_id
window w as (
    partition by encounter_id
    order by dl.start_datetime
)

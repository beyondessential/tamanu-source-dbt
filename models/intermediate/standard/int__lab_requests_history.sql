select distinct on (lr.id, coalesce(lrl.status, lr.status))
    lr.id as request_id,
    lr.requested_datetime::date as requested_date,
    lr.encounter_id,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    ltc.id as lab_test_category_id,
    ltc.name as lab_test_category,
    coalesce(lrl.status, lr.status) as status,
    coalesce(lrlm.updated_datetime, lrm.updated_datetime)::date as status_start_date,
    case
        when coalesce(lrl.status, lr.status) = 'published'
            then
                coalesce(lrlm.updated_datetime, lrm.updated_datetime)::date
        when lead(coalesce(lrlm.updated_datetime, lrm.updated_datetime)) over w is not null
            then
                case
                    when coalesce(lrlm.updated_datetime, lrm.updated_datetime)::date
                        = (lead(coalesce(lrlm.updated_datetime, lrm.updated_datetime)) over w)::date
                        then (lead(coalesce(lrlm.updated_datetime, lrm.updated_datetime)) over w)::date
                    else (lead(coalesce(lrlm.updated_datetime, lrm.updated_datetime)) over w - interval '1 day')::date
                end
        else current_date
    end as status_end_date
from {{ ref('lab_requests') }} lr
join {{ ref('lab_requests_metadata') }} lrm on lrm.id = lr.id
left join {{ ref('lab_request_logs') }} lrl on lrl.lab_request_id = lr.id
left join {{ ref('lab_request_logs_metadata') }} lrlm on lrlm.id = lrl.id
left join {{ ref('encounters') }} e on e.id = lr.encounter_id
left join {{ ref('departments') }} d on d.id = coalesce(lr.department_id, e.department_id)
left join {{ ref('facilities') }} f on f.id = d.facility_id
left join {{ ref('reference_data') }} ltc on ltc.id = lr.lab_test_category_id
where lr.status not in ('deleted', 'cancelled', 'entered-in-error')
window
    w as (
        partition by lr.id
        order by coalesce(lrlm.updated_datetime, lrm.updated_datetime)
    )
order by lr.id, coalesce(lrl.status, lr.status)

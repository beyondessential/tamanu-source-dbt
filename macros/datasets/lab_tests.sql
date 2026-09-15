{% macro lab_tests_dataset(is_sensitive=false) %}

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(lr.requested_datetime, p.date_of_birth::date)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    req_dept.id as requesting_department_id,
    req_dept.name as requesting_department,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    lr.display_id as lab_request_id,
    lr.status as status_id,
    case lr.status
        when 'reception_pending' then 'Reception pending'
        when 'results_pending' then 'Results pending'
        when 'to_be_verified' then 'To be verified'
        when 'verified' then 'Verified'
        when 'published' then 'Published'
        when 'cancelled' then 'Cancelled'
        when 'deleted' then 'Deleted'
        when 'sample-not-collected' then 'Sample not collected'
        when 'entered-in-error' then 'Entered in error'
        else lr.status
    end as status,
    ltp.id as lab_test_panel_id,
    ltp.name as lab_test_panel,
    category.id as lab_test_category_id,
    category.name as lab_test_category,
    lr.requested_datetime,
    requester.id as requested_by_id,
    requester.display_name as requested_by,
    lr.published_datetime as lab_request_published_datetime,
    lt.date as lab_test_date,
    lt.result,
    lt.verification,
    ltt.id as lab_test_type_id,
    ltt.name as lab_test_type,
    lt.completed_datetime as lab_test_completed_datetime
from {{ ref('lab_requests') }} lr
join {{ ref('encounters') }} e on e.id = lr.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('locations') }} l on l.id = e.location_id
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
left join {{ ref('departments') }} d on d.id = e.department_id
left join {{ ref('departments') }} req_dept on req_dept.id = lr.department_id
left join {{ ref('facilities') }} f on f.id = l.facility_id
left join {{ ref('users') }} requester on requester.id = lr.requested_by_id
left join {{ ref('lab_test_panel_requests') }} ltpr on ltpr.id = lr.lab_test_panel_request_id
left join {{ ref('lab_test_panels') }} ltp on ltp.id = ltpr.lab_test_panel_id
left join {{ ref('reference_data') }} category on category.id = lr.lab_test_category_id
join {{ ref('lab_tests') }} lt on lt.lab_request_id = lr.id
join {{ ref('lab_test_types') }} ltt on ltt.id = lt.lab_test_type_id
where ltt.is_sensitive = {{ is_sensitive }}

{% endmacro %}

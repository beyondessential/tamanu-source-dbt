{% macro lab_requests_dataset(is_sensitive=false) %}

with lab_test_data as (
    select
        lr.id as lab_request_id,
        string_agg(ltt.name, ', '
            order by ltt.name
        ) as tests,
        max(lt.completed_datetime) as completed_datetime
    from {{ ref('lab_requests') }} lr
    join {{ ref('lab_tests') }} lt on lt.lab_request_id = lr.id
    join {{ ref('lab_test_types') }} ltt on ltt.id = lt.lab_test_type_id
    where ltt.is_sensitive = {{ is_sensitive }}
    group by lr.id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(lr.requested_datetime, p.date_of_birth)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    f.id as facility_id,
    f.name as facility,
    d.name as department,
    d.id as department_id,
    l.id as location_id,
    l.name as location,
    lg.id as location_group_id,
    lg.name as location_group,
    laboratory.id as laboratory_id,
    laboratory.name as laboratory,
    lr.display_id as request_id,
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
    lr.status as status_id,
    lr.requested_datetime,
    req_clinician.id as requested_by_id,
    req_clinician.display_name as requested_by,
    lr.department_id as requesting_department_id,
    req_department.name as requesting_department,
    lr.lab_test_priority_id as priority_id,
    priority.name as priority,
    category.id as lab_test_category_id,
    category.name as lab_test_category,
    ltp.name as lab_test_panel,
    lta.tests,
    lr.collected_datetime,
    lr.collected_by_id,
    collector.display_name as collected_by,
    lr.specimen_type_id,
    specimen.name as specimen_type,
    site.name as site,
    lta.completed_datetime,
    case lr.reason_for_cancellation
        when 'clinical' then 'Clinical reason'
        when 'duplicate' then 'Duplicate'
        when 'entered-in-error' then 'Entered in error'
        when 'patient-discharged' then 'Patient discharged'
        when 'patient-refused' then 'Patient refused'
        when 'other' then 'Other'
        else lr.reason_for_cancellation
    end as reason_for_cancellation
from {{ ref('lab_requests') }} lr
join lab_test_data lta on lta.lab_request_id = lr.id
join {{ ref('encounters') }} e on e.id = lr.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('locations') }} l on l.id = e.location_id
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
left join {{ ref('departments') }} d on d.id = e.department_id
left join {{ ref('facilities') }} f on f.id = l.facility_id
left join {{ ref('reference_data') }} laboratory on laboratory.id = lr.lab_test_laboratory_id
left join {{ ref('users') }} req_clinician on req_clinician.id = lr.requested_by_id
left join {{ ref('departments') }} req_department on req_department.id = lr.department_id
left join {{ ref('reference_data') }} priority on priority.id = lr.lab_test_priority_id
left join {{ ref('reference_data') }} category on category.id = lr.lab_test_category_id
left join {{ ref('users') }} collector on collector.id = lr.collected_by_id
left join {{ ref('reference_data') }} specimen on specimen.id = lr.specimen_type_id
left join {{ ref('reference_data') }} site on site.id = lr.lab_sample_site_id
left join {{ ref('lab_test_panel_requests') }} ltpr
    on ltpr.id = lr.lab_test_panel_request_id
left join {{ ref('lab_test_panels') }} ltp on ltp.id = ltpr.lab_test_panel_id

{% endmacro %}

with lab_test_data as (
    select
        lr.id as lab_request_id,
        string_agg(
            case when not ltt.is_sensitive then ltt.name end, ', '
            order by ltt.name
        ) as non_sensitive_tests,
        string_agg(
            case when ltt.is_sensitive then ltt.name end, ', '
            order by ltt.name
        ) as sensitive_tests,
        max(case when ltt.is_sensitive then lt.completed_datetime end) as sensitive_completed_datetime,
        max(case when not ltt.is_sensitive then lt.completed_datetime end) as non_sensitive_completed_datetime
    from {{ ref('lab_requests') }} lr
    join {{ ref('lab_tests') }} lt on lt.lab_request_id = lr.id
    join {{ ref('lab_test_types') }} ltt on ltt.id = lt.lab_test_type_id
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
    req_clinician.display_name as clinician,
    req_department.name as requesting_department,
    priority.name as priority,
    category.id as category_id,
    category.name as category,
    coalesce(ltp.name, lta.non_sensitive_tests) as non_sensitive_tests,
    lta.sensitive_tests,
    lr.collected_datetime,
    collector.display_name as collected_by,
    specimen.name as specimen_type,
    site.name as site,
    lta.non_sensitive_completed_datetime,
    lta.sensitive_completed_datetime,
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
left join {{ ref('lab_test_panel_requests') }} ltpr
    on ltpr.id = lr.lab_test_panel_request_id
left join {{ ref('lab_test_panels') }} ltp on ltp.id = ltpr.lab_test_panel_id
left join {{ ref('reference_data') }} priority on priority.id = lr.lab_test_priority_id
left join {{ ref('reference_data') }} category on category.id = lr.lab_test_category_id
left join {{ ref('users') }} collector on collector.id = lr.collected_by_id
left join {{ ref('reference_data') }} specimen on specimen.id = lr.specimen_type_id
left join {{ ref('reference_data') }} site on site.id = lr.lab_sample_site_id
order by lr.requested_datetime

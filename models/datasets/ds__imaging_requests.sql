with results as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from {{ ref('imaging_results') }}
    group by imaging_request_id
),

imaging_area_notes as (
    select
        record_id as imaging_request_id,
        string_agg(content, ', ' order by datetime) as imaging_area
    from {{ ref('notes') }}
    where record_type = 'ImagingRequest'
        and note_type = 'areaToBeImaged'
    group by record_id
),

imaging_areas as (
    select
        ira.imaging_request_id,
        coalesce(
            string_agg(ia.name, ', ' order by ia.name),
            n.imaging_area
        ) as imaging_area
    from {{ ref('imaging_request_areas') }} ira
    left join {{ ref('reference_data') }} ia on ia.id = ira.area_id
    left join imaging_area_notes n on n.imaging_request_id = ira.imaging_request_id
    group by ira.imaging_request_id, n.imaging_area
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(ir.datetime::date, p.date_of_birth)) as age,
    p.sex,
    v.id as village_id,
    v.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    lg.id as location_group_id,
    lg.name as location_group,
    ir.display_id as request_id,
    ir.datetime as requested_datetime,
    su.id as supervising_clinician_id,
    su.display_name as supervising_clinician,
    ru.id as requesting_clinician_id,
    ru.display_name as requesting_clinician,
    case
        when ir.priority = 'routine' then 'Routine'
        when ir.priority = 'urgent' then 'Urgent'
        when ir.priority = 'asap' then 'ASAP'
        when ir.priority = 'stat' then 'STAT'
        when ir.priority = 'today' then 'Today'
        else ir.priority
    end as priority,
    ir.imaging_type as imaging_type_id,
    case
        when ir.imaging_type = 'xRay' then 'X-Ray'
        when ir.imaging_type = 'ctScan' then 'CT Scan'
        when ir.imaging_type = 'ultrasound' then 'Ultrasound'
        when ir.imaging_type = 'mri' then 'MRI'
        when ir.imaging_type = 'ecg' then 'ECG'
        when ir.imaging_type = 'holterMonitor' then 'Holter Monitor'
        when ir.imaging_type = 'echocardiogram' then 'Echocardiogram'
        when ir.imaging_type = 'mammogram' then 'Mammogram'
        when ir.imaging_type = 'endoscopy' then 'Endoscopy'
        when ir.imaging_type = 'fluroscopy' then 'Fluroscopy'
        when ir.imaging_type = 'angiogram' then 'Angiogram'
        when ir.imaging_type = 'colonoscopy' then 'Colonoscopy'
        when ir.imaging_type = 'vascularStudy' then 'Vascular Study'
        when ir.imaging_type = 'stressTest' then 'Stress Test'
        else ir.imaging_type
    end as imaging_type,
    areas.imaging_area,
    ir.status as status_id,
    case
        when ir.status = 'pending' then 'Pending'
        when ir.status = 'in_progress' then 'In progress'
        when ir.status = 'completed' then 'Completed'
        when ir.status = 'cancelled' then 'Cancelled'
        when ir.status = 'deleted' then 'Deleted'
        when ir.status = 'entered_in_error' then 'Entered in error'
        else 'Unknown'
    end as status,
    case
        when ir.status = 'completed' then irs.completed_datetime
    end as completed_datetime,
    case
        when ir.reason_for_cancellation = 'clinical' then 'Clinical reason'
        when ir.reason_for_cancellation = 'duplicate' then 'Duplicate'
        when ir.reason_for_cancellation = 'entered-in-error' then 'Entered in error'
        when ir.reason_for_cancellation = 'patient-discharged' then 'Patient discharged'
        when ir.reason_for_cancellation = 'patient-refused' then 'Patient refused'
        when ir.reason_for_cancellation = 'other' then 'Other'
    end as reason_for_cancellation
from {{ ref('imaging_requests') }} ir
join {{ ref('encounters') }} e on e.id = ir.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('locations') }} l on l.id = e.location_id
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    and not f.is_sensitive
left join {{ ref('departments') }} d on d.id = e.department_id
left join {{ ref('users') }} su on su.id = e.clinician_id
left join {{ ref('users') }} ru on ru.id = ir.requested_by_id
left join imaging_areas areas on areas.imaging_request_id = ir.id
left join {{ ref('reference_data') }} v on v.id = p.village_id
left join results irs on irs.imaging_request_id = ir.id

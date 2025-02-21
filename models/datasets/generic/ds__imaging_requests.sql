with results as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from {{ ref('imaging_results') }}
    group by imaging_request_id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(ir.datetime::date, p.date_of_birth::date)) as age,
    initcap(p.sex::text) as sex,
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
    end as imaging_type,
    case
        when ia.id is not null then ia.name
        else n.content
    end as imaging_area,
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
left join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('locations') }} l on l.id = e.location_id
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
left join {{ ref('facilities') }} f on f.id = l.facility_id
left join {{ ref('departments') }} d on d.id = e.department_id
left join {{ ref('users') }} su on su.id = e.clinician_id
left join {{ ref('users') }} ru on ru.id = ir.requested_by_id
left join {{ ref('notes') }} n
    on n.record_id = ir.id and n.record_type = 'ImagingRequest' and n.note_type = 'areaToBeImaged'
left join {{ ref('imaging_request_areas') }} ira on ira.imaging_request_id = ir.id
left join {{ ref('reference_data') }} ia on ia.id = ira.area_id
left join {{ ref('reference_data') }} v on v.id = p.village_id
left join results irs on irs.imaging_request_id = ir.id
order by ir.datetime

with encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.date,
        eh.change_type,
        eh.actor_id,
        eh.clinician_id,
        eh.department_id,
        eh.location_id,
        eh.encounter_type,
        clinician.display_name as clinician_name,
        actor.display_name as actor_name,
        d.name as department_name,
        l.name as location_name,
        lg.id as location_group_id,
        lg.name as location_group_name,
        row_number() over (
            partition by eh.encounter_id, eh.change_type
            order by eh.date
        ) as change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id
            order by eh.date
        ) as prev_location_group_id
    from {{ ref('encounters') }} ef
    join {{ ref('encounter_history') }} eh
        on eh.encounter_id = ef.id
    join {{ ref('users') }} actor
        on actor.id = eh.actor_id
    join {{ ref('users') }} clinician
        on clinician.id = eh.clinician_id
    join {{ ref('departments') }} d
        on d.id = eh.department_id
    join {{ ref('locations') }} l
        on l.id = eh.location_id
    join {{ ref('location_groups') }} lg
        on lg.id = l.location_group_id
),

location_changes as (
    select
        encounter_id,
        array_agg(
            to_char(date::timestamp, 'dd/mm/yyyy hh12:mi:ss AM')
            order by date
        ) as location_datetime,
        array_agg(
            location_id
            order by date
        ) as location_id,
        string_agg(
            location_name, ', '
            order by date
        ) as location_name
    from encounter_history_consolidated
    where change_type isnull or change_type = 'location'
    group by encounter_id
),

location_group_changes as (
    select
        encounter_id,
        array_agg(
            to_char(date::timestamp, 'dd/mm/yyyy hh12:mi:ss AM')
            order by date
        ) as location_group_datetime,
        array_agg(
            location_group_id
            order by date
        ) as location_group_id,
        string_agg(
            location_group_name, ', '
            order by date
        ) as location_group_name
    from encounter_history_consolidated
    where (change_type isnull or change_type = 'location')
        and (location_group_id != prev_location_group_id or prev_location_group_id is null)
    group by encounter_id
),

department_changes as (
    select
        encounter_id,
        array_agg(
            to_char(date::timestamp, 'dd/mm/yyyy hh12:mi:ss AM')
            order by date
        ) as department_datetime,
        array_agg(
            department_id
            order by date
        ) as department_id,
        string_agg(
            department_name, ', '
            order by date
        ) as department_name
    from encounter_history_consolidated
    where change_type isnull or change_type = 'department'
    group by encounter_id
),

encounter_type_changes as (
    select
        encounter_id,
        array_agg(
            to_char(date::timestamp, 'dd/mm/yyyy hh12:mi:ss AM')
            order by date
        ) as encounter_type_datetime,
        string_agg(
            case
                when encounter_type = 'triage' then 'Triage'
                when encounter_type = 'observation' then 'Active ED care'
                when encounter_type = 'emergency' then 'Emergency short stay'
            end, ', '
            order by date
        ) as emergency_encounter,
        string_agg(
            case
                when encounter_type = 'admission' then 'Hospital admission'
            end, ', '
            order by date
        ) as inpatient_encounter,
        string_agg(
            case
                when encounter_type = 'clinic' then 'Clinic'
                when encounter_type = 'imaging' then 'Imaging'
                when encounter_type = 'surveyResponse' then 'Survey response'
                when encounter_type = 'vaccination' then 'Vaccination'
            end, ', '
            order by date
        ) as outpatient_encounter
    from encounter_history_consolidated
    where change_type isnull or change_type = 'encounter_type'
    group by encounter_id
),

encounter_diagnoses as (
    select
        ed.encounter_id,
        string_agg(
            concat(
                'Name: ', d.name,
                ', Code: ', d.code,
                ', Is primary: ', case when ed.is_primary then 'primary' else 'secondary' end,
                ', Certainty: ', ed.certainty
            ),
            E'\n'
            order by ed.is_primary desc, ed.date
        ) as diagnoses
    from {{ ref('encounters') }} e
    join {{ ref('encounter_diagnoses') }} ed
        on ed.encounter_id = e.id
    join {{ ref('reference_data') }} d 
        on d.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
    group by ed.encounter_id
),

encounter_prescriptions as (
    select
        ep.encounter_id,
        string_agg(
            concat(
                'Name: ', m.name,
                ', Discontinued: ', case when p.discontinued then 'true' else 'false' end,
                ', Discontinuing reason: ', p.discontinuing_reason
            ),
            '' || E'\n' || ''
            order by em.date
        ) as medications
    from {{ ref('encounter_prescriptions') }} ep
    join {{ ref('prescriptions') }} p
        on p.id = ep.prescription_id
    join {{ ref('reference_data') }} m on m.id = p.medication_id
    group by ep.encounter_id
),

encounter_vaccinations as (
    select
        av.encounter_id,
        string_agg(
            concat(
                v.name,
                ', Label: ', sv.label,
                ', Schedule: ', sv.dose_label
            ),
            E'\n'
            order by av.date
        ) as vaccinations
    from {{ ref('vaccine_administrations') }} av
    join {{ ref('vaccine_schedules') }} sv
        on sv.id = av.scheduled_vaccine_id
    join {{ ref('reference_data') }} v 
        on v.id = sv.vaccine_id 
    group by av.encounter_id
),

encounter_procedures as (
    select
        p.encounter_id,
        string_agg(
            concat(
                'Name: ', proc.name,
                ', Date: ', to_char(p.date::timestamp, 'DD-MM-YYYY'),
                ', Location: ', loc.name,
                ', Notes: ', p.note,
                ', Completed notes: ', p.completed_note
            ),
            E'\n'
            order by p.date
        ) as procedures
    from {{ ref('procedures') }} p
    left join {{ ref('reference_data') }} proc 
        on proc.id = p.procedure_type_id 
    left join {{ ref('locations') }} loc 
        on loc.id = p.location_id 
    group by p.encounter_id
),

encounter_lab_requests as (
    select
        lr.encounter_id,
        string_agg(
            coalesce(ltp.name, ltt.name), '' || E'\n' || ''
            order by lr.sample_time
        ) as lab_requests
    from {{ ref('lab_requests') }} lr
    left join {{ ref('lab_test_panel_requests') }} ltpr
        on ltpr.id = lr.lab_test_panel_request_id
    left join {{ ref('lab_test_panels') }} ltp 
        on ltp.id = ltpr.lab_test_panel_id 
    left join {{ ref('lab_tests') }} lt
        on lt.lab_request_id = lr.id
        and lr.lab_test_panel_request_id isnull
    left join {{ ref('lab_test_types') }} ltt 
        on ltt.id = lt.lab_test_type_id 
        and ltt.deleted_at is null
    where lr.status not in ('cancelled', 'deleted', 'entered-in-error')
    group by lr.encounter_id
),

imaging_request_info as (
    select
        ir.encounter_id,
        string_agg(
            concat(
                case
                    when ir.imaging_type = 'xRay' then 'X-Ray'
                    when ir.imaging_type = 'ctScan' then 'CT Scan'
                    when ir.imaging_type = 'ecg' then 'Electrocardiogram (ECG)'
                    when ir.imaging_type = 'mri' then 'MRI'
                    when ir.imaging_type = 'ultrasound' then 'Ultrasound'
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
                end,
                ', Areas to be imaged: ',
                coalesce(
                    string_agg(
                        area.name, ', '
                        order by area.name
                    ),
                    string_agg(case
                        when n.note_type = 'areaToBeImaged' then n.content
                    end, ', '
                    order by n.date)
                ),
                ', Notes: ',
                string_agg(case
                    when n.note_type = 'other' then n.content
                end, ','
                order by n.date)
            ),
            '' || E'\n' || ''
        ) as imaging_requests
    from {{ ref('imaging_requests') }} ir
    left join {{ ref('imaging_request_areas') }} ira
        on ira.imaging_request_id = ir.id
    left join {{ ref('reference_data') }} area 
        on area.id = ira.area_id 
    left join {{ ref('notes') }} n
        on n.record_id = ir.id
        and n.record_type = 'ImagingRequest'
    where ir.status not in ('cancelled', 'deleted', 'entered_in_error')
    group by ir.encounter_id
),

encounter_notes as (
    select
        n.record_id as encounter_id,
        string_agg(concat(
            'Note type: ',
            case
                when n.note_type = 'treatmentPlan' then 'Treatment plan'
                when n.note_type = 'admission' then 'Admission'
                when n.note_type = 'medical' then 'Medical'
                when n.note_type = 'surgical' then 'Surgical'
                when n.note_type = 'nursing' then 'Nursing'
                when n.note_type = 'dietary' then 'Dietary'
                when n.note_type = 'pharmacy' then 'Pharmacy'
                when n.note_type = 'physiotherapy' then 'Physiotherapy'
                when n.note_type = 'social' then 'Social'
                when n.note_type = 'discharge' then 'Discharge'
                when n.note_type = 'areaToBeImaged' then 'Area to be imaged'
                when n.note_type = 'resultDescription' then 'Result description'
                when n.note_type = 'other' then 'Other'
                when n.note_type = 'clinicalMobile' then 'Clinical mobile'
                when n.note_type = 'handover' then 'Handover'
                else n.note_type
            end,
            ', Content: ', n.content,
            ', Note date: ', to_char(n.date::timestamp, 'DD/MM/YYYY HH12:MI AM')
        ),
        E'\n'
        order by n.date) as notes
    from {{ ref('notes') }} n 
    where n.record_type = 'Encounter' and n.note_type != 'system'
    group by n.record_id
)

select  
    e.id as encounter_id,
    e.start_date as encounter_start_date,
    e.end_date as encounter_end_date,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(e.start_date::date, p.date_of_birth::date)) as age,
    p.sex,
    eth.name as ethnicity,
    bt.name as patient_billing_type,
    case when e.end_date is not null then
        case
            when e.end_date::date - e.start_date::date < 1 then 1
            else e.end_date::date - e.start_date::date
        end
    end as length_of_stay,
    f.id as facility_id,
    f.name as facility,
    etc.emergency_encounter,
    etc.inpatient_encounter,
    etc.outpatient_encounter,
    di.id as discharge_disposition_id,
    di.name as discharge_disposition,
    t.score as triage_score,
    arr.id as arrival_mode_id,
    arr.name as arrival_mode,
    case when t.closed_time notnull and t.triage_time notnull and t.closed_time > t.triage_time
            then concat(
                    lpad((
                        extract(day from (t.closed_time::timestamp - t.triage_time::timestamp)) * 24
                        + extract(hour from (t.closed_time::timestamp - t.triage_time::timestamp))
                    )::text, 2, '0'), ':',
                    lpad(extract(minute from (t.closed_time::timestamp - t.triage_time::timestamp))::text, 2, '0'), ':',
                    lpad(
                        (extract(second from (t.closed_time::timestamp - t.triage_time::timestamp))::int)::text, 2, '0'
                    )
                )
    end as triage_wait_time,
    d.id as discharging_department_id,
    d.name as discharging_department,
    lg.id as discharging_location_group_id,
    lg.name as discharging_location_group,
    l.id as discharging_location_id,
    l.name as discharging_location,
    dc.department_datetime[array_upper(dc.department_datetime, 1)] as time_assigned_to_discharging_department,
    lgc.location_group_datetime[array_upper(lgc.location_group_datetime, 1)] as time_assigned_to_discharging_area,
    lc.location_datetime[array_upper(lc.location_datetime, 1)] as time_assigned_to_discharging_location,
    dc.department_name as department_history,
    array_to_string(dc.department_datetime, ', ') as department_datetime_history,
    lgc.location_group_name as area_history,
    array_to_string(lgc.location_group_datetime, ', ') as area_datetime_history,
    lc.location_name as location_history,
    array_to_string(lc.location_datetime, ', ') as location_datetime_history,
    e.reason_for_encounter,
    ed.diagnoses,
    ep.medications,
    ev.vaccinations,
    epr.procedures,
    elr.lab_requests,
    iri.imaging_requests,
    case
        when length(en.notes) > 32000
            then concat(
                    'THIS CELL HAS BEEN CROPPED AS IT EXCEEDED THE MAXIMUM LENGTH IN EXCEL - PLEASE SEE TAMANU FOR ',
                    'FULL NOTES HISTORY', '' || E'\n' || '', left(en.notes, 32000)
                )
        else en.notes
    end as notes
from {{ ref('encounters') }} e
join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('patient_additional_data') }} pad on pad.patient_id = e.patient_id
left join {{ ref('reference_data') }} eth on eth.id = pad.ethnicity_id
left join {{ ref('reference_data') }} bt on bt.id = e.patient_billing_type_id
left join {{ ref('departments') }} d on d.id = e.department_id
left join {{ ref('locations') }} l on l.id = e.location_id
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
left join {{ ref('facilities') }} f on f.id = l.facility_id
left join {{ ref('triages') }} t on t.encounter_id = e.id
left join {{ ref('reference_data') }} arr on arr.id = t.arrival_mode_id
left join {{ ref('discharges')}} d on d.encounter_id = e.id
left join {{ ref('reference_data')}} di on di.id = d.discharge_disposition_id
left join encounter_type_changes etc on etc.encounter_id = e.id
left join department_changes dc on dc.encounter_id = e.id
left join location_group_changes lgc on lgc.encounter_id = e.id
left join location_changes lc on lc.encounter_id = e.id
left join encounter_diagnoses ed on ed.encounter_id = e.id
left join encounter_prescriptions ep on ep.encounter_id = e.id
left join encounter_vaccinations ev on ev.encounter_id = e.id
left join encounter_procedures epr on epr.encounter_id = e.id
left join encounter_lab_requests elr on elr.encounter_id = e.id
left join imaging_request_info iri on iri.encounter_id = e.id
left join encounter_notes en on en.encounter_id = e.id
order by e.start_date desc
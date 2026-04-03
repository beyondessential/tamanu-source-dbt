{% macro encounter_summary_report(date_field, is_sensitive=false) %}

with encounters_in_scope as (
    select
        e.id as encounter_id,
        e.start_datetime,
        e.end_datetime,
        e.patient_id,
        e.location_id,
        e.department_id,
        e.clinician_id,
        e.patient_billing_type_id,
        e.reason_for_encounter,
        f.id as facility_id,
        f.name as facility
    from {{ ref('encounters') }} e
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
        and f.is_sensitive = {{ is_sensitive }}
    where
        e.patient_id != '{{ var("test_patient") }}'
        {% if date_field == 'end_datetime' %}
        and e.end_datetime is not null
        {% endif %}
        and case
            when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
            else e.{{ date_field }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
        end
        and case
            when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
            else e.{{ date_field }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
        end
        and case
            when {{ parameter('facilityId') }} is null then true
            else f.id = {{ parameter('facilityId') }}
        end
        and case
            when {{ parameter('patientBillingTypeId') }} is null then true
            else e.patient_billing_type_id = {{ parameter('patientBillingTypeId') }}
        end
        and case
            when {{ parameter('supervisingClinicianId') }} is null then true
            else e.clinician_id = {{ parameter('supervisingClinicianId') }}
        end
),

encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.datetime,
        eh.change_type,
        eh.updated_by_id,
        eh.clinician_id,
        eh.department_id,
        eh.location_id,
        eh.encounter_type,
        clinician.display_name as clinician_name,
        actor.display_name as updated_by_name,
        d.name as department_name,
        l.name as location_name,
        lg.id as location_group_id,
        lg.name as location_group_name,
        row_number() over (
            partition by eh.encounter_id, eh.change_type
            order by eh.datetime
        ) as change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id
            order by eh.datetime
        ) as prev_location_group_id
    from {{ ref('encounter_history') }} eh
    join encounters_in_scope eis
        on eis.encounter_id = eh.encounter_id
    join {{ ref('users') }} actor
        on actor.id = eh.updated_by_id
    join {{ ref('users') }} clinician
        on clinician.id = eh.clinician_id
    join {{ ref('departments') }} d
        on d.id = eh.department_id
    join {{ ref('locations') }} l
        on l.id = eh.location_id
    left join {{ ref('location_groups') }} lg
        on lg.id = l.location_group_id
),

encounter_changes as (
    select
        encounter_id,
        
        -- Location changes: tracks all location changes throughout the encounter
        array_agg(
            to_char(datetime, '{{ var("datetime_format") }}')
            order by datetime
        ) filter (where change_type isnull or 'location' = any(change_type)) as location_datetimes,
        array_agg(
            location_id
            order by datetime
        ) filter (where change_type isnull or 'location' = any(change_type)) as location_ids,
        string_agg(
            location_name, ', '
            order by datetime
        ) filter (where change_type isnull or 'location' = any(change_type)) as locations,

        -- Location group changes: tracks location group changes (only when group actually changes)
        array_agg(
            to_char(datetime, '{{ var("datetime_format") }}')
            order by datetime
        ) filter (where change_type isnull or ('location' = any(change_type) and location_group_id is distinct from prev_location_group_id)) as location_group_datetimes,
        array_agg(
            location_group_id
            order by datetime
        ) filter (where change_type isnull or ('location' = any(change_type) and location_group_id is distinct from prev_location_group_id)) as location_group_ids,
        string_agg(
            location_group_name, ', '
            order by datetime
        ) filter (where change_type isnull or ('location' = any(change_type) and location_group_id is distinct from prev_location_group_id)) as location_groups,

        -- Department changes: tracks all department changes throughout the encounter
        array_agg(
            to_char(datetime, '{{ var("datetime_format") }}')
            order by datetime
        ) filter (where change_type isnull or 'department' = any(change_type)) as department_datetimes,
        array_agg(
            department_id
            order by datetime
        ) filter (where change_type isnull or 'department' = any(change_type)) as department_ids,
        string_agg(
            department_name, ', '
            order by datetime
        ) filter (where change_type isnull or 'department' = any(change_type)) as departments,

        -- Encounter type changes: tracks encounter type progression (emergency types)
        string_agg(
            case
                when encounter_type = 'triage' then 'Triage'
                when encounter_type = 'observation' then 'Active ED care'
                when encounter_type = 'emergency' then 'Emergency short stay'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or 'encounter_type' = any(change_type)) as encounter_type_emergency,

        -- Encounter type changes: tracks encounter type progression (inpatient types)
        string_agg(
            case
                when encounter_type = 'admission' then 'Hospital admission'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or 'encounter_type' = any(change_type)) as encounter_type_inpatient,

        -- Encounter type changes: tracks encounter type progression (outpatient types)
        string_agg(
            case
                when encounter_type = 'clinic' then 'Clinic'
                when encounter_type = 'imaging' then 'Imaging'
                when encounter_type = 'surveyResponse' then 'Survey response'
                when encounter_type = 'vaccination' then 'Vaccination'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or 'encounter_type' = any(change_type)) as encounter_type_outpatient,

        -- Encountering clinician: actor who created the initial encounter record (change_sequence = 1 ensures the creation row is used)
        min(updated_by_id) filter (where change_type is null and change_sequence = 1) as encountering_clinician_id,
        min(updated_by_name) filter (where change_type is null and change_sequence = 1) as encountering_clinician
    from encounter_history_consolidated
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
            order by ed.is_primary desc, ed.datetime asc
        ) as diagnoses
    from {{ ref('encounter_diagnoses') }} ed
    join encounters_in_scope eis
        on eis.encounter_id = ed.encounter_id
    join {{ ref('reference_data') }} d
        on d.id = ed.diagnosis_id
    group by ed.encounter_id
),

encounter_prescriptions as (
    select
        ep.encounter_id,
        string_agg(
            concat(
                'Name: ', m.name,
                ', Discontinued: ', case when p.is_discontinued then 'true' else 'false' end,
                ', Discontinuing reason: ', p.discontinuing_reason
            ),
            '' || E'\n' || ''
            order by p.datetime
        ) as medications
    from {{ ref('encounter_prescriptions') }} ep
    join encounters_in_scope eis
        on eis.encounter_id = ep.encounter_id
    join {{ ref('prescriptions') }} p
        on p.id = ep.prescription_id
    join {{ ref('reference_data') }} m
        on m.id = p.medication_id
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
            order by av.datetime
        ) as vaccinations
    from {{ ref('vaccine_administrations') }} av
    join encounters_in_scope eis
        on eis.encounter_id = av.encounter_id
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
                ', Date: ', to_char(p.date, '{{ var("date_format") }}'),
                ', Location: ', loc.name,
                ', Notes: ', p.note,
                ', Completed notes: ', p.completed_note
            ),
            E'\n'
            order by p.date
        ) as procedures
    from {{ ref('procedures') }} p
    join encounters_in_scope eis
        on eis.encounter_id = p.encounter_id
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
            order by lr.collected_datetime
        ) as lab_requests
    from {{ ref('lab_requests') }} lr
    join encounters_in_scope eis
        on eis.encounter_id = lr.encounter_id
    left join {{ ref('lab_test_panel_requests') }} ltpr
        on ltpr.id = lr.lab_test_panel_request_id
    left join {{ ref('lab_test_panels') }} ltp
        on ltp.id = ltpr.lab_test_panel_id
    left join {{ ref('lab_tests') }} lt
        on lt.lab_request_id = lr.id
        and lr.lab_test_panel_request_id isnull
    left join {{ ref('lab_test_types') }} ltt
        on ltt.id = lt.lab_test_type_id
    where lr.status not in ('cancelled', 'deleted', 'entered-in-error')
    group by lr.encounter_id
),

notes_raw as (
    select
        n.id,
        n.datetime,
        n.content,
        n.note_type,
        n.record_type,
        n.record_id,
        n.updated_note_id,
        n.visibility_status
    from {{ ref('notes') }} n
    left join {{ ref('imaging_requests') }} ir
        on n.record_type = 'ImagingRequest'
        and ir.id = n.record_id
    join encounters_in_scope eis
        on eis.encounter_id = coalesce(ir.encounter_id, n.record_id)
    where n.record_type in ('Encounter', 'ImagingRequest')
),

encounter_notes_deduped as (
    select
        id,
        datetime,
        content,
        note_type,
        record_id,
        visibility_status,
        row_number() over (partition by coalesce(updated_note_id, id) order by datetime desc) as row_number
    from notes_raw
    where
        record_type = 'Encounter'
        and note_type != 'system'
),

imaging_request_areas as (
    select
        ir.encounter_id,
        ira.imaging_request_id,
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
        end as imaging_type,
        coalesce(
            string_agg(
                area.name, ', '
                order by area.name
            ),
            string_agg(case
                when n.note_type = 'areaToBeImaged' then n.content
            end, ', '
            order by n.datetime)
        ) as areas_to_be_imaged,
        string_agg(case
            when n.note_type = 'other' then n.content
        end, ','
        order by n.datetime) as notes
    from {{ ref('imaging_requests') }} ir
    join encounters_in_scope eis
        on eis.encounter_id = ir.encounter_id
    left join {{ ref('imaging_request_areas') }} ira
        on ira.imaging_request_id = ir.id
    left join {{ ref('reference_data') }} area
        on area.id = ira.area_id
    left join notes_raw n
        on n.record_id = ir.id
        and n.record_type = 'ImagingRequest'
    where ir.status not in ('cancelled', 'deleted', 'entered_in_error')
    group by ir.encounter_id, ira.imaging_request_id, ir.imaging_type
),

encounter_imaging_requests as (
    select
        encounter_id,
        string_agg(
            concat(imaging_type, ', Areas to be imaged: ', areas_to_be_imaged, ', Notes: ', notes), '' || E'\n' || ''
        ) as imaging_requests
    from imaging_request_areas
    group by encounter_id
),

encounter_notes as (
    select
        n.record_id as encounter_id,
        string_agg(concat(
            'Note type: ',
            {{ translate_column_value('NOTE_TYPE_LABELS', 'n.note_type') }},
            ', Content: ', n.content,
            ', Note date: ', to_char(n.datetime, '{{ var("datetime_format") }}')
        ),
        E'\n'
        order by n.datetime) as notes
    from encounter_notes_deduped n
    where n.row_number = 1
    group by n.record_id
)

select
    p.display_id as "{{ translate_label('patientDisplayId') }}",
    p.first_name as "{{ translate_label('patientFirstName') }}",
    p.last_name as "{{ translate_label('patientLastName') }}",
    to_char(p.date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    date_part('year', age(eis.start_datetime, p.date_of_birth)) as "{{ translate_label('patientAge') }}",
    p.sex as "{{ translate_label('patientSex') }}",
    eth.name as "{{ translate_label('patientEthnicity') }}",
    bt.name as "{{ translate_label('patientBillingType') }}",
    to_char(eis.start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char(eis.end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    case
        when eis.end_datetime is not null then
            case
                when eis.end_datetime::date - eis.start_datetime::date < 1 then 1
                else eis.end_datetime::date - eis.start_datetime::date
            end
    end as "{{ translate_label('encounterLengthOfStay') }}",
    eis.facility as "{{ translate_label('facility') }}",
    ec.encounter_type_emergency as "{{ translate_label('encounterTypeEmergency') }}",
    ec.encounter_type_inpatient as "{{ translate_label('encounterTypeInpatient') }}",
    ec.encounter_type_outpatient as "{{ translate_label('encounterTypeOutpatient') }}",
    dd.name as "{{ translate_label('dischargeDisposition') }}",
    t.score as "{{ translate_label('triageCategory') }}",
    am.name as "{{ translate_label('triageArrivalMode') }}",
    case
        when t.closed_datetime notnull and t.triage_datetime notnull and t.closed_datetime > t.triage_datetime
            then concat(
                lpad((
                    extract(day from (t.closed_datetime - t.triage_datetime)) * 24
                    + extract(hour from (t.closed_datetime - t.triage_datetime))
                )::text, 2, '0'), ':',
                lpad(extract(minute from (t.closed_datetime - t.triage_datetime))::text, 2, '0'), ':',
                lpad(
                    (extract(second from (t.closed_datetime - t.triage_datetime))::int)::text, 2, '0'
                )
            )
    end as "{{ translate_label('triageWaitingTime') }}",
    ec.encountering_clinician as "{{ translate_label('encounterClinician') }}",
    c.display_name as "{{ translate_label('encounterSupervisingClinician') }}",
    dp.name as "{{ translate_label('dischargeDepartment') }}",
    ec.department_datetimes[array_upper(ec.department_datetimes, 1)] as "{{ translate_label('dischargeDateTime') }} of {{ translate_label('dischargeDepartment') }}",
    lg.name as "{{ translate_label('dischargeLocationGroup') }}",
    ec.location_group_datetimes[array_upper(ec.location_group_datetimes, 1)] as "{{ translate_label('dischargeDateTime') }} of {{ translate_label('dischargeLocationGroup') }}",
    l.name as "{{ translate_label('dischargeLocation') }}",
    ec.location_datetimes[array_upper(ec.location_datetimes, 1)] as "{{ translate_label('dischargeDateTime') }} of {{ translate_label('dischargeLocation') }}",
    ec.departments as "{{ translate_label('encounterDepartmentHistory') }}",
    array_to_string(ec.department_datetimes, ', ') as "{{ translate_label('encounterDepartmentHistoryDateTimes') }}",
    ec.location_groups as "{{ translate_label('encounterLocationGroupHistory') }}",
    array_to_string(ec.location_group_datetimes, ', ') as "{{ translate_label('encounterLocationGroupHistoryDateTimes') }}",
    ec.locations as "{{ translate_label('encounterLocationHistory') }}",
    array_to_string(ec.location_datetimes, ', ') as "{{ translate_label('encounterLocationHistoryDateTimes') }}",
    eis.reason_for_encounter as "{{ translate_label('encounterReasonForEncounter') }}",
    ed.diagnoses as "{{ translate_label('diagnoses') }}",
    ep.medications as "{{ translate_label('medications') }}",
    ev.vaccinations as "{{ translate_label('vaccinations') }}",
    epr.procedures as "{{ translate_label('procedures') }}",
    elr.lab_requests as "{{ translate_label('labRequests') }}",
    eir.imaging_requests as "{{ translate_label('imagingRequests') }}",
    case
        when length(en.notes) > 32000
            then concat(
                'THIS CELL HAS BEEN CROPPED AS IT EXCEEDED THE MAXIMUM LENGTH IN EXCEL - PLEASE SEE TAMANU FOR ',
                'FULL NOTES HISTORY', '' || E'\n' || '', left(en.notes, 32000)
            )
        else en.notes
    end as "{{ translate_label('notes') }}"
from encounters_in_scope eis
join {{ ref('patients') }} p
    on p.id = eis.patient_id
join {{ ref('locations') }} l
    on l.id = eis.location_id
join {{ ref('departments') }} dp
    on dp.id = eis.department_id
left join {{ ref('location_groups') }} lg
    on lg.id = l.location_group_id
left join {{ ref('users') }} c
    on c.id = eis.clinician_id
join encounter_changes ec
    on ec.encounter_id = eis.encounter_id
left join {{ ref('triages') }} t
    on t.encounter_id = eis.encounter_id
left join {{ ref('discharges') }} d
    on d.encounter_id = eis.encounter_id
left join {{ ref('patient_additional_data') }} pad
    on pad.patient_id = eis.patient_id
left join {{ ref('reference_data') }} eth
    on eth.id = pad.ethnicity_id
left join {{ ref('reference_data') }} bt
    on bt.id = eis.patient_billing_type_id
left join {{ ref('reference_data') }} am
    on am.id = t.arrival_mode_id
left join {{ ref('reference_data') }} dd
    on dd.id = d.disposition_id
left join encounter_diagnoses ed
    on ed.encounter_id = eis.encounter_id
left join encounter_prescriptions ep
    on ep.encounter_id = eis.encounter_id
left join encounter_vaccinations ev
    on ev.encounter_id = eis.encounter_id
left join encounter_procedures epr
    on epr.encounter_id = eis.encounter_id
left join encounter_lab_requests elr
    on elr.encounter_id = eis.encounter_id
left join encounter_imaging_requests eir
    on eir.encounter_id = eis.encounter_id
left join encounter_notes en
    on en.encounter_id = eis.encounter_id
where
    case
        when {{ parameter('departmentId') }} is null then true
        else {{ parameter('departmentId') }} = any(ec.department_ids::text [])
    end
    and case
        when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(ec.location_group_ids::text [])
    end
order by eis.{{ date_field }} desc

{% endmacro %}

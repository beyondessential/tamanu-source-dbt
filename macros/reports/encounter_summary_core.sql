{% macro encounter_summary_core(date_field, is_sensitive=false) %}
{#-
    Encounter summary rows: the patient, the encounter's movement history and its
    clinical aggregates, resolved and mostly unformatted.

    See specs/reports/encounter-summary.md for the BL clauses this macro implements.

    Callers differ only in projection: timestamps stay naive and aggregates stay as
    arrays or text, and each caller applies its own translate_label / to_char / timezone
    shift. Calling the core is what lets a deployment repo extend the report with its own
    joins instead of maintaining a copy of the body.

    BL-001: encounter_id and patient_id are the join keys an extending caller needs. The
    formatted report output exposes neither, and its patient display_id is patient-grain.

    BL-002: the projection applies no to_char and no to_user_selected_timezone. This
    governs the select list only -- the CTEs below do use both, so the compiled core
    carries nine :timezone placeholders.

    BL-003: no order by. A caller wraps this in a subquery, where ordering is not
    guaranteed to survive.

    BL-005: the parameter() filters here make this report-layer, hence macros/reports/.

    BL-006: seven outputs are already formatted in the viewer's timezone, applied inside
    the CTEs -- the three discharge_*_datetime columns, the three *_datetimes arrays, and
    the dates embedded in the procedures and notes text. A caller needing another format
    for those must change the CTEs; there is no raw column to select.
-#}

{#- The facility scope and the is_sensitive partition come from encounters_core();
    see specs/dbt-model/encounters_core.md. The predicates below are this report's own
    and reference the `e` / `f` aliases that macro contracts on (its BL-003).

    localise_timestamps is left off: this core is presentation-neutral (BL-002), so the
    timezone shift belongs to whichever caller formats the output. -#}
{%- set scope_filter -%}
    {{ to_user_selected_timezone('e.' ~ date_field) }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('e.' ~ date_field) }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    {%- if date_field == 'end_datetime' %}
    and e.end_datetime is not null
    {%- endif %}
    and {{ encounter_scope_common_filters() }}
{%- endset -%}

with encounters_in_scope as (
    select
        encounter_id,
        start_datetime,
        end_datetime,
        patient_id,
        location_id,
        department_id,
        clinician_id,
        patient_billing_type_id,
        reason_for_encounter,
        facility
    from (
        {{ encounters_core(is_sensitive=is_sensitive, extra_predicates=scope_filter) }}
    ) scope
),


encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.datetime,
        eh.change_type,
        eh.updated_by_id,
        eh.department_id,
        eh.location_id,
        eh.encounter_type,
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
    -- OQ-001: left join. encounter_history.actor_id is nullable at source, unlike
    -- department_id / location_id / examiner_id, so an inner join here drops the
    -- change -- and drops the encounter entirely where every one of its history
    -- rows has a null actor.
    left join {{ ref('users') }} actor
        on actor.id = eh.updated_by_id
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
            to_char({{ to_user_selected_timezone('datetime') }}, '{{ var("datetime_format") }}')
            order by datetime
        ) filter (where change_type is null or 'location' = any(change_type)) as location_datetimes,
        string_agg(
            location_name, ', '
            order by datetime
        ) filter (where change_type is null or 'location' = any(change_type)) as locations,

        -- Location group changes: tracks location group changes (only when group actually changes)
        array_agg(
            to_char({{ to_user_selected_timezone('datetime') }}, '{{ var("datetime_format") }}')
            order by datetime
        ) filter (where change_type is null or ('location' = any(change_type) and location_group_id is distinct from prev_location_group_id)) as location_group_datetimes,
        array_agg(
            location_group_id
            order by datetime
        ) filter (where change_type is null or ('location' = any(change_type) and location_group_id is distinct from prev_location_group_id)) as location_group_ids,
        string_agg(
            location_group_name, ', '
            order by datetime
        ) filter (where change_type is null or ('location' = any(change_type) and location_group_id is distinct from prev_location_group_id)) as location_groups,

        -- Department changes: tracks all department changes throughout the encounter
        array_agg(
            to_char({{ to_user_selected_timezone('datetime') }}, '{{ var("datetime_format") }}')
            order by datetime
        ) filter (where change_type is null or 'department' = any(change_type)) as department_datetimes,
        array_agg(
            department_id
            order by datetime
        ) filter (where change_type is null or 'department' = any(change_type)) as department_ids,
        string_agg(
            department_name, ', '
            order by datetime
        ) filter (where change_type is null or 'department' = any(change_type)) as departments,

        -- Encounter type changes: tracks encounter type progression (emergency types)
        string_agg(
            case
                when encounter_type = 'triage' then 'Triage'
                when encounter_type = 'observation' then 'Active ED care'
                when encounter_type = 'emergency' then 'Emergency short stay'
            end, ', '
            order by datetime
        ) filter (where change_type is null or 'encounter_type' = any(change_type)) as encounter_type_emergency,

        -- Encounter type changes: tracks encounter type progression (inpatient types)
        string_agg(
            case
                when encounter_type = 'admission' then 'Hospital admission'
            end, ', '
            order by datetime
        ) filter (where change_type is null or 'encounter_type' = any(change_type)) as encounter_type_inpatient,

        -- Encounter type changes: tracks encounter type progression (outpatient types)
        string_agg(
            case
                when encounter_type = 'clinic' then 'Clinic'
                when encounter_type = 'imaging' then 'Imaging'
                when encounter_type = 'surveyResponse' then 'Survey response'
                when encounter_type = 'vaccination' then 'Vaccination'
            end, ', '
            order by datetime
        ) filter (where change_type is null or 'encounter_type' = any(change_type)) as encounter_type_outpatient,

        -- Encountering clinician: actor who created the initial encounter record (change_sequence = 1 ensures the creation row is used)
        min(updated_by_name) filter (where change_type is null and change_sequence = 1) as encountering_clinician,

        -- Discharge datetimes: the time the patient was last assigned to each dimension, falls back to encounter start time if never changed
        to_char({{ to_user_selected_timezone('coalesce(max(datetime) filter (where \'department\' = any(change_type)), min(datetime) filter (where change_type is null))') }}, '{{ var("datetime_format") }}') as discharge_department_datetime,
        to_char({{ to_user_selected_timezone('coalesce(max(datetime) filter (where \'location\' = any(change_type)), min(datetime) filter (where change_type is null))') }}, '{{ var("datetime_format") }}') as discharge_location_datetime,
        to_char({{ to_user_selected_timezone('coalesce(max(datetime) filter (where \'location\' = any(change_type) and location_group_id is distinct from prev_location_group_id), min(datetime) filter (where change_type is null))') }}, '{{ var("datetime_format") }}') as discharge_location_group_datetime
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
        ) as diagnoses,
        string_agg(
            d.code,
            '; '
            order by ed.is_primary desc, ed.datetime asc
        ) as diagnosis_codes
    from {{ ref('encounter_diagnoses') }} ed
    join encounters_in_scope eis
        on eis.encounter_id = ed.encounter_id
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
        and lr.lab_test_panel_request_id is null
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
        n.updated_note_id
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
            ', Note date: ', to_char({{ to_user_selected_timezone('n.datetime') }}, '{{ var("datetime_format") }}')
        ),
        E'\n'
        order by n.datetime) as notes
    from encounter_notes_deduped n
    where n.row_number = 1
    group by n.record_id
)

select
    -- BL-001: join keys for an extending caller
    eis.encounter_id,
    eis.patient_id,
    -- patient
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    eth.name as ethnicity,
    bt.name as billing_type,
    division.name as division,
    subdivision.name as subdivision,
    village.name as village,
    -- encounter
    eis.start_datetime,
    eis.end_datetime,
    eis.facility,
    eis.reason_for_encounter,
    ec.encounter_type_emergency,
    ec.encounter_type_inpatient,
    ec.encounter_type_outpatient,
    -- discharge
    dd.name as discharge_disposition,
    dp.name as discharge_department,
    lg.name as discharge_location_group,
    l.name as discharge_location,
    ec.discharge_department_datetime,
    ec.discharge_location_group_datetime,
    ec.discharge_location_datetime,
    -- triage: raw component timestamps, so a caller formats the waiting time itself
    t.score as triage_score,
    am.name as triage_arrival_mode,
    t.triage_datetime,
    t.closed_datetime as triage_closed_datetime,
    -- clinicians
    ec.encountering_clinician,
    c.display_name as supervising_clinician,
    -- movement history
    ec.departments,
    ec.department_datetimes,
    ec.location_groups,
    ec.location_group_datetimes,
    ec.locations,
    ec.location_datetimes,
    -- BL-004: the id arrays the outer filters test, built by the aggregation
    ec.department_ids,
    ec.location_group_ids,
    -- clinical aggregates
    ed.diagnoses,
    ed.diagnosis_codes,
    ep.medications,
    ev.vaccinations,
    epr.procedures,
    elr.lab_requests,
    eir.imaging_requests,
    en.notes

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
left join {{ ref('reference_data') }} village
    on village.id = p.village_id
left join {{ ref('reference_data') }} bt
    on bt.id = eis.patient_billing_type_id
left join {{ ref('reference_data') }} division
    on division.id = pad.division_id
left join {{ ref('reference_data') }} subdivision
    on subdivision.id = pad.subdivision_id
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
-- BL-005: report-layer parameter() filters stay in the core
-- BL-003: no `order by` here -- a caller wraps this in a subquery, where ordering is
-- not guaranteed to survive, so the caller applies its own
where
    case
        when {{ parameter('departmentId') }} is null then true
        else {{ parameter('departmentId') }} = any(ec.department_ids::text [])
    end
    and case
        when {{ parameter('locationGroupId') }} is null then true
        else {{ parameter('locationGroupId') }} = any(ec.location_group_ids::text [])
    end

{% endmacro %}

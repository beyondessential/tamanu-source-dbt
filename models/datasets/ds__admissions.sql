with admission_encounters as (
    select 
        id,
        patient_id,
        start_datetime,
        end_datetime,
        location_id,
        patient_billing_type_id
    from {{ ref('encounters') }}
    where encounter_type = 'admission'
),

encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.datetime,
        eh.change_type,
        eh.clinician_id,
        eh.department_id,
        eh.location_id,
        u.display_name as clinician_name,
        d.name as department_name,
        l.name as location_name,
        lg.id as location_group_id,
        lg.name as location_group_name,
        -- Window functions for ordering and lag operations
        row_number() over (
            partition by eh.encounter_id, eh.change_type 
            order by eh.datetime
        ) as change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id 
            order by eh.datetime
        ) as prev_location_group_id
    from admission_encounters ae
    left join {{ ref('encounter_history') }} eh 
        on eh.encounter_id = ae.id
        and eh.encounter_type = 'admission'
        and (eh.change_type is null or eh.change_type in ('encounter_type', 'examiner', 'department', 'location'))
    left join {{ ref('users') }} u 
        on u.id = eh.clinician_id
    left join {{ ref('departments') }} d 
        on d.id = eh.department_id
    left join {{ ref('locations') }} l 
        on l.id = eh.location_id
    left join {{ ref('location_groups') }} lg 
        on lg.id = l.location_group_id
),

-- Clinician changes and admitting clinician logic
clinician_data as (
    select
        encounter_id,
        bool_or(change_type = 'encounter_type' and change_sequence = 1) as is_transfer,
        min(datetime) filter (where change_type is null or change_type in ('encounter_type', 'examiner')) as admission_datetime,
        array_agg(datetime order by datetime) filter (where change_type is null or change_type in ('encounter_type', 'examiner')) as clinician_datetimes,
        array_agg(clinician_id order by datetime) filter (where change_type is null or change_type in ('encounter_type', 'examiner')) as clinician_ids,
        array_agg(clinician_name order by datetime) filter (where change_type is null or change_type in ('encounter_type', 'examiner')) as clinician_names
    from encounter_history_consolidated
    group by encounter_id
),

-- Admitting clinician determination
admitting_clinicians as (
    select
        encounter_id,
        admission_datetime,
        case
            when is_transfer and array_length(clinician_ids, 1) > 1 
            then clinician_ids[2]
            else clinician_ids[1]
        end as admitting_clinician_id,
        case
            when is_transfer and array_length(clinician_names, 1) > 1 
            then clinician_names[2]
            else clinician_names[1]
        end as admitting_clinician_name
    from clinician_data
),

-- Department changes aggregation
department_changes as (
    select
        encounter_id,
        string_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI'), 
            '; ' 
            order by datetime
        ) as department_datetimes,
        array_agg(department_id order by datetime) as department_ids,
        string_agg(department_name, ', ' order by datetime) as departments
    from encounter_history_consolidated
    where change_type is null or change_type in ('encounter_type', 'department')
    group by encounter_id
),

-- Location changes aggregation
location_changes as (
    select
        encounter_id,
        string_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI'), 
            '; ' 
            order by datetime
        ) as location_datetimes,
        array_agg(location_id order by datetime) as location_ids,
        string_agg(location_name, ', ' order by datetime) as locations
    from encounter_history_consolidated
    where change_type is null or change_type in ('encounter_type', 'location')
    group by encounter_id
),

-- Location group changes (deduplicated in single pass)
location_group_changes as (
    select
        encounter_id,
        string_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI'), 
            '; ' 
            order by datetime
        ) as location_group_datetimes,
        array_agg(location_group_id order by datetime) as location_group_ids,
        string_agg(location_group_name, ', ' order by datetime) as location_groups
    from encounter_history_consolidated
    where (change_type is null or change_type in ('encounter_type', 'location'))
        and (location_group_id != prev_location_group_id or prev_location_group_id is null)
    group by encounter_id
),

-- Diagnoses aggregation
encounter_diagnoses as (
    select
        ed.encounter_id,
        string_agg(
            case when ed.is_primary 
                then rd.name || ' (' || rd.code || ')'
            end, 
            '; ' 
            order by ed.datetime
        ) as primary_diagnoses,
        string_agg(
            case when not ed.is_primary 
                then rd.name || ' (' || rd.code || ')'
            end, 
            '; ' 
            order by ed.datetime
        ) as secondary_diagnoses
    from admission_encounters ae
    inner join {{ ref('encounter_diagnoses') }} ed 
        on ed.encounter_id = ae.id
    inner join {{ ref('reference_data') }} rd 
        on rd.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
    group by ed.encounter_id
),

-- Patient and reference data
patient_data as (
    select
        ae.id as encounter_id,
        p.id as patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.date_of_birth,
        p.sex,
        p.village_id,
        village.name as village_name,
        ae.patient_billing_type_id,
        bt.name as billing_type_name,
        ae.start_datetime,
        ae.end_datetime,
        ae.location_id,
        f.id as facility_id,
        f.name as facility_name
    from admission_encounters ae
    left join {{ ref('patients') }} p 
        on p.id = ae.patient_id
    left join {{ ref('reference_data') }} village 
        on village.id = p.village_id
    left join {{ ref('reference_data') }} bt 
        on bt.id = ae.patient_billing_type_id
    left join {{ ref('locations') }} l 
        on l.id = ae.location_id
    left join {{ ref('facilities') }} f 
        on f.id = l.facility_id
)

select
    pd.patient_id,
    pd.display_id,
    pd.first_name,
    pd.last_name,
    pd.date_of_birth,
    date_part('year', age(ac.admission_datetime, pd.date_of_birth)) as age,
    initcap(pd.sex::text) as sex,
    pd.village_id,
    pd.village_name as village,
    pd.patient_billing_type_id as billing_type_id,
    pd.billing_type_name as billing_type,
    ac.admitting_clinician_id,
    ac.admitting_clinician_name as admitting_clinician,
    ac.admission_datetime,
    case
        when pd.end_datetime is null then 'active'
        else 'discharged'
    end as admission_status,
    pd.end_datetime as discharge_datetime,
    pd.facility_id,
    pd.facility_name as facility,
    dc.department_ids,
    dc.departments,
    dc.department_datetimes,
    lgc.location_group_ids,
    lgc.location_groups,
    lgc.location_group_datetimes,
    lc.location_ids,
    lc.locations,
    lc.location_datetimes,
    ed.primary_diagnoses,
    ed.secondary_diagnoses
from patient_data pd
left join admitting_clinicians ac 
    on ac.encounter_id = pd.encounter_id
left join department_changes dc 
    on dc.encounter_id = pd.encounter_id
left join location_changes lc 
    on lc.encounter_id = pd.encounter_id
left join location_group_changes lgc 
    on lgc.encounter_id = pd.encounter_id
left join encounter_diagnoses ed 
    on ed.encounter_id = pd.encounter_id

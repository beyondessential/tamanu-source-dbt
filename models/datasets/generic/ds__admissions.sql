with encounters_filtered as (
    select *
    from {{ ref('encounters') }}
    where encounter_type = 'admission'
),
encounter_change_clinician as (
    select
        eh.encounter_id,
        case when (array_agg(
                eh.change_type
                order by eh.datetime
            ))[1] = 'encounter_type' then true
            else false
        end as transfer,
        array_agg(
            eh.datetime
            order by eh.datetime
        ) as clinician_datetimes,
        array_agg(
            eh.clinician_id
            order by eh.datetime
        ) as clinician_ids,
        array_agg(
            u.display_name
            order by eh.datetime
        ) as clinicians
    from encounters_filtered ef
    join {{ ref('encounter_history') }} eh
        on eh.encounter_id = ef.id
    left join {{ ref ('users') }} u on u.id = eh.clinician_id
    where eh.encounter_type = 'admission'
        and (eh.change_type isnull or eh.change_type in ('encounter_type', 'examiner'))
    group by eh.encounter_id
),
admitting_clinician as (
	-- If the admission encounter is a transfer from a different encounter type (e.g. emergency), the admitting  
	-- clinician is the next clinician change if available, otherwise the clinician when the transfer occurred.
    select
        encounter_id,
        case
            when transfer = true and array_upper(clinician_ids, 1) > 1 then clinician_ids[2]
            else clinician_ids[1]
        end as admitting_clinician_id,
        case
            when transfer = true and array_upper(clinicians, 1) > 1 then clinicians[2]
            else clinicians[1]
        end as admitting_clinician
    from encounter_change_clinician
),
encounter_change_department as (
    select
        eh.encounter_id,
        string_agg(
        	to_char(eh.datetime, 'yyyy-mm-dd hh24:mi'), '; '
            order by eh.datetime
        ) as department_datetimes,
        array_agg(
            eh.department_id
            order by eh.datetime
        ) as department_ids,
        string_agg(
            d.name, ', '
            order by eh.datetime
        ) as departments
    from encounters_filtered ef
    join {{ ref('encounter_history') }} eh
        on eh.encounter_id = ef.id
    left join {{ ref('departments') }} d on d.id = eh.department_id
    where eh.encounter_type = 'admission'
        and (eh.change_type isnull or eh.change_type in ('encounter_type', 'department'))
    group by eh.encounter_id
),
encounter_change_location as (
    select
        eh.encounter_id,
        string_agg(
            to_char(eh.datetime, 'yyyy-mm-dd hh24:mi'), '; '
            order by eh.datetime
        ) as location_datetimes,
        array_agg(
            eh.location_id
            order by eh.datetime
        ) as location_ids,
        string_agg(
            l.name, ', '
            order by eh.datetime
        ) as locations
    from encounters_filtered ef
    join {{ ref('encounter_history') }} eh
        on eh.encounter_id = ef.id
    left join {{ ref('locations') }} l on l.id = eh.location_id
    where eh.encounter_type = 'admission'
        and (eh.change_type isnull or eh.change_type in ('encounter_type', 'location'))
    group by eh.encounter_id
),
encounter_unnest_change_location_group as (
    select
        eh.encounter_id,
        eh.datetime as location_group_datetime,
        lg.id as location_group_id,
        lg.name as location_group,
        case
            when location_group_id = lag(location_group_id) over w then 1
            else 0
        end as duplicate
    from encounters_filtered ef
    join {{ ref('encounter_history') }} eh on eh.encounter_id = ef.id
    left join {{ ref('locations') }} l on l.id = eh.location_id
    left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
    where eh.encounter_type = 'admission'
        and (eh.change_type isnull or eh.change_type in ('encounter_type', 'location'))
    window w as (
        partition by encounter_id
        order by eh.datetime
    )
),
encounter_change_location_group as (
    select
        encounter_id,
        string_agg(
            to_char(location_group_datetime, 'yyyy-mm-dd hh24:mi'), '; '
            order by location_group_datetime
        ) as location_group_datetimes,
        array_agg(
            location_group_id
            order by location_group_datetime
        ) as location_group_ids,
        string_agg(
            location_group, ', '
            order by location_group_datetime
        ) as location_groups
    from encounter_unnest_change_location_group
    where duplicate = 0
    group by encounter_id
),
diagnoses_by_encounter as (
    select
        ed.encounter_id,
        string_agg((case when ed.is_primary = true
                then concat(diagnosis.name, ' (', diagnosis.code, ')')
        end), '; '
        order by ed.datetime) as primary_diagnoses,
        string_agg((case when ed.is_primary = false
                then concat(diagnosis.name, ' (', diagnosis.code, ')')
        end), '; '
        order by ed.datetime) as secondary_diagnoses
    from encounters_filtered ef
    join {{ ref('encounter_diagnoses') }} ed on ed.encounter_id = ef.id
    left join {{ ref('reference_data') }} diagnosis on diagnosis.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
    group by ed.encounter_id
)
select
	p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(ef.start_datetime, p.date_of_birth)) as age,
    initcap(p.sex::text) as sex,
    village.id as village_id,
    village.name as village,
    bt.id as billing_type_id,
    bt.name as billing_type,
    ac.admitting_clinician_id,
    ac.admitting_clinician,
    ecc.clinician_datetimes[1] as admission_datetime,
    case
        when ef.end_datetime is null then 'active'
        else 'discharged'
    end as admission_status,
    ef.end_datetime as discharge_datetime,
    f.id as facility_id,
    f.name as facility,
    ecd.department_ids,
    ecd.departments,
    ecd.department_datetimes,
    eclg.location_group_ids,
    eclg.location_groups,
    eclg.location_group_datetimes,
    ecl.location_ids,
    ecl.locations,
    ecl.location_datetimes,
    d.primary_diagnoses,
    d.secondary_diagnoses
from encounters_filtered ef
left join {{ ref('patients') }} p on p.id = ef.patient_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('reference_data') }} bt on bt.id = ef.patient_billing_type_id
left join admitting_clinician ac on ac.encounter_id = ef.id
left join encounter_change_clinician ecc on ecc.encounter_id = ef.id
left join {{ ref('locations') }} l on l.id = ef.location_id
left join {{ ref('facilities') }} f on f.id = l.facility_id
left join encounter_change_department ecd on ecd.encounter_id = ef.id
left join encounter_change_location_group eclg on eclg.encounter_id = ef.id
left join encounter_change_location ecl on ecl.encounter_id = ef.id
left join diagnoses_by_encounter d on d.encounter_id = ef.id

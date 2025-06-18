with filtered_procedure as (
    select
        pc.*,
        eh.department_id,
        eh.encounter_type,
        row_number() over (
            partition by pc.id
            order by eh.datetime desc
        ) as encounter_history_record
    from {{ ref('procedures') }} pc
    left join {{ ref('encounter_history') }} eh
        on eh.encounter_id = pc.encounter_id
        and eh.datetime::date <= pc.date
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pc.date, p.date_of_birth)) as age,
    p.sex,
    nationality.name as nationality,
    encounter_facility.id as encounter_facility_id,
    encounter_facility.name as encounter_facility,
    encounter_department.id as encounter_department_id,
    encounter_department.name as encounter_department,
    case
        when coalesce(pc.encounter_type, e.encounter_type) = 'admission' then 'Hospital Admission'
        when coalesce(pc.encounter_type, e.encounter_type) = 'clinic' then 'Clinic'
        when coalesce(pc.encounter_type, e.encounter_type) in ('triage', 'observation', 'emergency') then 'Triage'
    end as encounter_type,
    e.start_datetime as encounter_start_datetime,
    e.end_datetime as encounter_end_datetime,
    procedure_facility.id as procedure_facility_id,
    procedure_facility.name as procedure_facility,
    procedure_area.id as procedure_area_id,
    procedure_area.name as procedure_area,
    procedure_location.id as procedure_location_id,
    procedure_location.name as procedure_location,
    procedure_type.id as procedure_type_id,
    procedure_type.name as procedure_type,
    pc.start_time as procedure_start_time,
    pc.end_time as procedure_end_time,
    case
        when pc.end_time is not null and pc.start_time is not null then
            concat(
                lpad((
                    case
                        when pc.end_time < pc.start_time
                            then
                                (24 + extract(hour from pc.end_time) - extract(hour from pc.start_time))
                        else
                            extract(hour from (pc.end_time - pc.start_time))
                    end
                )::text, 2, '0'), ':',
                lpad((
                    case
                        when pc.end_time < pc.start_time
                            then
                                (extract(minute from pc.end_time) - extract(minute from pc.start_time))
                        else
                            extract(minute from (pc.end_time - pc.start_time))
                    end
                )::text, 2, '0')
            )
    end as procedure_duration,
    clinician.id as procedure_clinician_id,
    clinician.display_name as procedure_clinician,
    anaesthetist.id as procedure_anaesthetist_id,
    anaesthetist.display_name as procedure_anaesthetist,
    assistant.id as procedure_assistant_id,
    assistant.display_name as procedure_assistant,
    case
        when pc.is_completed then 'Y' else 'N'
    end as is_completed
from filtered_procedure pc
join {{ ref('encounters') }} e on e.id = pc.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('reference_data') }} procedure_type on procedure_type.id = pc.procedure_type_id
join {{ ref('locations') }} procedure_location
    on procedure_location.id = pc.location_id
left join {{ ref('location_groups') }} procedure_area
    on procedure_area.id = procedure_location.location_group_id
join {{ ref('facilities') }} procedure_facility
    on procedure_facility.id = procedure_location.facility_id
join {{ ref('locations') }} encounter_location
    on encounter_location.id = e.location_id
join {{ ref('facilities') }} encounter_facility
    on encounter_facility.id = encounter_location.facility_id
join {{ ref('departments') }} encounter_department
    on encounter_department.id = coalesce(pc.department_id, e.department_id)
left join {{ ref('patient_additional_data') }} pd on pd.patient_id = p.id
left join {{ ref('reference_data') }} nationality on nationality.id = pd.nationality_id
left join {{ ref('users') }} assistant on assistant.id = pc.assistant_id
left join {{ ref('users') }} anaesthetist on anaesthetist.id = pc.anaesthetist_id
left join {{ ref('users') }} clinician on clinician.id = pc.clinician_id
where pc.encounter_history_record = 1

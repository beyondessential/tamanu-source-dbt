select
    e.id as encounter_id,
    p.id as patient_id,
    diagnosis.id as diagnosis_id,
    diagnosis.name as diagnosis,
    ed.datetime as diagnosis_datetime,
    p.first_name,
    p.last_name,
    p.display_id,
    date_part('year', age(ed.datetime::date, p.date_of_birth)) as age,
    p.sex,
    coalesce(pad.primary_contact_number, pad.secondary_contact_number) as contact_number,
    village.id as village_id,
    village.name as village,
    clinician.id as clinician_id,
    clinician.display_name as clinician,
    d.id as department_id,
    d.name as department,
    l.id as location_id,
    l.name as location,
    f.id as facility_id,
    f.name as facility,
    initcap(ed.certainty) as certainty,
    case when ed.is_primary = true then 'Yes' else 'No' end as is_primary
from {{ ref('encounter_diagnoses') }} ed
join {{ ref('reference_data') }} diagnosis on diagnosis.id = ed.diagnosis_id
join {{ ref('encounters') }} e on e.id = ed.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('patient_additional_data') }} pad on pad.patient_id = p.id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('users') }} clinician on clinician.id = e.clinician_id
left join {{ ref('departments') }} d on d.id = e.department_id
join {{ ref('locations') }} l on l.id = e.location_id
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    and not f.is_sensitive

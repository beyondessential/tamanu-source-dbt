select
    e.id as encounter_id,
    p.id as patient_id,
    diagnosis.id as diagnosis_id,
    diagnosis.name as diagnosis,
    ed.datetime as diagnosis_datetime,
    pfv.value as legal_status,
    case 
        when date_part('year', age(ed.datetime::date, p.date_of_birth)) < 5 then '< 5 years'
        when date_part('year', age(ed.datetime::date, p.date_of_birth)) between 5 and 14 then '5-14 years'
        else '15+ years'
    end as age_category,
    rs.id as referral_source_id,
    rs.name as referral_source,
    apt.id as appointment_type_id,
    apt.name as appointment_type,
    f.id as facility_id,
    f.name as facility
from {{ ref('encounter_diagnoses') }} ed
join {{ ref('reference_data') }} diagnosis on diagnosis.id = ed.diagnosis_id
join {{ ref('encounters') }} e on e.id = ed.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('facilities') }} f on f.id = e.facility_id
left join {{ ref('outpatient_appointments') }} oa on oa.encounter_id = e.id
left join {{ ref('reference_data') }} apt on apt.id = oa.appointment_type_id
left join {{ ref('reference_data') }} rs on rs.id = e.referral_source_id
left join {{ ref('patient_field_values') }} pfv on pfv.patient_id = p.id
    and pfv.definition_id = 'fieldCategory-legalstatus'
order by ed.datetime desc

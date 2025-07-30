select
    pprc.id as condition_id,
    prcc.id as condition_category_id,
    ppr.id as registration_id,
    ppr.program_registry_id,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    medical_area.id as medical_area_id,
    medical_area.name as medical_area,
    sub_division.id as sub_division_id,
    sub_division.name as sub_division,
    division.id as division_id,
    division.name as division,
    prc.name as condition,
    prcc.name as condition_category,
    pprc.datetime::date as condition_recorded_date,
    recorded_by.id as condition_recorded_by_id,
    recorded_by.display_name as condition_recorded_by,
    ppr.registration_status
from {{ ref('patient_program_registration_conditions') }} pprc
join {{ ref('program_registry_conditions') }} prc on prc.id = pprc.program_registry_condition_id
join {{ ref('patient_program_registrations') }} ppr on ppr.id = pprc.patient_program_registration_id
join {{ ref('program_registry_condition_categories') }} prcc on prcc.id = pprc.program_registry_condition_category_id
join {{ ref('program_registries') }} pr on pr.id = ppr.program_registry_id
join {{ ref('patients') }} p on p.id = ppr.patient_id
join {{ ref('patient_additional_data') }} pad on pad.patient_id = p.id
left join {{ ref('reference_data') }} medical_area on medical_area.id = pad.medical_area_id
left join {{ ref('reference_data') }} sub_division on sub_division.id = pad.subdivision_id
left join {{ ref('reference_data') }} division on division.id = pad.division_id
left join {{ ref('users') }} recorded_by on recorded_by.id = pprc.recorded_by_id
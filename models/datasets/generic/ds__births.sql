select
    pbd.registration_date,
    case
        when left(pbd.registration_date::text, 10) = left(pad.registration_date::text, 10) then u.display_name
    end as registered_by,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    initcap(p.sex::text) as sex,
    rd_ethnicity.name as ethnicity,
    rd_nationality.name as nationality,
    p.village_id,
    rd_village.name as village,
    case
        when
            p_mother.id is not null
            then concat(p_mother.first_name, ' ', p_mother.last_name, ' (', p_mother.display_id, ')')
    end as mother,
    case
        when
            p_father.id is not null
            then concat(p_father.first_name, ' ', p_father.last_name, ' (', p_father.display_id, ')')
    end as father,
    to_char(pbd.birth_time, 'HH12:MI AM') as birth_time,
    pbd.gestational_age_estimate,
    case when pbd.registered_birth_place = 'health_facility' then 'Health facility'
        when pbd.registered_birth_place = 'home' then 'Home'
        when pbd.registered_birth_place = 'other' then 'Other'
        else pbd.registered_birth_place
    end as registered_birth_place,
    f.id as birth_facility_id,
    f.name as birth_facility,
    case when pbd.attendant_at_birth = 'doctor' then 'Doctor'
        when pbd.attendant_at_birth = 'midwife' then 'Midwife'
        when pbd.attendant_at_birth = 'nurse' then 'Nurse'
        when pbd.attendant_at_birth = 'traditional_birth_attentdant' then 'Traditional birth attendant'
        when pbd.attendant_at_birth = 'other' then 'Other'
        else pbd.attendant_at_birth
    end as attendant_at_birth,
    pbd.name_of_attendant_at_birth,
    case
        when pbd.birth_delivery_type = 'normal_vaginal_delivery' then 'Normal vaginal delivery'
        when pbd.birth_delivery_type = 'breech' then 'Breech'
        when pbd.birth_delivery_type = 'emergency_c_section' then 'Emergency C-section'
        when pbd.birth_delivery_type = 'elective_c_section' then 'Elective C-section'
        when pbd.birth_delivery_type = 'vacuum_extraction' then 'Vacuum extraction'
        when pbd.birth_delivery_type = 'forceps' then 'Forceps'
        when pbd.birth_delivery_type = 'other' then 'Other'
        else pbd.birth_delivery_type
    end as birth_delivery_type,
    initcap(pbd.birth_type::text) as birth_type,
    pbd.birth_weight,
    pbd.birth_length,
    pbd.apgar_score_one_minute,
    pbd.apgar_score_five_minutes,
    pbd.apgar_score_ten_minutes
from {{ ref("patient_birth_data") }} pbd
left join {{ ref("patients") }} p on p.id = pbd.patient_id
left join {{ ref("reference_data") }} rd_village on rd_village.id = p.village_id
left join {{ ref("patient_additional_data") }} pad on pad.patient_id = p.id
left join {{ ref("reference_data") }} rd_nationality on rd_nationality.id = pad.nationality_id
left join {{ ref("reference_data") }} rd_ethnicity on rd_ethnicity.id = pad.ethnicity_id
left join {{ ref("patients") }} p_mother on p_mother.id = pad.mother_id
left join {{ ref("patients") }} p_father on p_father.id = pad.father_id
left join {{ ref("facilities") }} f on f.id = pbd.birth_facility_id
left join {{ ref("users") }} u on u.id = pad.registered_by_id
order by p.date_of_birth, pbd.birth_time

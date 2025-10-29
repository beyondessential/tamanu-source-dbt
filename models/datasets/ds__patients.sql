select
    p.registration_date,
    u.display_name as registered_by,
    p.id as patient_id,
    p.first_name,
    p.middle_name,
    p.last_name,
    p.cultural_name,
    p.display_id,
    p.sex,
    p.village_id,
    village.name as village,
    p.date_of_birth,
    p.date_of_death,
    pad.birth_certificate,
    pad.driving_license,
    pad.passport,
    pad.blood_type,
    pad.title,
    pad.marital_status,
    pad.primary_contact_number,
    pad.secondary_contact_number,
    cob.name as country_of_birth,
    nationality.name as nationality,
    ethnicity.name as ethnicity,
    occupation.name as occupation,
    religion.name as religion,
    billing.name as patient_billing_type,
    pad.mother_id,
    pad.father_id,
    pad.street_village,
    case
        when pbd.patient_id is null then 'Patient'
        else 'Birth'
    end as registration_type,
    date_part(
        'year',
        age(
            coalesce(p.date_of_death::date, current_date),
            p.date_of_birth
        )
    ) as age,
    case
        when p.date_of_death is not null then 'Deceased'
        else 'Alive'
    end as status
from {{ ref("patients") }} p
left join {{ ref("patient_additional_data") }} pad on pad.patient_id = p.id
left join {{ ref("patient_birth_data") }} pbd on pbd.patient_id = p.id
left join {{ ref("users") }} u on u.id = pad.registered_by_id
left join {{ ref("reference_data") }} village on village.id = p.village_id and village.type = 'village'
left join {{ ref("reference_data") }} cob on cob.id = pad.country_of_birth_id and cob.type = 'country'
left join {{ ref("reference_data") }} nationality on nationality.id = pad.nationality_id and nationality.type = 'nationality'
left join {{ ref("reference_data") }} ethnicity on ethnicity.id = pad.ethnicity_id and ethnicity.type = 'ethnicity'
left join {{ ref("reference_data") }} occupation on occupation.id = pad.occupation_id and occupation.type = 'occupation'
left join {{ ref("reference_data") }} religion on religion.id = pad.religion_id and religion.type = 'religion'
left join {{ ref("reference_data") }} billing on billing.id = pad.patient_billing_type_id and billing.type = 'patientBillingType'

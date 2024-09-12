SELECT
    id,
    title,
    marital_status,
    primary_contact_number,
    secondary_contact_number,
    street_village,
    birth_certificate,
    country_of_birth_id,
    driving_license,
    passport,
    blood_type,
    ethnicity_id,
    nationality_id,
    occupation_id,
    religion_id,
    patient_billing_type_id,
    mother_id,
    father_id,
    registered_by_id
FROM {{ source("tamanu", "patient_additional_data") }}
WHERE deleted_at IS NULL
    AND id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'

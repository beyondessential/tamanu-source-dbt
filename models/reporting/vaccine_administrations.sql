SELECT
    av.id,
    date AS datetime,
    encounter_id,
    location_id,
    department_id,
    scheduled_vaccine_id,
    status,
    reason,
    not_given_reason_id,
    batch,
    vaccine_name,
    vaccine_brand,
    disease,
    consent AS is_consented,
    consent_given_by,
    injection_site,
    given_by,
    given_elsewhere AS is_given_elsewhere,
    circumstance_ids,
    recorder_id
FROM {{ source("tamanu", "administered_vaccines") }} av
WHERE deleted_at IS NULL

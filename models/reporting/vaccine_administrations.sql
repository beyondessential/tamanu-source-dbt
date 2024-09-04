SELECT
    id,
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
    consent,
    consent_given_by,
    injection_site,
    given_by,
    given_elsewhere,
    circumstance_ids,
    recorder_id
FROM {{ source("tamanu", "administered_vaccines") }}
WHERE deleted_at IS NULL

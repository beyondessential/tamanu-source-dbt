SELECT
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    survey_response_id
FROM {{ source("tamanu", "referrals") }}
WHERE deleted_at IS NULL

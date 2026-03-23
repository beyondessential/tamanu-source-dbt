select
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    survey_response_id
from {{ source('tamanu', 'referrals') }}
where deleted_at is null

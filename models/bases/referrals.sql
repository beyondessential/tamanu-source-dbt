select
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    survey_response_id
from {{ resolve_input_model('referrals') }}
where deleted_at is null

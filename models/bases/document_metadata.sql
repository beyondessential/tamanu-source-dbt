select
    id,
    name,
    type,
    created_at::timestamp as created_datetime,
    patient_id,
    encounter_id
from {{ resolve_input_model('document_metadata') }}
where deleted_at is null


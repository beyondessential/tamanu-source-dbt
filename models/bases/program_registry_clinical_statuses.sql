select
    id,
    code,
    name,
    color,
    visibility_status,
    program_registry_id
from {{ resolve_input_model('program_registry_clinical_statuses') }}
where deleted_at is null

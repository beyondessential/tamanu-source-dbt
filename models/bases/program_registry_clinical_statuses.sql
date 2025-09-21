select
    id,
    code,
    name,
    color,
    visibility_status,
    program_registry_id
from {{ resolve_input_model('program_registry_clinical_statuses', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null

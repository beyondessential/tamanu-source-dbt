select
    id,
    code,
    name
from {{ resolve_input_model('programs', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null

select
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config
from {{ resolve_input_model('program_data_elements', source_type=var('base_model_source_type', 'source')) }}
where deleted_at is null

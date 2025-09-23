select
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config
from {{ resolve_input_model('program_data_elements') }}
where deleted_at is null

select
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config
from {{ source("tamanu", "program_data_elements") }}
where deleted_at is null

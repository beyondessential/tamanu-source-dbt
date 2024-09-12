SELECT
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config
FROM {{ source("tamanu", "program_data_elements") }}
WHERE deleted_at IS NULL

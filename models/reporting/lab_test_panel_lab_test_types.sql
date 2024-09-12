SELECT
    id,
    lab_test_panel_id,
    lab_test_type_id
FROM {{ source("tamanu", "lab_test_panel_lab_test_types") }}
WHERE deleted_at IS NULL

SELECT
    id,
    lab_test_panel_id,
    encounter_id
FROM {{ source("tamanu", "lab_test_panel_requests") }}
WHERE deleted_at IS NULL

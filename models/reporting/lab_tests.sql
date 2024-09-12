SELECT
    id,
    date,
    status,
    result,
    lab_request_id,
    lab_test_type_id,
    lab_test_method_id,
    laboratory_officer,
    completed_date AS completed_datetime,
    verification
FROM {{ source("tamanu", "lab_tests") }}
WHERE deleted_at IS NULL

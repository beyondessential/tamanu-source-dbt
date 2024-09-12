SELECT
    id,
    display_id,
    status,
    requested_date AS requested_datetime,
    lab_test_priority_id,
    lab_test_category_id,
    lab_test_panel_request_id,
    lab_test_laboratory_id,
    requested_by_id,
    specimen_attached AS is_specimen_collected,
    specimen_type_id,
    lab_sample_site_id,
    sample_time AS collected_datetime,
    collected_by_id,
    reason_for_cancellation,
    published_date,
    senaite_id,
    encounter_id,
    department_id
FROM {{ source("tamanu", "lab_requests") }}
WHERE deleted_at IS NULL

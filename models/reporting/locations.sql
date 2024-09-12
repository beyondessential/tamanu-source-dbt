SELECT
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status
FROM {{ source("tamanu", "locations") }}
WHERE deleted_at IS NULL
